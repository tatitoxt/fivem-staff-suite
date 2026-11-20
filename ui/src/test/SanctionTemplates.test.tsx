import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { App } from '../App';
import { LOCALES } from '../mock/locales';
import type { IncomingMessage, Ticket } from '../types';

const strings = LOCALES.es;

function dispatch(data: IncomingMessage) {
  act(() => window.dispatchEvent(new MessageEvent('message', { data, origin: 'https://nui-game-internal' })));
}

function init(capabilities: string[]) {
  dispatch({ type: 'init', payload: {
    locale: 'es', strings, version: '0.2.0',
    config: { sanction_templates: [
      { id: 'evasion_day', action: 'ban', reason: strings.sanction_reason_evasion, duration: 86400 },
    ] },
    player: { name: 'Alex', rank: 'admin', capabilities },
  } });
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete window.GetParentResourceName;
});

it('shows the configured sanction only with permission and confirms its reason and duration', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn().mockResolvedValue({ json: async () => ({ ok: true }) });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  const ticket: Ticket = {
    id: 42, reporter: 'license:reporter', state: 'open', category: 'player', priority: 'normal',
    claimer: null, created_ts: 1, updated_ts: 1, description: 'Reporte', messages: [], resolution: null, rating: null,
  };
  const capabilities = ['report.view', 'mod.ban', 'mod.warn'];
  init(capabilities);
  dispatch({ type: 'tickets', payload: { tickets: [ticket] } });
  dispatch({ type: 'open', payload: { view: 'tickets' } });
  expect(await screen.findByRole('heading', { name: /#42/ })).toBeInTheDocument();
  expect(screen.queryByRole('combobox', { name: strings.ui_sanction_template })).not.toBeInTheDocument();
  init([...capabilities, 'mod.template']);
  fireEvent.change(screen.getByRole('combobox', { name: strings.ui_sanction_template }), {
    target: { value: 'evasion_day' },
  });
  expect(screen.getByRole('button', { name: strings.mod_warn })).toBeDisabled();
  fireEvent.click(screen.getByRole('button', { name: strings.mod_ban }));
  const dialog = within(screen.getByRole('dialog'));
  expect(dialog.getByText(new RegExp(strings.sanction_reason_evasion))).toBeInTheDocument();
  expect(dialog.getByText(strings.ui_sanction_duration.replace('%{seconds}', '86400'))).toBeInTheDocument();
  fireEvent.click(dialog.getByRole('button', { name: strings.mod_ban }));
  expect(transport).toHaveBeenCalledWith('https://staff_suite/mod_action', expect.objectContaining({
    body: JSON.stringify({ action: 'ban', target: 'license:reporter', reason: '', ticket: 42, template: 'evasion_day' }),
  }));
});
