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
  dispatch({
    type: 'init',
    payload: {
      locale: 'es', strings, version: '0.2.0', config: { cleanup_countdowns: [10, 30, 60] },
      player: { name: 'Alex', rank: 'admin', capabilities },
    },
  });
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete window.GetParentResourceName;
});

it('schedules a vehicle cleanup with the chosen countdown and lets staff cancel it', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn()
    .mockResolvedValueOnce({ json: async () => ({ ok: false, error: strings.cleanup_pending }) })
    .mockResolvedValueOnce({ json: async () => ({ ok: true, data: { seconds: 60 } }) })
    .mockResolvedValueOnce({ json: async () => ({ ok: true }) });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  profile([]);
  dispatch({ type: 'open', payload: { view: 'settings' } });
  expect(await screen.findByRole('heading', { name: strings.ui_nav_settings })).toBeInTheDocument();
  expect(screen.queryByRole('heading', { name: strings.ui_cleanup_title })).not.toBeInTheDocument();

  profile(['world.cleanup']);
  expect(await screen.findByRole('heading', { name: strings.ui_cleanup_title })).toBeInTheDocument();
  fireEvent.click(screen.getByRole('radio', { name: '60 s' }));
  fireEvent.click(screen.getByRole('button', { name: strings.ui_cleanup_start }));
  expect(await screen.findByRole('alert')).toHaveTextContent(strings.cleanup_pending);
  expect(transport).toHaveBeenCalledWith('https://staff_suite/vehicle_cleanup', expect.objectContaining({
    body: JSON.stringify({ seconds: 60 }),
  }));

  fireEvent.click(screen.getByRole('button', { name: strings.ui_cleanup_start }));
  const cancel = await screen.findByRole('button', { name: strings.ui_cleanup_cancel });
  const card = screen.getByRole('region', { name: strings.ui_cleanup_title });
  expect(within(card).getByRole('status')).toHaveTextContent('60');
  fireEvent.click(cancel);
  expect(await screen.findByRole('button', { name: strings.ui_cleanup_start })).toBeInTheDocument();
  expect(within(card).getByRole('status')).toHaveTextContent(strings.ui_cleanup_cancelled);
  expect(transport).toHaveBeenLastCalledWith('https://staff_suite/vehicle_cleanup_cancel', expect.anything());
});
