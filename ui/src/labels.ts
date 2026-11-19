import type { AlertSeverity, Priority, TicketState } from './types';

export type Tone = 'green' | 'orange' | 'red' | 'blue' | 'gray';
type T = (key: string, vars?: Record<string, string | number>) => string;

function tr(t: T, key: string, fallback: string): string {
  const v = t(key);
  return v === key ? fallback : v;
}

export const stateTone: Record<TicketState, Tone> = {
  open: 'green', reopened: 'red', claimed: 'orange', in_progress: 'orange', resolved: 'blue', closed: 'gray',
};

export const priorityTone: Record<Priority, Tone> = {
  urgent: 'red', high: 'orange', normal: 'blue', low: 'gray',
};

export const severityTone: Record<AlertSeverity, Tone> = { high: 'red', medium: 'orange', low: 'gray' };

export const PRIORITY_WEIGHT: Record<Priority, number> = { urgent: 3, high: 2, normal: 1, low: 0 };

export function stateLabel(t: T, s: TicketState) {
  return tr(t, `ui_state_${s}`, s);
}
export function priorityLabel(t: T, p: string) {
  return tr(t, `pri_${p}`, p);
}
export function categoryLabel(t: T, c: string) {
  return tr(t, `cat_${c}`, c);
}
export function actionLabel(t: T, action: string) {
  return tr(t, `ui_act_${action.replace(/\./g, '_')}`, action);
}
export function rankLabel(t: T, rank: string) {
  return tr(t, `ui_rank_${rank}`, rank);
}
