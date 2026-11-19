import type { AuditEntry, VerifyResult } from '../types';
import { sha256Hex } from './sha256';

// Espejo de core/audit_chain.lua (canonical + verify) para el harness de dev.
export const GENESIS = '0'.repeat(64);
const FS = '\x1f';
const RS = '\x1e';

export function canonical(e: Omit<AuditEntry, 'hash' | 'prev_hash'>): string {
  return [e.seq, e.ts, e.actor, e.action, e.target, e.reason, e.payload ?? ''].map(String).join(FS);
}

export function append(
  entries: AuditEntry[],
  data: Pick<AuditEntry, 'ts' | 'actor' | 'action'> & Partial<Pick<AuditEntry, 'target' | 'reason' | 'payload'>>,
): AuditEntry {
  const prev_hash = entries.length ? entries[entries.length - 1].hash : GENESIS;
  const e = {
    seq: entries.length + 1, ts: data.ts, actor: data.actor, action: data.action,
    target: data.target ?? '', reason: data.reason ?? '', payload: data.payload ?? '', prev_hash,
  };
  const entry: AuditEntry = { ...e, hash: sha256Hex(canonical(e) + RS + prev_hash) };
  entries.push(entry);
  return entry;
}

export function verify(entries: AuditEntry[]): VerifyResult {
  let prev = GENESIS;
  for (let i = 0; i < entries.length; i++) {
    const e = entries[i];
    const seq = i + 1;
    if (e.seq !== seq || e.prev_hash !== prev) return { ok: false, broken_at: seq };
    if (e.hash !== sha256Hex(canonical(e) + RS + e.prev_hash)) return { ok: false, broken_at: seq };
    prev = e.hash;
  }
  return { ok: true, broken_at: null };
}
