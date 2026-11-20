import { act, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { App } from '../App';
import { LOCALES } from '../mock/locales';
import type { IncomingMessage, Ticket } from '../types';

const strings = LOCALES.es;

function dispatch(data: IncomingMessage) {
  act(() => window.dispatchEvent(new MessageEvent('message', { data, origin: 'https://nui-game-internal' })));
}

function profile(capabilities: string[], enabled: boolean) {
  dispatch({ type: 'init', payload: {
    locale: 'es', strings, version: '0.2.0', config: { export: { tickets: enabled, file: true, webhook: false } },
    player: { name: 'Alex', rank: 'admin', capabilities },
  } });
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete window.GetParentResourceName;
});

it('exports only the selected ticket ID and shows the confirmed result', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn().mockResolvedValue({ json: async () => ({ ok: true }) });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  const ticket: Ticket = {
    id: 42, reporter: 'license:reporter', state: 'open', category: 'bug', priority: 'normal',
    claimer: null, created_ts: 1, updated_ts: 1, description: 'Report', messages: [], resolution: null, rating: null,
  };
  profile(['report.view'], true);
  dispatch({ type: 'tickets', payload: { tickets: [ticket, { ...ticket, id: 43, created_ts: 0 }] } });
  dispatch({ type: 'open', payload: { view: 'tickets' } });
  expect(await screen.findByRole('heading', { name: /#42/ })).toBeInTheDocument();
  expect(screen.queryByRole('button', { name: strings.ui_ticket_export })).not.toBeInTheDocument();
  profile(['report.view', 'report.export'], false);
  expect(screen.queryByRole('button', { name: strings.ui_ticket_export })).not.toBeInTheDocument();
  profile(['report.view', 'report.export', 'player.profile.view'], true);
  fireEvent.click(screen.getByRole('button', { name: /#43/ }));
  expect(screen.getByRole('button', { name: strings.ui_player_profile })).toBeInTheDocument();
  fireEvent.click(screen.getByRole('button', { name: strings.ui_ticket_export }));
  expect(await screen.findByText(strings.ticket_export_sent)).toBeInTheDocument();
  expect(transport).toHaveBeenCalledWith('https://staff_suite/ticket_export', expect.objectContaining({
    body: JSON.stringify({ id: 43 }),
  }));
});
