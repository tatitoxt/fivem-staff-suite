import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { App } from '../App';
import { LOCALES } from '../mock/locales';
import type { IncomingMessage, Ticket } from '../types';

const strings = LOCALES.es;

function dispatch(data: IncomingMessage) {
  act(() => window.dispatchEvent(new MessageEvent('message', { data, origin: 'https://nui-game-internal' })));
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete window.GetParentResourceName;
});

it('previews the preset reason and duration and sends only the preset ID for the sanction', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn().mockResolvedValue({ json: async () => ({ ok: true }) });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  const ticket: Ticket = {
    id: 42, reporter: 'license:reporter', state: 'open', category: 'bug', priority: 'normal',
    claimer: null, created_ts: 1, updated_ts: 1, description: 'Report', messages: [], resolution: null, rating: null,
  };
  const capabilities = ['report.view', 'mod.warn', 'mod.ban', 'mod.freeze'];
  const init = (caps: string[]) => dispatch({ type: 'init', payload: {
    locale: 'es', strings, version: '0.2.0', config: {
      sanction_templates: [{ id: 'evasion_day', action: 'ban', reason: 'Motivo fijo', duration: 86400 }],
    },
    player: { name: 'Alex', rank: 'admin', capabilities: caps },
  } });
  init(capabilities);
  dispatch({ type: 'tickets', payload: { tickets: [ticket] } });
  dispatch({ type: 'open', payload: { view: 'tickets' } });
  expect(await screen.findByRole('heading', { name: /#42/ })).toBeInTheDocument();
  expect(screen.queryByLabelText(strings.ui_sanction_template)).not.toBeInTheDocument();
  init([...capabilities, 'mod.template']);
  const selector = await screen.findByLabelText(strings.ui_sanction_template);
  fireEvent.change(screen.getByLabelText(strings.ui_mod_reason), { target: { value: 'Borrador manual' } });
  fireEvent.change(selector, { target: { value: 'evasion_day' } });
  expect(screen.getByRole('button', { name: strings.mod_warn })).toBeDisabled();
  expect(screen.getByLabelText(strings.ui_mod_reason)).toHaveValue('Motivo fijo');
  fireEvent.click(screen.getByRole('button', { name: strings.mod_freeze }));
  expect(transport).toHaveBeenCalledWith('https://staff_suite/mod_action', expect.objectContaining({
    body: JSON.stringify({ action: 'freeze', target: 'license:reporter', reason: '', ticket: 42 }),
  }));
  fireEvent.click(screen.getByRole('button', { name: strings.mod_ban }));
  const dialog = within(screen.getByRole('dialog', { name: strings.ui_confirm_ban_title }));
  expect(dialog.getByText(/Motivo fijo/)).toBeInTheDocument();
  expect(dialog.getByText(/86400/)).toBeInTheDocument();
  fireEvent.click(dialog.getByRole('button', { name: strings.mod_ban }));
  expect(transport).toHaveBeenCalledWith('https://staff_suite/mod_action', expect.objectContaining({
    body: JSON.stringify({ action: 'ban', target: 'license:reporter', reason: '', ticket: 42, template: 'evasion_day' }),
  }));
});
