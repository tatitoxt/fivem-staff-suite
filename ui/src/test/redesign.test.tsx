import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { App } from '../App';
import { dailySeries } from '../components/Sparkline';
import { backend } from '../mock/backend';

const nav = async (name: RegExp) => fireEvent.click(await screen.findByRole('button', { name }));

describe('NUI rediseño', () => {
  it('Ctrl+K abre la palette, filtra y ejecuta con Enter', async () => {
    render(<App />);
    await screen.findByTestId('chain-status', {}, { timeout: 3000 });
    fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
    const input = await screen.findByRole('combobox', { name: /Buscá una vista/ });
    expect(input).toHaveFocus();
    fireEvent.change(input, { target: { value: 'dash' } });
    expect(within(screen.getByRole('listbox')).getAllByRole('option')).toHaveLength(1);
    fireEvent.keyDown(input, { key: 'Enter' });
    expect(await screen.findByRole('heading', { name: 'Dashboard' }, { timeout: 3000 })).toBeInTheDocument();
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

  it('Ctrl+K no abre la palette sobre un diálogo, así Escape no descarta el borrador', async () => {
    render(<App />);
    await screen.findByTestId('chain-status');
    fireEvent.keyDown(window, { key: 'n' });
    const dialog = await screen.findByRole('dialog', { name: 'Nuevo reporte' });
    fireEvent.change(within(dialog).getByRole('textbox'), { target: { value: 'Borrador' } });
    fireEvent.keyDown(window, { key: 'k', ctrlKey: true });
    expect(screen.queryByRole('combobox', { name: /Buscá una vista/ })).not.toBeInTheDocument();
    expect(within(dialog).getByRole('textbox')).toHaveValue('Borrador');
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

  it('la actividad cuenta resoluciones por la auditoría, no por updated_ts', async () => {
    render(<App />);
    await screen.findByTestId('chain-status');
    fireEvent.keyDown(window, { key: '3' });
    const bars = await screen.findByRole('list', { name: 'Actividad de tickets' });
    const total = within(bars).getAllByRole('listitem')
      .reduce((n, el) => n + Number(/(\d+) resueltos/.exec(el.getAttribute('aria-label') ?? '')?.[1] ?? 0), 0);
    expect(total).toBe(2);
  });

  it('Ctrl+Enter envía el reporte aunque el foco esté en Cancelar', async () => {
    render(<App />);
    await screen.findByTestId('chain-status');
    fireEvent.keyDown(window, { key: 'n' });
    const dialog = await screen.findByRole('dialog', { name: 'Nuevo reporte' });
    fireEvent.change(within(dialog).getByRole('textbox'), { target: { value: 'Desde el footer' } });
    const cancel = within(dialog).getByRole('button', { name: 'Cancelar' });
    cancel.focus();
    fireEvent.keyDown(cancel, { key: 'Enter', ctrlKey: true });
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
  });

  it('un reporte resuelto sigue en Mis reportes con el paso Resuelto y sin respuesta', async () => {
    render(<App />);
    await screen.findByTestId('chain-status');
    await nav(/Mis reportes/);
    act(() => {
      window.dispatchEvent(new MessageEvent('message', { data: { type: 'myTickets', payload: { tickets: [
        { id: 42, category: 'bug', state: 'resolved', description: 'Cajero roto', messages: [] },
      ] } } }));
    });
    await waitFor(() => expect(screen.getAllByText('Resuelto').some((el) => el.closest('li')?.getAttribute('aria-current') === 'step')).toBe(true));
    expect(screen.queryByPlaceholderText(/Respondé al staff/)).not.toBeInTheDocument();
  });

  it('avisos con el panel cerrado: arriba a la derecha, máximo 3 y se van solos', async () => {
    render(<App />);
    await screen.findByTestId('chain-status');
    fireEvent.keyDown(window, { key: 'Escape' });
    await waitFor(() => expect(screen.queryByTestId('chain-status')).not.toBeInTheDocument());
    act(() => {
      for (let i = 1; i <= 4; i++) {
        window.dispatchEvent(new MessageEvent('message', { data: { type: 'notice', payload: { kind: 'reply', text: `Aviso ${i}`, duration: 300, max: 3 } } }));
      }
    });
    const region = await screen.findByRole('status', { name: 'Avisos' });
    expect(within(region).getAllByText(/^Aviso \d$/)).toHaveLength(3);
    expect(within(region).queryByText('Aviso 1')).not.toBeInTheDocument();
    expect(within(region).getAllByText('Respuesta del staff')).toHaveLength(3);
    await waitFor(() => expect(screen.queryByRole('status', { name: 'Avisos' })).not.toBeInTheDocument(), { timeout: 2000 });
  });

  it('dailySeries agrupa por día terminando hoy', () => {
    const now = 10 * 86400 + 3600;
    expect(dailySeries([now, now - 60, now - 86400, now - 8 * 86400], 7, now)).toEqual([0, 0, 0, 0, 0, 1, 2]);
  });
});
