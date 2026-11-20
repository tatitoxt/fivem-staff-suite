import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { App } from '../App';
import { dailySeries } from '../components/Sparkline';
import { backend } from '../mock/backend';

const nav = async (name: RegExp) => fireEvent.click(await screen.findByRole('button', { name }));

describe('NUI rediseño', () => {
  it('Ctrl+K abre la palette, filtra y ejecuta con Enter', async () => {
    render(<App />);
    await screen.findByTestId('chain-status');
    fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
    const input = await screen.findByRole('combobox', { name: /Buscá una vista/ });
    expect(input).toHaveFocus();
    fireEvent.change(input, { target: { value: 'dash' } });
    expect(within(screen.getByRole('listbox')).getAllByRole('option')).toHaveLength(1);
    fireEvent.keyDown(input, { key: 'Enter' });
    expect(await screen.findByRole('heading', { name: 'Dashboard' })).toBeInTheDocument();
    expect(screen.queryByRole('combobox', { name: /Buscá una vista/ })).not.toBeInTheDocument();
  });

  it('Escape en la palette la cierra sin cerrar el panel', async () => {
    render(<App />);
    await screen.findByTestId('chain-status');
    fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
    const input = await screen.findByRole('combobox', { name: /Buscá una vista/ });
    fireEvent.keyDown(input, { key: 'Escape' });
    await waitFor(() => expect(screen.queryByRole('combobox', { name: /Buscá una vista/ })).not.toBeInTheDocument());
    expect(screen.getByTestId('chain-status')).toBeInTheDocument();
  });

  it('los números cambian de vista, salvo mientras se escribe', async () => {
    render(<App />);
    await screen.findByTestId('chain-status');
    fireEvent.keyDown(window, { key: '3' });
    expect(await screen.findByRole('heading', { name: 'Dashboard' })).toBeInTheDocument();
    await nav(/Reportes/);
    const reason = await screen.findByPlaceholderText(/Obligatoria/);
    fireEvent.keyDown(reason, { key: '1' });
    expect(screen.getByRole('heading', { name: 'Reportes' })).toBeInTheDocument();
  });

  it('N abre el reporte rápido: tiles con flechas, captura y estado visible', async () => {
    const spy = vi.spyOn(backend, 'handle');
    render(<App />);
    await screen.findByTestId('chain-status');
    fireEvent.keyDown(window, { key: 'n' });
    const dialog = await screen.findByRole('dialog', { name: 'Nuevo reporte' });
    const group = within(dialog).getByRole('radiogroup');
    const player = within(group).getByRole('radio', { name: /Jugador/ });
    expect(player).toHaveAttribute('aria-checked', 'true');
    player.focus();
    fireEvent.keyDown(player, { key: 'ArrowLeft' });
    const bug = within(group).getByRole('radio', { name: /Bug/ });
    expect(bug).toHaveAttribute('aria-checked', 'true');
    expect(bug).toHaveFocus();
    const text = within(dialog).getByRole('textbox');
    fireEvent.change(text, { target: { value: 'El cajero no deposita' } });
    fireEvent.click(within(dialog).getByRole('checkbox', { name: /Adjuntar captura/ }));
    fireEvent.keyDown(text, { key: 'Enter', ctrlKey: true });
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(spy.mock.calls.some(([a, p]) => a === 'ticket_create' && (p as { attach?: boolean }).attach === true)).toBe(true);
    const step = await screen.findByText('Enviado');
    expect(step.closest('li')).toHaveAttribute('aria-current', 'step');
    spy.mockRestore();
  });

  it('dailySeries agrupa por día terminando hoy', () => {
    const now = 10 * 86400 + 3600;
    expect(dailySeries([now, now - 60, now - 86400, now - 8 * 86400], 7, now)).toEqual([0, 0, 0, 0, 0, 1, 2]);
  });
});
