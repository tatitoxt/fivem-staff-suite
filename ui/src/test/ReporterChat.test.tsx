import { act, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { App } from '../App';
import { LOCALES } from '../mock/locales';
import type { IncomingMessage, Ticket } from '../types';

function dispatch(...messages: IncomingMessage[]) {
  act(() => {
    for (const data of messages) {
      window.dispatchEvent(new MessageEvent('message', { data, origin: 'https://nui-game-internal' }));
    }
  });
}

function setup() {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn();
  vi.stubGlobal('fetch', transport);
  render(<App />);
  return transport;
}

const profile = (capabilities: string[], escalation?: { threshold: number; windowSeconds: number }): IncomingMessage => ({
  type: 'init',
  payload: {
    locale: 'es', strings: LOCALES.es, version: '0.2.0',
    config: { limits: { message_body: 10 }, warn_escalation: escalation },
    player: { name: 'Alex', rank: 'player', capabilities },
  },
});

it('shows the configured warning escalation only for authorized staff', async () => {
  setup();
  const ticket: Ticket = {
    id: 1, reporter: 'license:reporter', state: 'open', category: 'bug', priority: 'normal',
    claimer: null, created_ts: 1, updated_ts: 1, description: 'Report', messages: [], resolution: null, rating: null,
  };
  const rule = { threshold: 3, windowSeconds: 600 };
  dispatch(profile(['report.view', 'mod.warn'], rule), { type: 'tickets', payload: { tickets: [ticket] } },
    { type: 'open', payload: { view: 'tickets' } });
  await screen.findByRole('button', { name: LOCALES.es.mod_warn });
  expect(screen.queryByText(/acumular 3 advertencias en 10 min/)).not.toBeInTheDocument();
  dispatch(profile(['report.view', 'mod.warn', 'mod.kick', 'mod.warn_escalate'], rule));
  expect(screen.getByText(/acumular 3 advertencias en 10 min/)).toBeInTheDocument();
});

afterEach(() => {
  vi.unstubAllGlobals();
  delete window.GetParentResourceName;
});

it('shows the public thread and keeps a reply draft until the server accepts it', async () => {
  const transport = setup();
  transport
    .mockResolvedValueOnce({ json: async () => ({ ok: false, error: LOCALES.es.rate_limited }) })
    .mockResolvedValueOnce({ json: async () => ({ ok: true }) });
  dispatch(profile([]), { type: 'open' }, { type: 'myTickets', payload: { tickets: [{
    id: 41, state: 'claimed', category: 'bug', description: 'Mi ticket',
    messages: [{ mine: false, body: 'Estamos investigando', ts: 1 }],
  }] } });
  expect(await screen.findByRole('heading', { name: LOCALES.es.ui_my_reports })).toBeInTheDocument();
  expect(screen.getByText('Estamos investigando')).toBeInTheDocument();
  expect(screen.queryByRole('button', { name: /^Reportes/ })).not.toBeInTheDocument();
  expect(screen.queryByRole('switch')).not.toBeInTheDocument();
  const draft = screen.getByRole('textbox', { name: LOCALES.es.ui_reply_placeholder });
  const send = screen.getByRole('button', { name: LOCALES.es.ui_send });
  fireEvent.change(draft, { target: { value: 'ñ'.repeat(6) } });
  expect(send).toBeDisabled();
  expect(screen.getByRole('alert')).toBeInTheDocument();
  fireEvent.change(draft, { target: { value: 'Gracias' } });
  fireEvent.click(send);
  expect(transport).toHaveBeenCalledWith('https://staff_suite/ticket_reply', expect.objectContaining({
    body: JSON.stringify({ id: 41, body: 'Gracias' }),
  }));
  expect(await screen.findByRole('alert')).toHaveTextContent(LOCALES.es.rate_limited);
  expect(draft).toHaveValue('Gracias');
  fireEvent.click(send);
  await waitFor(() => expect(draft).toHaveValue(''));
  dispatch({ type: 'myTickets', payload: { tickets: [] } });
  expect(screen.getByText(LOCALES.es.ui_my_reports_empty)).toBeInTheDocument();
});

it('requests a waypoint teleport with the staff capability and sends no coordinates', async () => {
  const transport = setup();
  transport.mockResolvedValue({ json: async () => ({ ok: true }) });
  dispatch(profile(['report.view']), { type: 'open', payload: { view: 'settings' } });
  expect(await screen.findByRole('heading', { name: LOCALES.es.ui_nav_settings })).toBeInTheDocument();
  expect(screen.queryByRole('button', { name: LOCALES.es.ui_waypoint_go })).not.toBeInTheDocument();
  fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
  expect(screen.queryByRole('option', { name: LOCALES.es.ui_waypoint_go })).not.toBeInTheDocument();
  fireEvent.keyDown(screen.getByRole('combobox', { name: LOCALES.es.ui_cmd_placeholder }), { key: 'Escape' });
  dispatch(profile(['report.view', 'staff.waypoint']));
  fireEvent.click(screen.getByRole('button', { name: LOCALES.es.ui_waypoint_go }));
  fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
  fireEvent.click(screen.getByRole('option', { name: LOCALES.es.ui_waypoint_go }));
  expect(transport).toHaveBeenCalledWith('https://staff_suite/goto_waypoint', expect.objectContaining({ body: '{}' }));
  expect(transport.mock.calls.filter(([url]) => url === 'https://staff_suite/goto_waypoint')).toHaveLength(2);
});

it('changes freeze to unfreeze on server confirmation and uses the same permission', async () => {
  const transport = setup();
  transport.mockResolvedValue({ json: async () => ({ ok: true }) });
  const target = 'license:target';
  const ticket: Ticket = {
    id: 1, state: 'open', reporter: target, category: 'bug', priority: 'normal', claimer: null,
    created_ts: 1, updated_ts: 1, messages: [], resolution: null, rating: null,
  };
  dispatch(profile(['report.view', 'mod.freeze']), { type: 'tickets', payload: { tickets: [ticket] } },
    { type: 'open', payload: { view: 'tickets' } });
  fireEvent.click(await screen.findByRole('button', { name: LOCALES.es.mod_freeze }));
  expect(transport).toHaveBeenCalledWith('https://staff_suite/mod_action', expect.objectContaining({
    body: JSON.stringify({ action: 'freeze', target, reason: '', ticket: 1 }),
  }));
  dispatch({ type: 'freezeState', payload: { target, frozen: true } });
  fireEvent.click(screen.getByRole('button', { name: LOCALES.es.mod_unfreeze }));
  expect(transport).toHaveBeenLastCalledWith('https://staff_suite/mod_action', expect.objectContaining({
    body: JSON.stringify({ action: 'unfreeze', target, reason: '', ticket: 1 }),
  }));
  dispatch(profile(['report.view']));
  expect(screen.getByRole('button', { name: LOCALES.es.mod_unfreeze })).toBeDisabled();
  dispatch({ type: 'freezeState', payload: { target, frozen: false } });
  expect(screen.getByRole('button', { name: LOCALES.es.mod_freeze })).toBeDisabled();
});
