import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { App } from '../App';
import { LOCALES } from '../mock/locales';
import type { IncomingMessage } from '../types';

const strings = LOCALES.es;

function dispatch(data: IncomingMessage) {
  act(() => window.dispatchEvent(new MessageEvent('message', { data, origin: 'https://nui-game-internal' })));
}

function profile(capabilities: string[]) {
  dispatch({ type: 'init', payload: {
    locale: 'es', strings, version: '0.2.0', config: { limits: { message_body: 8 } },
    player: { name: 'Alex', rank: 'helper', capabilities },
  } });
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete window.GetParentResourceName;
});

it('shows the composer to staff and preserves the draft after a rejected send', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const fetcher = vi.fn()
    .mockResolvedValueOnce({ json: async () => ({ ok: false, error: strings.rate_limited }) })
    .mockResolvedValueOnce({ json: async () => ({ ok: true }) });
  vi.stubGlobal('fetch', fetcher);
  render(<App />);
  profile([]);
  dispatch({ type: 'open', payload: { view: 'settings' } });
  expect(screen.queryByRole('form', { name: strings.ui_staff_chat })).not.toBeInTheDocument();
  profile(['staff.chat']);
  const form = within(await screen.findByRole('form', { name: strings.ui_staff_chat }));
  const input = form.getByRole('textbox');
  const send = form.getByRole('button', { name: strings.ui_send });
  fireEvent.change(input, { target: { value: 'ñññññ' } });
  expect(send).toBeDisabled();
  fireEvent.change(input, { target: { value: 'Hola' } });
  fireEvent.click(send);
  expect(await form.findByRole('alert')).toHaveTextContent(strings.rate_limited);
  expect(input).toHaveValue('Hola');
  fireEvent.click(send);
  expect(await form.findByRole('status')).toHaveTextContent(strings.staff_chat_sent);
  expect(input).toHaveValue('');
  expect(fetcher).toHaveBeenLastCalledWith('https://staff_suite/staff_chat', expect.objectContaining({
    body: JSON.stringify({ body: 'Hola' }),
  }));
});
