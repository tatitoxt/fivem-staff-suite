import type { ThemePref } from '../theme';
import { fmt } from '../format';
import { version } from '../../package.json';
import { sha256Hex } from './sha256';
import type {
  AuditEntry, BanRow, DashboardPayload, IncomingMessage, OutgoingAction, OutgoingPayloads, StaffStat, Ticket, TicketState,
  SanctionTemplate,
} from '../types';
import { append, verify } from './chain';
import { ALL_CAPS, ME, STAFF, TAMPER_SEQ, buildAlerts, buildAudit, buildStaff, buildTickets } from './demo';
import { LOCALES } from './locales';

// Backend simulado: reproduce lo que hacen client/main.lua + server/main.lua
// (transiciones de core/tickets.lua, auditoría encadenada, duty) y responde
// con los mismos mensajes NUI. Solo se carga en `npm run dev` y en tests.

const TRANSITIONS: Record<TicketState, Partial<Record<string, TicketState>>> = {
  open: { claim: 'claimed', close: 'closed', cancel: 'closed' },
  claimed: { unclaim: 'open', transfer: 'claimed', resolve: 'resolved', close: 'closed' },
  in_progress: { resolve: 'resolved', unclaim: 'claimed', close: 'closed' },
  resolved: { close: 'closed', reopen: 'reopened' },
  closed: { reopen: 'reopened' },
  reopened: { claim: 'claimed', close: 'closed', cancel: 'closed' },
};

const REASON_REQUIRED = new Set(['kick', 'ban', 'warn', 'delete_vehicle']);

export function computeDashboard(tickets: Ticket[], staff: StaffStat[], alerts: DashboardPayload['alerts']): DashboardPayload {
  const avg = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
  return {
    kpis: {
      open: tickets.filter((t) => t.state !== 'resolved' && t.state !== 'closed').length,
      resolved: tickets.filter((t) => t.state === 'resolved' || t.state === 'closed').length,
      avg_response: avg(staff.map((s) => s.avg_response).filter((x): x is number => x != null)),
      avg_rating: avg(staff.map((s) => s.avg_rating).filter((x): x is number => x != null)),
      on_duty: staff.filter((s) => s.on_duty).length,
    },
    leaderboard: [...staff].sort((a, b) => b.resolved - a.resolved),
    alerts,
  };
}

function demoScreenshot(id: number, n: number): string {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">`
    + `<rect width="640" height="360" fill="#1f2937"/><rect x="24" y="24" width="592" height="312" rx="16" fill="#374151"/>`
    + `<text x="320" y="170" fill="#f9fafb" font-family="sans-serif" font-size="28" text-anchor="middle">Ticket #${id} - captura ${n}</text>`
    + `<text x="320" y="210" fill="#9ca3af" font-family="sans-serif" font-size="18" text-anchor="middle">screenshot-basic (demo)</text></svg>`;
  return `data:image/svg+xml;base64,${btoa(svg)}`;
}

// Demo: ?brand=Nombre&accent=%23RRGGBB muestra la personalización de marca.
function mockBrand(): { name?: string; accent?: string } | undefined {
  if (typeof location === 'undefined') return undefined;
  const q = new URLSearchParams(location.search);
  const name = q.get('brand') ?? undefined;
  const accent = q.get('accent') ?? undefined;
  return name || accent ? { name, accent } : undefined;
}

function storedTheme(): ThemePref {
  try {
    const v = localStorage.getItem('staff_suite_theme');
    return v === 'dark' || v === 'auto' ? v : 'light';
  } catch { return 'light'; }
}

export class MockBackend {
  private theme: ThemePref = storedTheme();
  private evidenceData = new Map<string, string>();
  private ownerAccess = { id: 18, identifier: 'license:demo18', baseRank: 'helper',
    rank: 'inherit', rules: {} as Record<string, string> };
  locale = 'es';
  now = Date.now() / 1000;
  entries: AuditEntry[] = buildAudit(this.now);
  bans: BanRow[] = [];
  tickets: Ticket[] = buildTickets(this.now);
  staff: StaffStat[] = buildStaff();
  alerts = buildAlerts(this.now);
  latency = 120;
  private original: AuditEntry | null = null;

  private emit(msg: IncomingMessage) {
    window.postMessage(msg, '*');
  }

  private s(key: string, vars?: Record<string, string | number>) {
    return fmt(LOCALES[this.locale]?.[key] ?? key, vars);
  }

  private self() {
    return this.staff.find((s) => s.actor === ME)!;
  }

  private record(actor: string, action: string, target = '', reason = '', payload?: Record<string, unknown>) {
    append(this.entries, {
      ts: Math.round(Date.now() / 1000), actor, action, target, reason,
      payload: payload ? JSON.stringify(payload) : '',
    });
  }

  emitInit() {
    this.emit({
      type: 'init',
      payload: {
        locale: this.locale,
        theme: this.theme,
        strings: LOCALES[this.locale],
        version,
        player: { name: ME, rank: 'owner', capabilities: ALL_CAPS },
        config: {
          panel_key: 'F6', locales: ['es', 'en'],
          brand: mockBrand(),
          categories: ['bug', 'player', 'staff', 'question', 'other'],
          priorities: ['low', 'normal', 'high', 'urgent'],
          require_reason: true, persistence: 'json',
          export: { webhook: true, file: true, anchor_every: 20, tickets: true },
          sanction_templates: this.sanctionTemplates(),
          canned: ['greeting', 'investigating', 'need_info', 'resolved']
            .map((id) => ({ id, title: this.s(`canned_${id}_title`), text: this.s(`canned_${id}`) })),
          evidence: true,
          transfer_targets: ['Nahuel_R', 'Sofi.Mod', 'Kevo', 'Lu.Helper', 'Martin_B']
            .map((name) => ({ name, identifier: name })),
        },
      },
    });
  }

  private sanctionTemplates(): SanctionTemplate[] {
    return [
      { id: 'rp_warning', action: 'warn', reason: this.s('sanction_reason_rp') },
      { id: 'evasion_day', action: 'ban', reason: this.s('sanction_reason_evasion'), duration: 86400 },
    ];
  }

  emitAudit(withVerify: boolean) {
    this.emit({
      type: 'audit',
      payload: {
        entries: this.entries.map((e) => ({ ...e })),
        head: this.entries[this.entries.length - 1]?.hash ?? '',
        ...(withVerify ? { verify: verify(this.entries) } : {}),
      },
    });
  }

  emitTickets() {
    this.emit({ type: 'tickets', payload: { tickets: this.tickets.map((t) => ({ ...t, messages: [...t.messages] })) } });
    const tickets = this.tickets
      .filter((ticket) => ticket.reporter === ME && ticket.state !== 'closed')
      .map(({ id, category, state, description, messages }) => ({
        id, category, state, description,
        messages: messages.filter((msg) => !msg.internal)
          .map(({ author, body, ts }) => ({ mine: author === ME, body, ts })),
      }));
    this.emit({ type: 'myTickets', payload: { tickets } });
  }

  emitDuty() {
    this.emit({ type: 'duty', payload: { self: { on_duty: this.self().on_duty }, staff: this.staff.map((s) => ({ ...s })) } });
    this.emit({ type: 'dashboard', payload: computeDashboard(this.tickets, this.staff, this.alerts) });
  }

  toast(kind: 'ok' | 'error' | 'info', text: string) {
    this.emit({ type: 'toast', payload: { kind, text } });
  }

  start() {
    this.emitInit();
    this.emitAudit(true);
    this.emitTickets();
    this.emitDuty();
  }

  /** Harness: edita una entrada sin recalcular su hash (simula manipulación en la DB). */
  tamper(seq = TAMPER_SEQ) {
    const e = this.entries[seq - 1];
    if (!e || this.original) return;
    this.original = { ...e };
    this.entries[seq - 1] = { ...e, payload: JSON.stringify({ item: 'water', count: 1 }) };
    this.emitAudit(false);
  }

  restore() {
    if (!this.original) return;
    this.entries[this.original.seq - 1] = this.original;
    this.original = null;
    this.emitAudit(false);
  }

  get tampered() {
    return this.original !== null;
  }

  private transition(id: number, action: string, extra: { to?: string; resolution?: string } = {}) {
    const t = this.tickets.find((x) => x.id === id);
    if (!t) return this.toast('error', this.s('invalid_transition'));
    if (action === 'claim' && t.claimer && t.claimer !== ME) return this.toast('error', this.s('already_claimed'));
    const next = TRANSITIONS[t.state][action];
    if (!next) return this.toast('error', this.s('invalid_transition'));
    const from = t.state;
    t.state = next;
    if (action === 'claim') t.claimer = ME;
    if (action === 'transfer') t.claimer = extra.to ?? t.claimer;
    if (action === 'resolve') {
      t.resolution = extra.resolution ?? '';
      t.resolved_by = t.claimer;
      const who = this.staff.find((s) => s.actor === t.claimer);
      if (who) who.resolved += 1;
    }
    if (action === 'reopen') { t.claimer = null; t.resolution = null; }
    t.updated_ts = Math.round(Date.now() / 1000);
    this.record(ME, `ticket_${action}`, `ticket:${id}`, extra.resolution ?? (extra.to ? `→ ${extra.to}` : ''), { from, to: next });
    this.emitTickets();
    this.emitAudit(false);
    this.emitDuty();
  }

  promptRate(): number | null {
    const t = this.tickets.find((x) => (x.state === 'resolved' || x.state === 'closed') && x.rating == null);
    if (t) this.emit({ type: 'rate', payload: { id: t.id } });
    return t?.id ?? null;
  }

  handle<A extends OutgoingAction>(action: A, payload: OutgoingPayloads[A]): Promise<unknown> {
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve(this.dispatch(action, payload) ?? { ok: true });
      }, action === 'audit_verify' ? this.latency * 4 : this.latency);
    });
  }

  private dispatch(action: OutgoingAction, p: unknown) {
    switch (action) {
      case 'close_ui':
        this.emit({ type: 'close' });
        return;
      case 'set_theme': {
        this.theme = (p as OutgoingPayloads['set_theme']).theme;
        try { localStorage.setItem('staff_suite_theme', this.theme); } catch { /* sin storage */ }
        return;
      }
      case 'set_locale': {
        const { locale } = p as OutgoingPayloads['set_locale'];
        if (LOCALES[locale]) this.locale = locale;
        this.emitInit();
        return;
      }
      case 'refresh':
        this.start();
        return;
      case 'audit_filter':
        return;
      case 'announce': {
        const { body } = p as OutgoingPayloads['announce'];
        this.record(ME, 'staff_announce', 'server', body);
        this.emitAudit(false);
        this.toast('info', `${this.s('announcement_title')} · ${body}`);
        return { ok: true };
      }
      case 'vehicle_cleanup': {
        const { seconds } = p as OutgoingPayloads['vehicle_cleanup'];
        this.record(ME, 'world_cleanup_request', 'server', '', { seconds });
        this.emitAudit(false);
        this.toast('info', this.s('cleanup_countdown').replace('%{seconds}', String(seconds)));
        return { ok: true, data: { seconds } };
      }
      case 'vehicle_cleanup_cancel':
        this.record(ME, 'world_cleanup_cancel', 'server', '');
        this.emitAudit(false);
        this.toast('info', this.s('cleanup_cancelled'));
        return { ok: true };
      case 'ban_list': {
        const { page } = p as OutgoingPayloads['ban_list'];
        return { ok: true, data: { rows: this.bans.slice((page - 1) * 20, page * 20), hasMore: this.bans.length > page * 20 } };
      }
      case 'ban_revoke': {
        const { id, reason } = p as OutgoingPayloads['ban_revoke'];
        const ban = this.bans.find((row) => row.id === id && row.status === 'active');
        if (!ban) return { ok: false, error: this.s('ban_not_active') };
        ban.status = 'revoked';
        this.record(ME, 'mod_unban', ban.identifier, reason, { ban_id: id });
        this.emitAudit(false);
        return { ok: true };
      }
      case 'ticket_export': {
        const { id } = p as OutgoingPayloads['ticket_export'];
        this.record(ME, 'ticket_export_request', `ticket:${id}`);
        this.record(ME, 'ticket_export_result', `ticket:${id}`, '', { ok: true, status: 200 });
        this.emitAudit(false);
        return { ok: true };
      }
      case 'staff_chat': {
        const { body } = p as OutgoingPayloads['staff_chat'];
        this.record(ME, 'staff_chat_request', 'staff', '', { bytes: new TextEncoder().encode(body).length });
        this.record(ME, 'staff_chat_result', 'staff', '', { request_seq: this.entries.length, ok: true, recipients: 1 });
        this.emitAudit(false);
        return;
      }
      case 'online_players':
        return { ok: true, data: [
          { id: 12, key: 1, name: 'Tomás', ping: 43, played_seconds: 6930, tickets: 1 },
          { id: 37, key: 2, name: 'Meli', ping: 61, played_seconds: 3410, tickets: 1 },
          { id: 42, key: 3, name: 'Vale', ping: 29, played_seconds: 1580, tickets: 0 },
        ] };
      case 'staff_weekly': {
        const now = Math.floor(Date.now() / 1000);
        return { ok: true, data: { from: now - 604800, to: now, staff: [
          { actor: ME, duty_seconds: 7200, sessions: 2, resolved: 5, ratings: 4, avg_rating: 4.5 },
        ] } };
      }
      case 'player_profile':
      case 'player_profile_note': {
        const { id, body } = p as { id: number; body?: string };
        const ticket = this.tickets.find((item) => item.id === id);
        if (!ticket) return { ok: false, error: this.s('player_profile_missing') };
        const player = ticket.reporter;
        this.record(ME, action === 'player_profile' ? 'player_profile_view' : 'player_profile_note', player, body);
        this.emitAudit(false);
        const recent = (event: string) => this.entries.filter((entry) => entry.action === event && entry.target === player)
          .slice(-20).reverse().map(({ seq, ts, actor, reason }) => ({ seq, ts, actor, text: reason }));
        return { ok: true, data: {
          played_seconds: 7230,
          warns: recent('mod_warn'), bans: recent('mod_ban'), notes: recent('player_profile_note'),
          tickets: this.tickets.filter((item) => item.reporter === player).slice(0, 20)
            .map(({ id, state, created_ts: ts }) => ({ id, state, ts })),
        } };
      }
      case 'audit_verify': {
        const res = verify(this.entries);
        this.record(ME, 'audit_verify', '', res.ok ? 'ok' : `broken:${res.broken_at}`);
        this.emitAudit(true);
        return;
      }
      case 'ticket_claim':
      case 'ticket_close':
      case 'ticket_reopen':
        this.transition((p as { id: number }).id, action.slice(7));
        return;
      case 'ticket_transfer': {
        const { id, to } = p as OutgoingPayloads['ticket_transfer'];
        if (!STAFF.includes(to)) return this.toast('error', this.s('invalid_transition'));
        this.transition(id, 'transfer', { to });
        return;
      }
      case 'ticket_resolve': {
        const { id, resolution } = p as OutgoingPayloads['ticket_resolve'];
        this.transition(id, 'resolve', { resolution });
        return;
      }
      case 'ticket_cancel': {
        const { id } = p as OutgoingPayloads['ticket_cancel'];
        const t = this.tickets.find((x) => x.id === id);
        if (!t || t.reporter !== ME) return { ok: false, error: this.s('no_permission') };
        if (t.state !== 'open' && t.state !== 'reopened') return { ok: false, error: this.s('ticket_cancel_late') };
        t.state = 'closed';
        t.updated_ts = Math.round(Date.now() / 1000);
        this.record(ME, 'ticket_cancel', `ticket:${id}`, '', { from: 'open', to: 'closed' });
        this.emitTickets();
        this.emitAudit(false);
        return { ok: true };
      }
      case 'ticket_reply':
      case 'ticket_message': {
        const { id, body, internal = false } = p as OutgoingPayloads['ticket_message'];
        const t = this.tickets.find((x) => x.id === id);
        if (!t || !body.trim()) return;
        if (action === 'ticket_reply' && t.reporter !== ME) return;
        const ts = Math.round(Date.now() / 1000);
        t.messages.push({ author: ME, body: body.trim(), ts, internal });
        t.updated_ts = ts;
        this.record(ME, 'ticket_message', `ticket:${id}`, '', { internal });
        this.emitTickets();
        this.emitAudit(false);
        return;
      }
      case 'ticket_create': {
        const { category, priority, body, attach } = p as OutgoingPayloads['ticket_create'];
        const ts = Math.round(Date.now() / 1000);
        const id = Math.max(0, ...this.tickets.map((t) => t.id)) + 1;
        this.tickets.push({
          id, reporter: ME, category, priority, state: 'open', claimer: null, created_ts: ts, updated_ts: ts,
          description: body, messages: [], resolution: null, rating: null,
        });
        this.record(ME, 'ticket_create', ME, '', { ticket: id, category });
        if (attach) {
          const data = demoScreenshot(id, 1);
          this.evidenceData.set(`${id}:1`, data);
          this.tickets[this.tickets.length - 1].evidence = [{ n: 1, ts, by: ME, sha256: sha256Hex(data), size: data.length }];
          this.record(ME, 'ticket_evidence', `ticket:${id}`, '', { n: 1 });
        }
        this.emitTickets();
        this.emitAudit(false);
        this.emitDuty();
        this.toast('ok', this.s('report_created', { id }));
        return;
      }
      case 'ticket_rate': {
        const { id, score } = p as OutgoingPayloads['ticket_rate'];
        const t = this.tickets.find((x) => x.id === id);
        if (!t || t.rating != null || score < 1 || score > 5) return;
        t.rating = score;
        const who = this.staff.find((s) => s.actor === (t.resolved_by ?? t.claimer));
        if (who) who.avg_rating = who.avg_rating == null ? score : Math.round(((who.avg_rating * 4 + score) / 5) * 10) / 10;
        this.record(t.reporter, 'ticket_rate', `ticket:${id}`, '', { score });
        this.emitTickets();
        this.emitAudit(false);
        this.emitDuty();
        this.toast('ok', this.s('rating_thanks'));
        return;
      }
      case 'rate_dismiss':
        return;
      case 'ticket_evidence': {
        const { id } = p as OutgoingPayloads['ticket_evidence'];
        const t = this.tickets.find((x) => x.id === id);
        if (!t) return;
        const n = (t.evidence?.length ?? 0) + 1;
        const data = demoScreenshot(id, n);
        this.evidenceData.set(`${id}:${n}`, data);
        t.evidence = [...(t.evidence ?? []), { n, ts: Math.round(Date.now() / 1000), by: ME, sha256: sha256Hex(data), size: data.length }];
        this.record(ME, 'ticket_evidence', `ticket:${id}`, '', { n });
        this.emitTickets();
        this.emitAudit(false);
        this.toast('ok', this.s('evidence_saved', { n }));
        return;
      }
      case 'evidence_get': {
        const { id, n } = p as OutgoingPayloads['evidence_get'];
        const data = this.evidenceData.get(`${id}:${n}`);
        const item = this.tickets.find((x) => x.id === id)?.evidence?.find((e) => e.n === n);
        if (!data || !item) return this.toast('error', this.s('evidence_failed'));
        this.emit({ type: 'evidence', payload: { id, n, data, ok: sha256Hex(data) === item.sha256 } });
        return;
      }
      case 'goto_waypoint':
        this.toast('info', this.s('waypoint_no_marker'));
        return;
      case 'goto_coords': {
        const { x, y, z } = p as OutgoingPayloads['goto_coords'];
        this.toast('info', this.s('coords_ok'));
        this.record(ME, 'staff_coords_request', ME, '', { x, y, z });
        this.record(ME, 'staff_coords_result', ME, 'ok', { x, y, z });
        this.emitAudit(false);
        return;
      }
      case 'spectate_stop':
        return { ok: true };
      case 'staff_mode':
        return { ok: true };
      case 'owner_permissions': {
        const { target, field, value, reason } = p as OutgoingPayloads['owner_permissions'];
        const capabilities = ALL_CAPS.filter((cap) => cap !== 'admin.permissions');
        if (target === undefined) return { ok: true, data: { players: [{ id: 18, name: 'Dani' }],
          ranks: ['helper', 'moderator', 'admin', 'senior_admin'], capabilities } };
        const access = this.ownerAccess;
        if (field && value) {
          const previous = field === 'rank' ? access.rank : access.rules[field] ?? 'inherit';
          if (field === 'rank') access.rank = value;
          else access.rules[field] = value;
          this.record(ME, 'admin_permissions_change', access.identifier, reason, { field, previous, value });
          this.emitAudit(false);
        }
        return { ok: true, data: { ...access, rules: { ...access.rules } } };
      }
      case 'emergency_freeze': {
        const { enabled, reason } = p as OutgoingPayloads['emergency_freeze'];
        const last = [...this.entries].reverse().find((entry) => entry.action === 'mod_emergency_freeze');
        if (enabled !== undefined) {
          this.record(ME, 'mod_emergency_freeze', 'server', reason, { enabled });
          this.emitAudit(false);
        }
        return { ok: true, data: { enabled: enabled ?? (last?.payload?.includes('"enabled":true') ?? false) } };
      }
      case 'mod_action': {
        const { action: mod, target: destination, reason: customReason, duration: customDuration, template } = p as OutgoingPayloads['mod_action'];
        const target = typeof destination === 'string' ? destination : `src:${destination.id}`;
        const preset = template ? this.sanctionTemplates().find((item) => item.id === template && item.action === mod) : undefined;
        if (template && !preset) return this.toast('error', this.s('sanction_template_invalid'));
        const reason = preset?.reason ?? customReason;
        const duration = preset?.duration ?? customDuration;
        if (REASON_REQUIRED.has(mod) && !reason.trim()) return this.toast('error', this.s('reason_required'));
        if (mod === 'freeze' || mod === 'unfreeze') {
          this.emit({ type: 'freezeState', payload: { target, frozen: mod === 'freeze' } });
        }
        this.record(ME, `mod_${mod}`, target, reason.trim(), {
          action: mod,
          template,
          ...(mod === 'ban' && { expires_at: duration === 0 ? 0 : Math.round(Date.now() / 1000) + (duration ?? 86400) }),
        });
        if (mod === 'ban') {
          const now = Math.round(Date.now() / 1000);
          this.bans.unshift({ id: this.entries.length, identifier: target, actor: ME, reason: reason.trim(),
            created_at: now, expires_at: duration === 0 ? 0 : now + (duration ?? 86400), status: 'active', aliases: 1 });
        }
        this.emitAudit(false);
        this.toast('ok', this.s('ui_toast_mod_done', { action: this.s(`mod_${mod}`) }));
        return;
      }
      case 'duty_toggle': {
        const me = this.self();
        me.on_duty = !me.on_duty;
        if (me.on_duty) me.sessions += 1;
        this.record(ME, me.on_duty ? 'duty.in' : 'duty.out', ME);
        this.toast('info', me.on_duty ? this.s('duty_in') : this.s('duty_out', { time: '0.0h' }));
        this.emitDuty();
        this.emitAudit(false);
        return;
      }
    }
  }
}

export const backend = new MockBackend();
