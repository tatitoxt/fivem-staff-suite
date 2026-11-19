import { act, fireEvent, render, screen, within } from '@testing-library/react';
import { expect, it, vi } from 'vitest';
import { App } from '../App';
import { LOCALES } from '../mock/locales';

vi.mock('../edition', () => ({ isLite: true }));

it('keeps audit and basic tickets visible while hiding Core screens and controls', async () => {
  render(<App />);
  expect(await screen.findByRole('button', { name: 'Verificar cadena' })).toBeEnabled();
  expect(screen.queryByRole('button', { name: 'Dashboard' })).not.toBeInTheDocument();
  expect(screen.queryByRole('button', { name: 'Servicio' })).not.toBeInTheDocument();

  fireEvent.click(screen.getByRole('button', { name: /^Reportes/ }));
  expect(await screen.findByRole('button', { name: 'Reclamar' })).toBeInTheDocument();
  expect(screen.queryByRole('button', { name: 'Transferir' })).not.toBeInTheDocument();
  expect(screen.queryByRole('heading', { name: 'Moderación' })).not.toBeInTheDocument();
  expect(screen.queryByText(LOCALES.es.ui_chat_title)).not.toBeInTheDocument();
  expect(screen.queryByLabelText('Prioridad')).not.toBeInTheDocument();

  act(() => {
    window.dispatchEvent(new MessageEvent('message', {
      data: {
        type: 'init',
        payload: {
          locale: 'es', strings: LOCALES.es, version: '0.1.0', config: { evidence: true },
          player: { name: 'Staff', rank: 'lite_staff', capabilities: ['report.view', 'report.claim'] },
        },
      },
    }));
    window.dispatchEvent(new MessageEvent('message', { data: { type: 'rate', payload: { id: 1 } } }));
  });
  expect(screen.queryByRole('heading', { name: LOCALES.es.ui_evidence })).not.toBeInTheDocument();
  expect(screen.queryByRole('dialog')).not.toBeInTheDocument();

  fireEvent.click(screen.getByRole('button', { name: LOCALES.es.ui_ticket_new }));
  const create = await screen.findByRole('dialog');
  expect(within(create).queryByLabelText('Prioridad')).not.toBeInTheDocument();
  fireEvent.click(within(create).getByRole('button', { name: 'Cancelar' }));
  fireEvent.click(screen.getByRole('button', { name: 'Ajustes' }));
  expect(await screen.findByRole('heading', { name: 'Ajustes' })).toBeInTheDocument();
  expect(screen.queryByRole('heading', { name: 'Exportación de auditoría' })).not.toBeInTheDocument();
  expect(screen.getByText('JSON')).toBeInTheDocument();
});

it('opens the upgrade details and links to Tebex only when configured', async () => {
  render(<App />);
  const upgrade = await screen.findByRole('button', { name: LOCALES.es.ui_upgrade_core });
  fireEvent.click(upgrade);
  const dialog = screen.getByRole('dialog', { name: LOCALES.es.ui_upgrade_core });
  expect(within(dialog).getByText(LOCALES.es.ui_upgrade_details)).toBeInTheDocument();
  expect(within(dialog).queryByRole('link')).not.toBeInTheDocument();
  window.postMessage({
    type: 'init',
    payload: {
      locale: 'es', strings: LOCALES.es, version: '0.1.0',
      config: { core_url: 'https://example.tebex.io/package/123' },
      player: { name: 'Staff', rank: 'lite_staff', capabilities: ['report.view', 'audit.view'] },
    },
  }, '*');
  expect(await within(dialog).findByRole('link', { name: LOCALES.es.ui_upgrade_tebex }))
    .toHaveAttribute('href', 'https://example.tebex.io/package/123');
});
