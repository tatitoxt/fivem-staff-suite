import { act, fireEvent, render, screen } from '@testing-library/react';
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
    locale: 'es', strings, version: '0.2.0', config: { limits: { reason: 8 } },
    player: { name: 'Alex', rank: 'admin', capabilities },
  } });
}

afterEach(() => {
  vi.unstubAllGlobals();
  delete window.GetParentResourceName;
});

it('lists bans for reviewers and requires a bounded reason for revocation', async () => {
  const row = { id: 1, identifier: 'license:alex', actor: 'owner', reason: 'Abuso', expires_at: 0, status: 'active', aliases: 2 };
  window.GetParentResourceName = () => 'staff_suite';
  const transport = vi.fn()
    .mockResolvedValueOnce({ json: async () => ({ ok: true, data: { rows: [row], hasMore: false } }) })
    .mockResolvedValueOnce({ json: async () => ({ ok: true }) })
    .mockResolvedValueOnce({ json: async () => ({ ok: true, data: { rows: [{ ...row, status: 'revoked' }] } }) });
  vi.stubGlobal('fetch', transport);
  render(<App />);
  profile([]);
  dispatch({ type: 'open', payload: { view: 'settings' } });
  expect(await screen.findByRole('heading', { name: strings.ui_nav_settings })).toBeInTheDocument();
  expect(screen.queryByRole('button', { name: strings.ban_review_title })).not.toBeInTheDocument();
  fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
  const palette = screen.getByRole('combobox', { name: strings.ui_cmd_placeholder });
  expect(screen.queryByRole('option', { name: strings.ban_review_title })).not.toBeInTheDocument();

  profile(['ban.view']);
  expect(screen.getByRole('button', { name: strings.ban_review_title })).toBeInTheDocument();
  fireEvent.change(palette, { target: { value: strings.ban_review_title } });
  fireEvent.keyDown(palette, { key: 'Enter' });
  expect(await screen.findByRole('dialog', { name: strings.ban_review_title })).toBeInTheDocument();
  expect(await screen.findByText('Abuso')).toBeInTheDocument();
  expect(screen.queryByRole('button', { name: strings.ban_review_revoke })).not.toBeInTheDocument();

  profile(['ban.view', 'ban.revoke']);
  fireEvent.click(screen.getByRole('button', { name: strings.ban_review_revoke }));
  const submit = screen.getByRole('button', { name: strings.ban_review_revoke });
  expect(submit).toBeDisabled();
  const reason = screen.getByRole('textbox', { name: strings.ban_review_reason });
  fireEvent.change(reason, { target: { value: 'ñ'.repeat(5) } });
  expect(submit).toBeDisabled();
  fireEvent.change(reason, { target: { value: 'Apelar' } });
  fireEvent.click(submit);
  expect(await screen.findByText(strings.ban_review_revoked)).toBeInTheDocument();
  expect(transport).toHaveBeenCalledWith('https://staff_suite/ban_revoke', expect.objectContaining({
    body: JSON.stringify({ id: 1, reason: 'Apelar' }),
  }));
});
