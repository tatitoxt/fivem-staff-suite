import type { IncomingMessage, OutgoingAction, OutgoingPayloads } from './types';

// Capa de abstracción NUI. Dentro de FiveM habla con client/main.lua vía
// fetch a https://<resource>/<action>; en `npm run dev` (y en tests) usa un
// backend mock con datos demo que emite los mismos mensajes que el adapter.

declare global {
  interface Window {
    GetParentResourceName?: () => string;
    invokeNative?: (action: 'openUrl', url: string) => void;
  }
}

const INCOMING = new Set(['init', 'audit', 'tickets', 'dashboard', 'duty', 'toast', 'open', 'close']);

export function isNui(): boolean {
  return typeof window !== 'undefined' && typeof window.GetParentResourceName === 'function';
}

export function useMock(): boolean {
  return import.meta.env.DEV && !isNui();
}

export function isIncoming(data: unknown): data is IncomingMessage {
  return typeof data === 'object' && data !== null && INCOMING.has((data as { type?: string }).type ?? '');
}

type MockModule = typeof import('./mock/backend');
let mockPromise: Promise<MockModule> | null = null;
export function loadMock(): Promise<MockModule> {
  mockPromise ??= import('./mock/backend');
  return mockPromise;
}

export async function send<A extends OutgoingAction>(
  action: A,
  payload: OutgoingPayloads[A] = {} as OutgoingPayloads[A],
): Promise<unknown> {
  if (isNui()) {
    const resource = window.GetParentResourceName!();
    try {
      const res = await fetch(`https://${resource}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload),
      });
      return await res.json().catch(() => null);
    } catch {
      return null;
    }
  }
  if (useMock()) {
    const { backend } = await loadMock();
    return backend.handle(action, payload);
  }
  return null;
}

export function subscribe(cb: (msg: IncomingMessage) => void): () => void {
  const onMessage = (e: MessageEvent) => {
    if (isIncoming(e.data)) cb(e.data);
  };
  window.addEventListener('message', onMessage);
  if (useMock()) {
    void loadMock().then(({ backend }) => backend.start());
  }
  return () => window.removeEventListener('message', onMessage);
}
