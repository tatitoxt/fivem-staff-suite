import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { App } from '../App';
import { LOCALES } from '../mock/locales';
import type { IncomingMessage } from '../types';

const strings = LOCALES.es;

function dispatch(data: IncomingMessage) {
  act(() => window.dispatchEvent(new MessageEvent('message', { data, origin: 'https://nui-game-internal' })));
}

function profile(capabilities: string[]) {
  dispatch({
    type: 'init',
    payload: {
      locale: 'es', strings, version: '0.2.0', config: { limits: { announcement: 10 } },
      player: { name: 'Alex', rank: 'admin', capabilities },
    },
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete window.GetParentResourceName;
});

it('only lets authorized staff submit and keeps the draft on rejection', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn()
    .mockResolvedValueOnce({ json: async () => ({ ok: false, error: strings.rate_limited }) })
    .mockResolvedValueOnce({ json: async () => ({ ok: true }) });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  profile([]);
  dispatch({ type: 'open', payload: { view: 'settings' } });
  expect(await screen.findByRole('heading', { name: strings.ui_nav_settings })).toBeInTheDocument();
  expect(screen.queryByRole('textbox', { name: strings.announcement_title })).not.toBeInTheDocument();

  profile(['staff.announce']);
  const draft = screen.getByRole('textbox', { name: strings.announcement_title });
  const send = screen.getByRole('button', { name: strings.ui_announcement_send });
  fireEvent.change(draft, { target: { value: 'ñ'.repeat(6) } });
  expect(send).toBeDisabled();
  fireEvent.change(draft, { target: { value: '  Aviso  ' } });
  fireEvent.click(send);
  expect(await screen.findByRole('alert')).toHaveTextContent(strings.rate_limited);
  expect(draft).toHaveValue('  Aviso  ');
  expect(transport).toHaveBeenCalledWith('https://staff_suite/announce', expect.objectContaining({
    body: JSON.stringify({ body: 'Aviso' }),
  }));
  fireEvent.click(send);
  await waitFor(() => expect(draft).toHaveValue(''));
  const form = screen.getByRole('form', { name: strings.announcement_title });
  expect(within(form).getByRole('status')).toHaveTextContent(strings.announcement_sent);
});
