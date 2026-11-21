import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, expect, it, vi } from 'vitest';
import { App } from '../App';
import { LOCALES } from '../mock/locales';
import type { IncomingMessage, PlayerProfile, Ticket } from '../types';

const strings = LOCALES.es;

function dispatch(data: IncomingMessage) {
  act(() => window.dispatchEvent(new MessageEvent('message', { data, origin: 'https://nui-game-internal' })));
}

function profile(capabilities: string[]) {
  dispatch({ type: 'init', payload: {
    locale: 'es', strings, version: '0.2.0', config: { limits: { message_body: 16 } },
    player: { name: 'Alex', rank: 'moderator', capabilities },
  } });
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete window.GetParentResourceName;
});

it('loads only the selected reporter and lets eligible staff add a bounded note', async () => {
  window.GetParentResourceName = () => 'staff_suite';
  const history: PlayerProfile = {
    played_seconds: 3720,
    warns: [{ seq: 1, ts: 1, actor: 'staff', text: 'Advertencia previa' }],
    bans: [], notes: [], tickets: [{ id: 42, state: 'open', ts: 1 }],
  };
  const saved = { ...history, notes: [{ seq: 3, ts: 1, actor: 'staff', text: 'Revisar caso' }] };
  const transport = vi.fn()
    .mockResolvedValueOnce({ json: async () => ({ ok: true, data: history }) })
    .mockResolvedValueOnce({ json: async () => ({ ok: true, data: saved }) });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  const ticket: Ticket = {
    id: 42, reporter: 'license:reporter', state: 'open', category: 'bug', priority: 'normal',
    claimer: null, created_ts: 1, updated_ts: 1, description: 'Report', messages: [], resolution: null, rating: null,
  };
  profile(['report.view']);
  dispatch({ type: 'tickets', payload: { tickets: [ticket] } });
  dispatch({ type: 'open', payload: { view: 'tickets' } });
  expect(await screen.findByRole('heading', { name: /#42/ })).toBeInTheDocument();
  expect(screen.queryByRole('button', { name: strings.ui_player_profile })).not.toBeInTheDocument();
  profile(['report.view', 'player.profile.view']);
  fireEvent.click(screen.getByRole('button', { name: strings.ui_player_profile }));
  const dialog = within(screen.getByRole('dialog', { name: strings.ui_player_profile }));
  expect(await dialog.findByText('Advertencia previa')).toBeInTheDocument();
  expect(dialog.getByText(`${strings.ui_player_profile_playtime} · 1 h 2 min`)).toBeInTheDocument();
  expect(dialog.queryByRole('textbox')).not.toBeInTheDocument();
  profile(['report.view', 'player.profile.view', 'player.profile.note']);
  const input = dialog.getByRole('textbox', { name: strings.ui_player_profile_note });
  const save = dialog.getByRole('button', { name: strings.ui_player_profile_save });
  fireEvent.change(input, { target: { value: 'ñ'.repeat(9) } });
  expect(save).toBeDisabled();
  fireEvent.change(input, { target: { value: 'Revisar caso' } });
  fireEvent.click(save);
  expect((await dialog.findAllByText('Revisar caso')).length).toBeGreaterThan(0);
  expect(transport).toHaveBeenNthCalledWith(2, 'https://staff_suite/player_profile',
    expect.objectContaining({ body: JSON.stringify({ id: 42 }) }));
  expect(transport).toHaveBeenNthCalledWith(3, 'https://staff_suite/player_profile_note',
    expect.objectContaining({ body: JSON.stringify({ id: 42, body: 'Revisar caso' }) }));
});
