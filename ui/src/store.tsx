import { createContext, useCallback, useContext, useEffect, useMemo, useReducer, useRef, type ReactNode } from 'react';
import { fmt } from './format';
import { isNui, send, subscribe, useMock } from './nui';
import type {
  AuditEntry, DashboardPayload, DutyPayload, IncomingMessage, OutgoingAction, OutgoingPayloads,
  EvidencePayload, PlayerInfo, Ticket, ToastKind, UiConfig, VerifyResult, ViewId,
} from './types';

export interface Toast { id: number; kind: ToastKind; text: string }

export interface AppState {
  ready: boolean;
  visible: boolean;
  view: ViewId;
  locale: string;
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
  dashboard: DashboardPayload | null;
  duty: DutyPayload | null;
  toasts: Toast[];
  auditActor: string;
  ratePrompt: number | null;
  evidence: EvidencePayload | null;
  dataState: 'idle' | 'loading' | 'ready' | 'error';
}

type Action =
  | { type: 'msg'; msg: IncomingMessage }
  | { type: 'view'; view: ViewId; auditActor?: string }
  | { type: 'checking' }
  | { type: 'setAuditActor'; actor: string }
  | { type: 'dismissToast'; id: number }
  | { type: 'toast'; kind: ToastKind; text: string }
  | { type: 'rateDone' }
  | { type: 'evidenceClose' }
  | { type: 'loadTimeout' }
  | { type: 'retry' };

let toastSeq = 0;

export function initialState(visible: boolean): AppState {
  return {
    ready: false,
    visible,
    view: 'audit',
    locale: 'es',
    strings: {},
    version: '',
    player: null,
    config: {},
    audit: { entries: [], head: '', verify: null, checking: false, checkedAt: null },
    tickets: [],
    dashboard: null,
    duty: null,
    toasts: [],
    auditActor: '', ratePrompt: null, evidence: null, dataState: 'idle',
  };
}

const arr = <T,>(x: T[] | unknown): T[] => (Array.isArray(x) ? x : []);

function normalizeTickets(t: Ticket[] | Record<string, Ticket>): Ticket[] {
  const list = Array.isArray(t) ? t : Object.values(t);
  return list
    .filter((x): x is Ticket => !!x && typeof x.id === 'number')
    .map((x) => ({ ...x, messages: Array.isArray(x.messages) ? x.messages : [] }));
}

function pushToast(state: AppState, kind: ToastKind, text: string): AppState {
  const toasts = [...state.toasts, { id: ++toastSeq, kind, text }].slice(-3);
  return { ...state, toasts };
}

const DATA_MESSAGES = new Set(['audit', 'tickets', 'dashboard', 'duty']);

export function reducer(state: AppState, action: Action): AppState {
  switch (action.type) {
    case 'view':
      return { ...state, view: action.view, auditActor: action.auditActor ?? state.auditActor };
    case 'setAuditActor':
      return { ...state, auditActor: action.actor };
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
        ...state, ready: true, locale: p.locale, strings: p.strings ?? {}, version: p.version ?? '',
        player: p.player ?? null, config: p.config ?? {},
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
    case 'dashboard':
      return {
        ...state,
        dashboard: { ...msg.payload, leaderboard: arr(msg.payload.leaderboard), alerts: arr(msg.payload.alerts) },
      };
    case 'duty':
      return { ...state, duty: { ...msg.payload, staff: arr(msg.payload.staff) } };
    case 'toast':
      return pushToast(state, msg.payload.kind, msg.payload.text);
    case 'rate':
      return { ...state, ratePrompt: msg.payload.id };
    case 'evidence':
      return { ...state, evidence: msg.payload };
    case 'open':
      return { ...state, visible: true, view: msg.payload?.view ?? state.view, dataState: state.dataState === 'ready' ? 'ready' : 'loading' };
    case 'close':
      return { ...state, visible: false };
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

  useEffect(() => subscribe((msg) => dispatch({ type: 'msg', msg })), []);

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
