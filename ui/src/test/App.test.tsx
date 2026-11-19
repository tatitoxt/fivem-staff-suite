import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { App } from '../App';
import { loadMock } from '../nui';

const nav = async (name: RegExp) => fireEvent.click(await screen.findByRole('button', { name }));

describe('NUI smoke', () => {
  it('renderiza las cinco vistas con los strings del init', async () => {
    render(<App />);
    expect(await screen.findByRole('heading', { name: 'Auditoría' })).toBeInTheDocument();
    expect(screen.getAllByTestId(/^entry-/).length).toBeGreaterThanOrEqual(40);

    await nav(/Reportes/);
    expect(await screen.findByRole('heading', { name: 'Reportes' })).toBeInTheDocument();
    expect(screen.getByLabelText('Cola de tickets').querySelectorAll('button')).toHaveLength(12);

    await nav(/Dashboard/);
    expect(await screen.findByText('Ranking del staff')).toBeInTheDocument();
    expect(screen.getByText('Alertas')).toBeInTheDocument();

    await nav(/Servicio/);
    expect(await screen.findByRole('heading', { name: 'Servicio' })).toBeInTheDocument();

    await nav(/Ajustes/);
    expect(await screen.findByRole('heading', { name: 'Ajustes' })).toBeInTheDocument();
  });

  it('verifica la cadena y marca la entrada manipulada', async () => {
    render(<App />);
    const verifyBtn = await screen.findByRole('button', { name: /Verificar cadena/ });
    fireEvent.click(verifyBtn);
    await waitFor(() => expect(screen.getByRole('button', { name: /Verificar cadena/ })).toBeEnabled());
    expect(screen.getByTestId('chain-status')).toHaveTextContent('Cadena íntegra');

    const { backend } = await loadMock();
    backend.tamper();
    fireEvent.click(screen.getByRole('button', { name: /Verificar cadena/ }));
    await waitFor(() => expect(screen.getByTestId('chain-status')).toHaveTextContent('Cadena rota en #27'));
    expect(within(screen.getByTestId('entry-27')).getByText('Alterada')).toBeInTheDocument();
    backend.restore();
  });

  it('reclama un ticket abierto', async () => {
    render(<App />);
    await nav(/Reportes/);
    fireEvent.click(await screen.findByRole('radio', { name: 'Abiertos' }));
    const queue = screen.getByLabelText('Cola de tickets');
    const first = queue.querySelector('button')!;
    fireEvent.click(first);
    fireEvent.click(screen.getByRole('button', { name: 'Reclamar' }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Reclamar' })).toBeDisabled());
  });

  it('cambia el idioma a inglés', async () => {
    render(<App />);
    await nav(/Ajustes/);
    fireEvent.click(await screen.findByRole('radio', { name: 'English' }));
    expect(await screen.findByRole('heading', { name: 'Settings' })).toBeInTheDocument();
  });

  it('oculta las secciones sin capability y salta a la primera permitida', async () => {
    render(<App />);
    await screen.findByTestId('chain-status');
    window.postMessage({
      type: 'init',
      payload: {
        locale: 'es', strings: {}, version: '0.1.0', config: {},
        player: { name: 'Lu.Helper', rank: 'helper', identifier: 'license:aa', capabilities: ['report.view', 'report.claim'] },
      },
    }, '*');
    // strings vacíos: t() devuelve la clave
    expect(await screen.findByRole('button', { name: /tab_tickets/ })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /tab_audit/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /ui_nav_dashboard/ })).not.toBeInTheDocument();
    await waitFor(() => expect(screen.getByRole('heading', { name: 'tab_tickets' })).toBeInTheDocument());
  });
});
