import { afterEach, describe, expect, it, vi } from 'vitest';
import { subscribe } from '../nui';

const toast = { type: 'toast', payload: { kind: 'ok', text: 'hola' } };

describe('subscribe', () => {
  afterEach(() => { delete window.GetParentResourceName; });

  it('solo acepta mensajes de NUI o de la propia página', () => {
    window.GetParentResourceName = () => 'staff_suite';
    const cb = vi.fn();
    const off = subscribe(cb);
    for (const origin of ['https://evil.example', 'null', '', 'https://cfx-nui-otro_recurso']) {
      window.dispatchEvent(new MessageEvent('message', { data: toast, origin }));
    }
    expect(cb).not.toHaveBeenCalled();
    for (const origin of ['nui://game', 'https://nui-game-internal', window.location.origin]) {
      window.dispatchEvent(new MessageEvent('message', { data: toast, origin }));
    }
    expect(cb).toHaveBeenCalledTimes(3);
    window.dispatchEvent(new MessageEvent('message', { data: { type: 'desconocido' }, origin: 'nui://game' }));
    expect(cb).toHaveBeenCalledTimes(3);
    off();
  });
});
