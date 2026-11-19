import { describe, expect, it } from 'vitest';
import { GENESIS, verify } from '../mock/chain';
import { TAMPER_SEQ, buildAudit, buildStaff, buildTickets, buildAlerts } from '../mock/demo';
import { sha256Hex as sha256 } from '../mock/sha256';

const NOW = 1_795_000_000;

describe('mock audit chain', () => {
  it('sha256 coincide con vectores conocidos', () => {
    expect(sha256('abc')).toBe('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(sha256('')).toBe('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
  });

  it('datos demo con el volumen de NUI_SPEC', () => {
    expect(buildAudit(NOW).length).toBeGreaterThanOrEqual(40);
    expect(buildTickets(NOW)).toHaveLength(12);
    expect(buildStaff()).toHaveLength(6);
    expect(buildAlerts(NOW)).toHaveLength(2);
  });

  it('la cadena demo verifica y detecta manipulación', () => {
    const entries = buildAudit(NOW);
    expect(entries[0].prev_hash).toBe(GENESIS);
    expect(verify(entries)).toEqual({ ok: true, broken_at: null });
    const tampered = entries.map((e) => (e.seq === TAMPER_SEQ ? { ...e, reason: 'editado' } : e));
    expect(verify(tampered)).toEqual({ ok: false, broken_at: TAMPER_SEQ });
  });
});
