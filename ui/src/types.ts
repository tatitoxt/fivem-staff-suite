import type { ThemePref } from './theme';
// Contrato NUI <-> Lua (NUI_SPEC.md). Los campos opcionales son los que el
// adapter puede omitir en actualizaciones parciales.

export type Capability = string;

export interface AuditEntry {
  seq: number;
  ts: number;
  actor: string;
  action: string;
  target: string;
  reason: string;
  payload: string;
  prev_hash: string;
  hash: string;
}

export interface VerifyResult {
  ok: boolean;
  broken_at: number | null;
}

export type TicketState = 'open' | 'claimed' | 'in_progress' | 'resolved' | 'closed' | 'reopened';
export type Priority = 'low' | 'normal' | 'high' | 'urgent';

export interface PlayerProfileEntry {
  seq: number;
  ts: number;
  actor: string;
  text: string;
  failed?: boolean;
}

export interface PlayerProfile {
  played_seconds?: number;
  warns: PlayerProfileEntry[];
  bans: PlayerProfileEntry[];
  notes: PlayerProfileEntry[];
  tickets: { id: number; state: TicketState; ts: number }[];
}

export interface SanctionTemplate {
  id: string;
  action: 'warn' | 'kick' | 'ban';
  reason: string;
  duration?: number;
}

export interface Msg {
  author: string;
  body: string;
  ts: number;
  internal: boolean;
}

export interface PublicMsg {
  mine: boolean;
  body: string;
  ts: number;
}

export interface ReporterTicket {
  id: number;
  category: string;
  state: TicketState;
  description?: string;
  messages: PublicMsg[];
}

export interface Ticket {
  id: number;
  reporter: string;
  category: string;
  priority: Priority;
  state: TicketState;
  claimer: string | null;
  created_ts: number;
  updated_ts: number;
  description?: string;
  messages: Msg[];
  resolution: string | null;
  rating: number | null;
  evidence?: Evidence[];
  first_response_ts?: number | null;
  resolved_by?: string | null;
}

export interface Evidence {
  n: number;
  ts: number;
  by: string;
  sha256: string;
  size: number;
}

export interface EvidencePayload {
  id: number;
  n: number;
  data: string;
  ok: boolean;
}

export interface CannedResponse {
  id: string;
  title: string;
  text: string;
}

export interface StaffStat {
  actor: string;
  on_duty: boolean;
  duty_hours: number;
  sessions: number;
  resolved: number;
  avg_response: number | null;
  avg_rating: number | null;
}

export type AlertSeverity = 'high' | 'medium' | 'low';

export interface Alert {
  id: string;
  kind: string;
  severity: AlertSeverity;
  actor: string;
  ts: number;
  vars?: Record<string, string | number>;
}

export interface Kpis {
  open: number;
  resolved: number;
  avg_response: number | null;
  avg_rating: number | null;
  on_duty: number;
}

export interface PlayerInfo {
  name: string;
  rank: string;
  identifier?: string;
  capabilities?: Capability[];
}

export interface TransferTarget {
  name: string;
  identifier: string;
}

export interface TicketCreateResult {
  ok: boolean;
  error?: string;
}

export interface UiConfig {
  core_url?: string;
  theme?: ThemePref;
  brand?: { name?: string; logo?: string; accent?: string };
  panel_key?: string;
  locales?: string[];
  categories?: string[];
  priorities?: Priority[];
  require_reason?: boolean;
  persistence?: string;
  export?: { webhook: boolean; file: boolean; anchor_every?: number; tickets?: boolean };
  transfer_targets?: TransferTarget[];
  canned?: CannedResponse[];
  evidence?: boolean;
  sanction_templates?: SanctionTemplate[];
  limits?: { ticket_body?: number; message_body?: number; resolution?: number; reason?: number; announcement?: number };
  warn_escalation?: { threshold: number; windowSeconds: number };
  cleanup_countdowns?: number[];
}

export interface InitPayload {
  locale: string;
  strings: Record<string, string>;
  version: string;
  player: PlayerInfo;
  config: UiConfig;
  theme?: ThemePref;
}

export interface AuditPayload {
  entries?: AuditEntry[];
  head?: string;
  verify?: VerifyResult;
}

export interface DashboardPayload {
  kpis: Kpis;
  leaderboard: StaffStat[];
  alerts: Alert[];
}

export interface DutyPayload {
  self: { on_duty: boolean };
  staff: StaffStat[];
}

export type ToastKind = 'ok' | 'error' | 'info';
export type NoticeKind = 'info' | 'reply' | 'warn' | 'announce' | 'report';
export interface NoticePayload { kind: NoticeKind; text: string; priority?: Priority; duration?: number; max?: number }

export type IncomingMessage =
  | { type: 'init'; payload: InitPayload }
  | { type: 'audit'; payload: AuditPayload }
  | { type: 'tickets'; payload: { tickets: Ticket[] | Record<string, Ticket> } }
  | { type: 'myTickets'; payload: { tickets: ReporterTicket[] | Record<string, ReporterTicket> } }
  | { type: 'frozenPlayers'; payload: Record<string, boolean> }
  | { type: 'freezeState'; payload: { target: string; frozen: boolean } }
  | { type: 'dashboard'; payload: DashboardPayload }
  | { type: 'duty'; payload: DutyPayload }
  | { type: 'toast'; payload: { kind: ToastKind; text: string; outside?: boolean } }
  | { type: 'notice'; payload: NoticePayload }
  | { type: 'rate'; payload: { id: number } }
  | { type: 'evidence'; payload: EvidencePayload }
  | { type: 'open'; payload?: { view?: ViewId } }
  | { type: 'close'; payload?: undefined };

export interface OutgoingPayloads {
  close_ui: Record<string, never>;
  set_locale: { locale: string };
  set_theme: { theme: ThemePref };
  audit_verify: Record<string, never>;
  audit_filter: { actor: string; action: string; from: number | null; to: number | null };
  ticket_claim: { id: number };
  ticket_transfer: { id: number; to: string };
  ticket_resolve: { id: number; resolution: string };
  ticket_close: { id: number };
  ticket_reopen: { id: number };
  ticket_message: { id: number; body: string; internal: boolean };
  ticket_export: { id: number };
  staff_chat: { body: string };
  online_players: Record<string, never>;
  staff_weekly: { export: boolean };
  staff_mode: { mode: 'noclip' | 'invisible' };
  emergency_freeze: { enabled?: boolean; reason?: string };
  owner_permissions: { target?: number; identifier?: string; field?: string; value?: string; reason?: string };
  player_profile: { id: number };
  player_profile_note: { id: number; body: string };
  ticket_reply: { id: number; body: string };
  ticket_create: { category: string; priority: Priority; body: string; attach?: boolean };
  mod_action: { action: ModAction; target: string | OnlinePlayerRef; reason: string; ticket?: number; duration?: number; template?: string };
  announce: { body: string };
  vehicle_cleanup: { seconds: number };
  vehicle_cleanup_cancel: Record<string, never>;
  ban_list: { page: number };
  ban_revoke: { id: number; reason: string };
  goto_waypoint: Record<string, never>;
  spectate_stop: Record<string, never>;
  duty_toggle: Record<string, never>;
  refresh: Record<string, never>;
  ticket_rate: { id: number; score: number };
  rate_dismiss: Record<string, never>;
  ticket_evidence: { id: number };
  evidence_get: { id: number; n: number };
}

export type OutgoingAction = keyof OutgoingPayloads;

export interface OnlinePlayerRef { id: number; key: number }
export interface WeeklyStaffRow {
  actor: string;
  duty_seconds: number;
  sessions: number;
  resolved: number;
  ratings: number;
  avg_rating?: number;
}
export interface WeeklyStaffReport { from: number; to: number; staff: WeeklyStaffRow[] }
export interface OnlinePlayer {
  id: number;
  key?: number;
  self?: boolean;
  name: string;
  ping: number;
  played_seconds: number;
  tickets?: number;
}

export interface BanRow {
  id?: number;
  identifier: string;
  actor: string;
  reason: string;
  created_at: number;
  expires_at: number;
  status: 'active' | 'expired' | 'revoked';
  aliases: number;
}

export type ModAction = 'goto' | 'bring' | 'spectate' | 'freeze' | 'unfreeze' | 'heal' | 'revive' | 'warn' | 'kick' | 'ban'
  | 'repair_vehicle' | 'delete_vehicle';

export type ViewId = 'audit' | 'tickets' | 'myReports' | 'dashboard' | 'duty' | 'players' | 'weekly' | 'settings';
