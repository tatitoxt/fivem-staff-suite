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
    locale: 'es', strings, version: '0.2.0', config: {},
    player: { name: 'Staff', rank: 'moderator', capabilities },
  } });
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete window.GetParentResourceName;
});

it('opens Players from Ctrl+K, searches by name and ID, and sends the active player reference', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn().mockImplementation(async (url: string) => ({
    json: async () => url.endsWith('/online_players') ? { ok: true, data: [
      { id: 18, key: 7, name: 'José', ping: 39, played_seconds: 300, tickets: 2 },
      { id: 24, key: 8, name: 'Meli', ping: 55, played_seconds: 754, tickets: 1 },
    ] } : { ok: true },
  }));
  vi.stubGlobal('fetch', transport);
  render(<App />);
  profile(['report.view']);
  dispatch({ type: 'open', payload: { view: 'settings' } });
  dispatch({ type: 'tickets', payload: { tickets: [] } });
  fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
  const playerCommand = { name: new RegExp(`^${strings.ui_nav_players}`) };
  expect(screen.queryByRole('option', playerCommand)).not.toBeInTheDocument();
  profile(['report.view', 'player.online.view', 'mod.goto']);
  fireEvent.click(screen.getByRole('option', playerCommand));
  expect(await screen.findByText('39 ms')).toBeInTheDocument();
  const search = screen.getByRole('textbox', { name: strings.ui_online_search });
  fireEvent.change(search, { target: { value: 'jose' } });
  expect(screen.queryByText('Meli')).not.toBeInTheDocument();
  fireEvent.change(search, { target: { value: '24' } });
  const row = screen.getByRole('row', { name: /#24 Meli/ });
  expect(within(row).queryByRole('button', { name: strings.mod_spectate })).not.toBeInTheDocument();
  fireEvent.click(within(row).getByRole('button', { name: strings.mod_goto }));
  expect(transport).toHaveBeenLastCalledWith('https://staff_suite/mod_action', expect.objectContaining({
    body: JSON.stringify({ action: 'goto', target: { id: 24, key: 8 }, reason: '' }),
  }));
});

it('offers a spectator exit command only with the spectate capability', () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn().mockResolvedValue({ json: async () => ({ ok: true }) });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  profile([]);
  dispatch({ type: 'open', payload: { view: 'settings' } });
  fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
  const command = { name: new RegExp(`^${strings.spectate_stop}`) };
  expect(screen.queryByRole('option', command)).not.toBeInTheDocument();
  profile(['mod.spectate']);
  fireEvent.click(screen.getByRole('option', command));
  expect(transport).toHaveBeenLastCalledWith('https://staff_suite/spectate_stop', expect.anything());
});

it('uses the audited export response to prepare a CSV and neutralizes spreadsheet formulas', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn().mockResolvedValue({ json: async () => ({
    ok: true, data: { from: 1700000000, to: 1700604800, staff: [
      { actor: '=HYPERLINK("a","b")', duty_seconds: 60, sessions: 1, resolved: 2, ratings: 0 },
    ] },
  }) });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  profile(['staff.analytics', 'staff.analytics.export']);
  dispatch({ type: 'open', payload: { view: 'weekly' } });
  dispatch({ type: 'dashboard', payload: {
    leaderboard: [], alerts: [], kpis: { open: 0, resolved: 0, avg_response: 0, avg_rating: 0, on_duty: 0 },
  } });
  fireEvent.click(await screen.findByRole('button', { name: strings.ui_weekly_export }));
  const csv = await screen.findByRole<HTMLTextAreaElement>('textbox', { name: strings.ui_weekly_csv });
  expect(csv.value).toContain(`"'=HYPERLINK(""a"",""b"")",60,1,2,0,`);
  expect(transport).toHaveBeenLastCalledWith('https://staff_suite/staff_weekly', expect.objectContaining({
    body: JSON.stringify({ export: true }),
  }));
});
