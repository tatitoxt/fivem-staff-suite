import { applyTheme, isThemePref, resolveTheme, type ThemePref } from './theme';
import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useRef, type ReactNode } from 'react';
import { fmt } from './format';
import { isNui, send, subscribe, useMock } from './nui';
import type {
  AuditEntry, DashboardPayload, DutyPayload, IncomingMessage, OutgoingAction, OutgoingPayloads,
  EvidencePayload, NoticePayload, PlayerInfo, ReporterTicket, Ticket, ToastKind, UiConfig, VerifyResult, ViewId,
} from './types';

export interface Toast { id: number; kind: ToastKind; text: string; outside?: boolean }

type StaffDialog = 'ban.view' | 'staff.chat' | 'mod.emergency_freeze' | 'admin.permissions';
export interface Notice extends NoticePayload { id: number }
type ViewAction = 'goto' | 'spectate' | 'repair_vehicle' | 'delete_vehicle' | 'weekly_export';

export interface AppState {
  ready: boolean;
  visible: boolean;
  view: ViewId;
  viewAction: ViewAction | null;
  locale: string;
  theme: ThemePref;
  strings: Record<string, string>;
  version: string;
  player: PlayerInfo | null;
  config: UiConfig;
  audit: {
    entries: AuditEntry[];
    head: string;
    verify: VerifyResult | null;
    checking: boolean;
    checkedAt: number | null;
  };
  tickets: Ticket[];
  myTickets: ReporterTicket[];
  frozenPlayers: Record<string, boolean>;
  dashboard: DashboardPayload | null;
  duty: DutyPayload | null;
  toasts: Toast[];
  auditActor: string;
  ratePrompt: number | null;
  evidence: EvidencePayload | null;
  dataState: 'idle' | 'loading' | 'ready' | 'error';
  palette: boolean;
  reportOpen: boolean;
  notices: Notice[];
  staffDialog: StaffDialog | null;
}

type Action =
  | { type: 'msg'; msg: IncomingMessage }
  | { type: 'theme'; theme: ThemePref }
  | { type: 'view'; view: ViewId; auditActor?: string; action?: ViewAction }
  | { type: 'checking' }
  | { type: 'setAuditActor'; actor: string }
  | { type: 'dismissToast'; id: number }
  | { type: 'toast'; kind: ToastKind; text: string }
  | { type: 'rateDone' }
  | { type: 'evidenceClose' }
  | { type: 'loadTimeout' }
  | { type: 'retry' }
  | { type: 'palette'; open: boolean }
  | { type: 'report'; open: boolean }
  | { type: 'dismissNotice'; id: number }
  | { type: 'staffDialog'; dialog: StaffDialog | null };

let toastSeq = 0;

export function initialState(visible: boolean): AppState {
  return {
    ready: false,
    visible,
    view: 'audit',
    viewAction: null,
    locale: 'es',
    theme: 'light',
    strings: {},
    version: '',
    player: null,
    config: {},
    audit: { entries: [], head: '', verify: null, checking: false, checkedAt: null },
    tickets: [],
    myTickets: [],
    frozenPlayers: {},
    dashboard: null,
    duty: null,
    toasts: [],
    auditActor: '', ratePrompt: null, evidence: null, dataState: 'idle', palette: false, reportOpen: false, notices: [],
    staffDialog: null,
  };
}

const arr = <T,>(x: T[] | unknown): T[] => (Array.isArray(x) ? x : []);

function normalizeTickets<T extends Ticket | ReporterTicket>(t: T[] | Record<string, T>): T[] {
  const list = Array.isArray(t) ? t : Object.values(t);
  return list
    .filter((x) => !!x && typeof x.id === 'number')
    .map((x) => ({ ...x, messages: Array.isArray(x.messages) ? x.messages : [] }));
}

function pushToast(state: AppState, kind: ToastKind, text: string, outside?: boolean): AppState {
  const toasts = [...state.toasts, { id: ++toastSeq, kind, text, outside }].slice(-3);
  return { ...state, toasts };
}

const HIDDEN_DEFER = new Set(['audit', 'tickets', 'myTickets', 'dashboard', 'duty', 'frozenPlayers']);
const DATA_MESSAGES = new Set(['audit', 'tickets', 'myTickets', 'dashboard', 'duty']);

export function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    case 'view':
      return { ...state, view: action.view, viewAction: action.action ?? null, auditActor: action.auditActor ?? state.auditActor };
    case 'setAuditActor':
      return { ...state, auditActor: action.actor };
    case 'dismissNotice':
      return { ...state, notices: state.notices.filter((n) => n.id !== action.id) };
    case 'theme':
      return { ...state, theme: action.theme };
    case 'palette':
      return { ...state, palette: action.open };
    case 'report':
      return { ...state, reportOpen: action.open, view: action.open ? 'myReports' : state.view };
    case 'staffDialog':
      return { ...state, staffDialog: action.dialog };
    case 'checking':
      return { ...state, audit: { ...state.audit, checking: true } };
    case 'dismissToast':
      return { ...state, toasts: state.toasts.filter((t) => t.id !== action.id) };
    case 'toast':
      return pushToast(state, action.kind, action.text);
    case 'rateDone':
      return { ...state, ratePrompt: null };
    case 'evidenceClose':
      return { ...state, evidence: null };
    case 'loadTimeout':
      return state.dataState === 'loading' ? { ...state, dataState: 'error' } : state;
    case 'retry':
      return { ...state, dataState: 'loading' };
    case 'msg': {
      const next = applyMessage(state, action.msg);
      return DATA_MESSAGES.has(action.msg.type) && next.dataState !== 'ready' ? { ...next, dataState: 'ready' } : next;
    }
  }
}

function applyMessage(state: AppState, msg: IncomingMessage): AppState {
  switch (msg.type) {
    case 'init': {
      const p = msg.payload;
      return {
        ...state, ready: true, locale: p.locale, theme: isThemePref(p.theme) ? p.theme : isThemePref(p.config?.theme) ? p.config.theme : state.theme, strings: p.strings ?? {}, version: p.version ?? '',
        player: p.player ?? null, config: p.config ?? {},
        staffDialog: state.staffDialog && p.player?.capabilities?.includes(state.staffDialog) ? state.staffDialog : null,
      };
    }
    case 'audit': {
      const p = msg.payload;
      const entries = p.entries !== undefined ? arr<AuditEntry>(p.entries) : state.audit.entries;
      const head = p.head ?? (entries.length ? entries[entries.length - 1].hash : state.audit.head);
      const gotVerify = p.verify !== undefined;
      return {
        ...state,
        audit: {
          entries,
          head,
          verify: gotVerify ? p.verify! : state.audit.verify,
          checking: gotVerify ? false : state.audit.checking,
          checkedAt: gotVerify && state.audit.checking ? Date.now() / 1000 : state.audit.checkedAt,
        },
      };
    }
    case 'tickets':
      return { ...state, tickets: normalizeTickets(msg.payload.tickets ?? []) };
    case 'myTickets':
      return { ...state, myTickets: normalizeTickets(msg.payload.tickets ?? []) };
    case 'frozenPlayers':
      return { ...state, frozenPlayers: { ...msg.payload } };
    case 'freezeState':
      return { ...state, frozenPlayers: { ...state.frozenPlayers, [msg.payload.target]: msg.payload.frozen } };
    case 'dashboard':
      return {
        ...state,
        dashboard: { ...msg.payload, leaderboard: arr(msg.payload.leaderboard), alerts: arr(msg.payload.alerts) },
      };
    case 'duty':
      return { ...state, duty: { ...msg.payload, staff: arr(msg.payload.staff) } };
    case 'toast':
      return pushToast(state, msg.payload.kind, msg.payload.text, msg.payload.outside);
    case 'notice': {
      const max = Math.max(1, Math.min(5, msg.payload.max ?? 3));
      return { ...state, notices: [...state.notices, { ...msg.payload, id: ++toastSeq }].slice(-max) };
    }
    case 'rate':
      return { ...state, ratePrompt: msg.payload.id };
    case 'evidence':
      return { ...state, evidence: msg.payload };
    case 'open':
      return { ...state, visible: true, notices: [], view: msg.payload?.view ?? state.view, viewAction: null,
        dataState: state.dataState === 'ready' ? 'ready' : 'loading' };
    case 'close':
      return { ...state, visible: false, palette: false, staffDialog: null, viewAction: null };
  }
}

export interface AppApi {
  state: AppState;
  dispatch: React.Dispatch<Action>;
  t: (key: string, vars?: Record<string, string | number>) => string;
  can: (cap: string) => boolean;
  send: <A extends OutgoingAction>(action: A, payload?: OutgoingPayloads[A]) => Promise<unknown>;
}

const Ctx = createContext<AppApi | null>(null);

export function AppProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(reducer, useMock(), initialState);

  useEffect(() => {
    const apply = () => applyTheme(resolveTheme(state.theme), state.config.brand?.accent);
    apply();
    if (state.theme !== 'auto' || !window.matchMedia) return;
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    mq.addEventListener?.('change', apply);
    return () => mq.removeEventListener?.('change', apply);
  }, [state.theme, state.config.brand?.accent]);
  const visibleRef = useRef(state.visible);
  visibleRef.current = state.visible;
  useEffect(() => {
    // Con el panel oculto, los datos se guardan sin renderizar y se aplican al abrir.
    const pending = new Map<string, IncomingMessage[]>();
    return subscribe((msg) => {
      if (!visibleRef.current && HIDDEN_DEFER.has(msg.type)) {
        pending.set(msg.type, msg.type === 'audit' ? [...(pending.get('audit') ?? []), msg] : [msg]);
        return;
      }
      dispatch({ type: 'msg', msg });
      if (msg.type === 'close') visibleRef.current = false;
      if (msg.type === 'open') {
        visibleRef.current = true;
        for (const list of pending.values()) for (const m of list) dispatch({ type: 'msg', msg: m });
        pending.clear();
      }
    });
  }, []);

  const t = useCallback(
    (key: string, vars?: Record<string, string | number>) => fmt(state.strings[key] ?? key, vars),
    [state.strings],
  );
  const can = useCallback(
    (cap: string) => {
      const caps = state.player?.capabilities;
      return !caps || caps.includes(cap);
    },
    [state.player],
  );

  const tRef = useRef(t);
  tRef.current = t;
  // En FiveM, null significa que el callback NUI no respondió: se avisa en vez de fallar en silencio.
  const safeSend = useCallback(async <A extends OutgoingAction>(action: A, payload?: OutgoingPayloads[A]) => {
    const res = await send(action, payload);
    if (res === null && isNui()) dispatch({ type: 'toast', kind: 'error', text: tRef.current('ui_error_action') });
    return res;
  }, []);

  const api = useMemo<AppApi>(() => ({ state, dispatch, t, can, send: safeSend }), [state, t, can, safeSend]);
  return <Ctx.Provider value={api}>{children}</Ctx.Provider>;
}

export function useApp(): AppApi {
  const v = useContext(Ctx);
  if (!v) throw new Error('useApp fuera de AppProvider');
  return v;
}
