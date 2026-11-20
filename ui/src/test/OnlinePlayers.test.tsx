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
  const transport = vi.fn().mockImplementation(async (_url: string, opts: RequestInit) => ({ json: async () => ({
    ok: true, data: { from: 1700000000, to: 1700604800, staff: [
      { actor: '=HYPERLINK("a","b")', duty_seconds: 60, sessions: 1,
        resolved: JSON.parse(String(opts.body)).export ? 2 : 0, ratings: 0 },
    ] },
  }) }));
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
  expect(within(screen.getByRole('row', { name: /HYPERLINK/ })).getByText('2')).toBeInTheDocument();
  expect(transport).toHaveBeenLastCalledWith('https://staff_suite/staff_weekly', expect.objectContaining({
    body: JSON.stringify({ export: true }),
  }));
});

it('only exposes staff movement modes authorized by the server in Ctrl+K', () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn().mockResolvedValue({ json: async () => ({ ok: true }) });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  profile(['staff.noclip']);
  dispatch({ type: 'open', payload: { view: 'settings' } });
  fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
  expect(screen.queryByRole('option', { name: new RegExp(strings.staff_mode_invisible) })).not.toBeInTheDocument();
  fireEvent.click(screen.getByRole('option', { name: new RegExp(strings.staff_mode_noclip) }));
  expect(transport).toHaveBeenLastCalledWith('https://staff_suite/staff_mode', expect.objectContaining({
    body: JSON.stringify({ mode: 'noclip' }),
  }));
});

it('requires a reason before requesting deletion of a player vehicle', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn().mockResolvedValue({ json: async () => ({ ok: true, data: [
    { id: 18, key: 7, name: 'José', ping: 39, played_seconds: 300 },
  ] }) });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  profile(['player.online.view', 'mod.delete_vehicle']);
  dispatch({ type: 'open', payload: { view: 'players' } });
  dispatch({ type: 'myTickets', payload: { tickets: [] } });
  fireEvent.click(await screen.findByRole('button', { name: strings.mod_delete_vehicle }));
  const dialog = within(screen.getByRole('dialog', { name: strings.mod_delete_vehicle }));
  expect(dialog.getByText(/José \(#18\)/)).toBeVisible();
  const submit = dialog.getByRole('button', { name: strings.mod_delete_vehicle });
  expect(submit).toBeDisabled();
  fireEvent.change(dialog.getByRole('textbox', { name: strings.ui_vehicle_reason }), { target: { value: 'bloqueo' } });
  fireEvent.click(submit);
  expect(transport).toHaveBeenLastCalledWith('https://staff_suite/mod_action', expect.objectContaining({
    body: JSON.stringify({ action: 'delete_vehicle', target: { id: 18, key: 7 }, reason: 'bloqueo' }),
  }));
});

it('loads emergency state and asks for a reason before a server-wide freeze', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn().mockImplementation(async (_url: string, opts: RequestInit) => ({
    json: async () => ({ ok: true, data: { enabled: JSON.parse(String(opts.body)).enabled ?? false } }),
  }));
  vi.stubGlobal('fetch', transport);
  render(<App />);
  profile(['mod.emergency_freeze']);
  dispatch({ type: 'open', payload: { view: 'settings' } });
  fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
  fireEvent.click(screen.getByRole('option', { name: new RegExp(strings.ui_emergency_title) }));
  const dialog = within(screen.getByRole('dialog', { name: strings.ui_emergency_title }));
  const freeze = await dialog.findByRole('button', { name: strings.ui_emergency_freeze });
  expect(freeze).toBeDisabled();
  fireEvent.change(dialog.getByRole('textbox', { name: strings.ui_vehicle_reason }), { target: { value: 'alerta' } });
  fireEvent.click(freeze);
  expect(await dialog.findByRole('button', { name: strings.ui_emergency_release })).toBeDisabled();
  expect(transport).toHaveBeenLastCalledWith('https://staff_suite/emergency_freeze', expect.objectContaining({
    body: JSON.stringify({ enabled: true, reason: 'alerta' }),
  }));
});

it('restricts the permissions editor to owners and sends a scoped ACE rule with a reason', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn().mockImplementation(async (_url: string, options: RequestInit) => {
    const request = JSON.parse(String(options.body));
    const data = request.target ? {
      id: 18, identifier: 'license:alex', rank: 'inherit', rules: { 'mod.kick': request.value ?? 'inherit' },
    } : { players: [{ id: 18, name: 'Alex' }], ranks: ['helper'], capabilities: ['mod.kick'] };
    return { json: async () => ({ ok: true, data }) };
  });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  profile(['admin.config']);
  dispatch({ type: 'open', payload: { view: 'settings' } });
  expect(screen.queryByRole('button', { name: strings.ui_permissions_title })).not.toBeInTheDocument();
  profile(['admin.permissions']);
  fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
  fireEvent.click(screen.getByRole('option', { name: new RegExp(strings.ui_permissions_title) }));
  const dialog = within(screen.getByRole('dialog', { name: strings.ui_permissions_title }));
  fireEvent.change(await dialog.findByRole('combobox', { name: strings.ui_permissions_player }), { target: { value: '18' } });
  fireEvent.change(await dialog.findByRole('combobox', { name: strings.ui_permissions_field }), { target: { value: 'mod.kick' } });
  fireEvent.change(dialog.getByRole('combobox', { name: strings.ui_permissions_value }), { target: { value: 'deny' } });
  const save = dialog.getByRole('button', { name: strings.ui_permissions_save });
  expect(save).toBeDisabled();
  fireEvent.change(dialog.getByRole('textbox', { name: strings.ui_vehicle_reason }), { target: { value: 'ajuste' } });
  fireEvent.click(save);
  expect(transport).toHaveBeenLastCalledWith('https://staff_suite/owner_permissions', expect.objectContaining({
    body: JSON.stringify({ target: 18, identifier: 'license:alex', field: 'mod.kick', value: 'deny', reason: 'ajuste' }),
  }));
});
