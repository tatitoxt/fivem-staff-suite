import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { App, LOAD_TIMEOUT_MS } from '../App';
import { LOCALES } from '../mock/locales';
import { initialState, reducer } from '../store';

const nav = async (name: RegExp) => fireEvent.click(await screen.findByRole('button', { name }));

describe('NUI pulido', () => {
  it('el grupo de filtros se maneja con flechas (roving tabindex)', async () => {
    render(<App />);
    await nav(/Reportes/);
    const all = await screen.findByRole('radio', { name: 'Todos' });
    const open = screen.getByRole('radio', { name: 'Abiertos' });
    expect(all).toHaveAttribute('tabindex', '0');
    expect(open).toHaveAttribute('tabindex', '-1');
    all.focus();
    fireEvent.keyDown(all, { key: 'ArrowRight' });
    await waitFor(() => expect(open).toHaveAttribute('aria-checked', 'true'));
    expect(open).toHaveFocus();
    fireEvent.keyDown(open, { key: 'End' });
    await waitFor(() => expect(screen.getByRole('radio', { name: 'Cerrados' })).toHaveFocus());
  });

  it('los diálogos atrapan el foco y lo devuelven al cerrar con Escape', async () => {
    render(<App />);
    await nav(/Reportes/);
    const opener = await screen.findByRole('button', { name: /Nuevo ticket/ });
    opener.focus();
    fireEvent.click(opener);
    const dialog = await screen.findByRole('dialog');
    const focusables = within(dialog).getAllByRole('button').filter((b) => !b.hasAttribute('disabled'));
    const last = focusables[focusables.length - 1];
    last.focus();
    fireEvent.keyDown(last, { key: 'Tab' });
    expect(dialog.contains(document.activeElement)).toBe(true);
    expect(document.activeElement).not.toBe(last);
    fireEvent.keyDown(document.activeElement!, { key: 'Escape' });
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
    expect(opener).toHaveFocus();
  });

  it('Escape cierra el panel', async () => {
    render(<App />);
    await nav(/Reportes/);
    fireEvent.keyDown(window, { key: 'Escape' });
    await waitFor(() => expect(screen.queryByRole('heading', { name: 'Reportes' })).not.toBeInTheDocument());
  });

  it('estados de datos: carga, error por timeout, reintento y listo', () => {
    let s = initialState(false);
    s = reducer(s, { type: 'msg', msg: { type: 'open' } });
    expect(s.dataState).toBe('loading');
    s = reducer(s, { type: 'loadTimeout' });
    expect(s.dataState).toBe('error');
    s = reducer(s, { type: 'retry' });
    expect(s.dataState).toBe('loading');
    s = reducer(s, { type: 'msg', msg: { type: 'tickets', payload: { tickets: [] } } });
    expect(s.dataState).toBe('ready');
    expect(reducer(s, { type: 'loadTimeout' }).dataState).toBe('ready');
    s = reducer(reducer(s, { type: 'msg', msg: { type: 'close' } }), { type: 'msg', msg: { type: 'open' } });
    expect(s.dataState).toBe('ready');
  });
});

describe('NUI dentro de FiveM', () => {
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
    delete (window as { GetParentResourceName?: () => string }).GetParentResourceName;
  });

  it('muestra carga, error con reintento y avisa si falla una acción', async () => {
    vi.useFakeTimers({ shouldAdvanceTime: true });
    (window as { GetParentResourceName?: () => string }).GetParentResourceName = () => 'staff_suite';
    const fetchMock = vi.fn().mockRejectedValue(new Error('sin callback'));
    vi.stubGlobal('fetch', fetchMock);
    render(<App />);
    act(() => {
      const fromNui = (data: unknown) => window.dispatchEvent(new MessageEvent('message', { data, origin: 'https://nui-game-internal' }));
      fromNui({
        type: 'init',
        payload: { locale: 'es', strings: LOCALES.es, version: '0.2.0', config: {}, player: { name: 'Fausto', rank: 'owner' } },
      });
      fromNui({ type: 'open', payload: { view: 'tickets' } });
    });
    expect(await screen.findByText('Cargando datos…')).toBeInTheDocument();

    await act(async () => { vi.advanceTimersByTime(LOAD_TIMEOUT_MS + 10); });
    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('No se pudieron cargar los datos del servidor.');
    fireEvent.click(within(alert).getByRole('button', { name: 'Reintentar' }));
    await waitFor(() => expect(fetchMock).toHaveBeenCalledWith('https://staff_suite/refresh', expect.anything()));
    expect(await screen.findByText('No se pudo completar la acción. Probá de nuevo.')).toBeInTheDocument();
    expect(screen.getByText('Cargando datos…')).toBeInTheDocument();
  });
});
