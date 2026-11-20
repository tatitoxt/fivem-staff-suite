import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { App } from '../App';
import { loadMock } from '../nui';
import { LOCALES } from '../mock/locales';

const nav = async (name: RegExp) => fireEvent.click(await screen.findByRole('button', { name }));

describe('NUI smoke', () => {
  it('renderiza las cinco vistas con los strings del init', async () => {
    render(<App />);
    expect(await screen.findByRole('heading', { name: 'Auditoría' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: LOCALES.es.ui_upgrade_core })).not.toBeInTheDocument();
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

  it('transfiere usando transfer_targets del server', async () => {
    render(<App />);
    await nav(/Reportes/);
    fireEvent.click(await screen.findByRole('radio', { name: 'Abiertos' }));
    fireEvent.click(screen.getByLabelText('Cola de tickets').querySelector('button')!);
    fireEvent.click(screen.getByRole('button', { name: 'Reclamar' }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Transferir' })).toBeEnabled());
    fireEvent.click(screen.getByRole('button', { name: 'Transferir' }));
    const dialog = await screen.findByRole('dialog');
    expect(within(dialog).getByRole('option', { name: 'Sofi.Mod' })).toBeInTheDocument();
  });

  it('muestra el export como sin dato si el server no lo informa', async () => {
    render(<App />);
    await screen.findByTestId('chain-status');
    window.postMessage({
      type: 'init',
      payload: { locale: 'es', strings: {}, version: '0.2.0', config: {}, player: { name: 'Fausto', rank: 'owner' } },
    }, '*');
    await nav(/ui_nav_settings/);
    expect(await screen.findAllByText('ui_export_unknown')).toHaveLength(2);
  });

  it('deshabilita Transferir sin report.resolve', async () => {
    render(<App />);
    await nav(/Reportes/);
    fireEvent.click(await screen.findByRole('radio', { name: 'Abiertos' }));
    fireEvent.click(screen.getByLabelText('Cola de tickets').querySelector('button')!);
    fireEvent.click(screen.getByRole('button', { name: 'Reclamar' }));
    await waitFor(() => expect(screen.getByRole('button', { name: 'Transferir' })).toBeEnabled());
    window.postMessage({
      type: 'init',
      payload: {
        locale: 'es', strings: LOCALES.es, version: '0.2.0', config: {},
        player: { name: 'Fausto', rank: 'mod', capabilities: ['report.view', 'report.claim'] },
      },
    }, '*');
    await waitFor(() => expect(screen.getByRole('button', { name: 'Transferir' })).toBeDisabled());
  });

  it('muestra bodies y nombres maliciosos como texto, sin HTML', async () => {
    render(<App />);
    await nav(/Reportes/);
    const xss = '<img src=x onerror="window.__xss=1"><script>window.__xss=1</script>';
    window.postMessage({
      type: 'tickets',
      payload: {
        tickets: [{
          id: 900, reporter: `license:${xss}`, category: 'bug', priority: 'urgent', state: 'open', claimer: null,
          created_ts: 1, updated_ts: 1, description: xss, resolution: null, rating: null,
          messages: [{ author: xss, body: xss, ts: 1, internal: false }],
        }],
      },
    }, '*');
    const queue = screen.getByLabelText('Cola de tickets');
    await waitFor(() => expect(queue.querySelectorAll('button')).toHaveLength(1));
    fireEvent.click(queue.querySelector('button')!);
    expect((await screen.findAllByText(xss)).length).toBeGreaterThanOrEqual(2);
    expect(document.querySelector('img[src="x"], script')).toBeNull();
    expect((window as unknown as { __xss?: number }).__xss).toBeUndefined();
  });

  it('conserva el borrador que supera el límite y bloquea el envío', async () => {
    const { container } = render(<App />);
    await nav(/Reportes/);
    window.postMessage({
      type: 'init',
      payload: {
        locale: 'es', strings: LOCALES.es, version: '0.2.0', config: { limits: { message_body: 10 } },
        player: { name: 'Fausto', rank: 'owner' },
      },
    }, '*');
    fireEvent.click(await screen.findByRole('radio', { name: 'Abiertos' }));
    fireEvent.click(screen.getByLabelText('Cola de tickets').querySelector('button')!);
    const draft = 'ñ'.repeat(6);
    fireEvent.change(container.querySelector('textarea')!, { target: { value: draft } });
    expect(await screen.findByRole('alert')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Enviar/ })).toBeDisabled();
    expect(container.querySelector('textarea')!.value).toBe(draft);
  });

  it('mantiene abierto el diálogo con el borrador si el server rechaza el reporte', async () => {
    const { backend } = await loadMock();
    const handle = backend.handle.bind(backend);
    const reject = ((action: string, payload: unknown) => (
      action === 'ticket_create'
        ? Promise.resolve({ ok: false, error: 'Ya tenés 3 reportes abiertos.' })
        : handle(action as never, payload as never)
    )) as typeof backend.handle;
    const spy = vi.spyOn(backend, 'handle').mockImplementation(reject);
    render(<App />);
    await nav(/Reportes/);
    fireEvent.click(await screen.findByRole('button', { name: /Nuevo ticket/ }));
    const dialog = await screen.findByRole('dialog');
    fireEvent.change(within(dialog).getByRole('textbox'), { target: { value: 'Me robaron el auto' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'Enviar reporte' }));
    expect(await within(dialog).findByText('Ya tenés 3 reportes abiertos.')).toBeInTheDocument();
    expect(within(dialog).getByRole('textbox')).toHaveValue('Me robaron el auto');

    spy.mockRestore();
    fireEvent.click(within(dialog).getByRole('button', { name: 'Enviar reporte' }));
    await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull());
  });

  it('inserta una respuesta predefinida en el mensaje', async () => {
    const { container } = render(<App />);
    await nav(/Reportes/);
    fireEvent.click(await screen.findByRole('radio', { name: 'Abiertos' }));
    fireEvent.click(screen.getByLabelText('Cola de tickets').querySelector('button')!);
    fireEvent.change(await screen.findByRole('combobox', { name: 'Respuestas predefinidas' }), { target: { value: 'greeting' } });
    expect(container.querySelector('textarea')!.value).toContain('ya estoy viendo tu reporte');
  });

  it('solicita una captura y la verifica contra el hash auditado', async () => {
    render(<App />);
    await nav(/Reportes/);
    fireEvent.click(await screen.findByRole('radio', { name: 'Abiertos' }));
    fireEvent.click(screen.getByLabelText('Cola de tickets').querySelector('button')!);
    fireEvent.click(await screen.findByRole('button', { name: /Solicitar captura/ }));
    expect(await screen.findByText('Captura #1')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Ver' }));
    const dialog = await screen.findByRole('dialog');
    expect(await within(dialog).findByText('Coincide con el hash auditado')).toBeInTheDocument();
    expect(within(dialog).getByRole('img')).toHaveAttribute('src', expect.stringMatching(/^data:image/));
  });

  it('el reporter valora el ticket resuelto', async () => {
    render(<App />);
    await screen.findByTestId('chain-status');
    const { backend } = await loadMock();
    const id = backend.promptRate();
    expect(id).not.toBeNull();
    const dialog = await screen.findByRole('dialog', { name: `Tu reporte #${id} fue resuelto` });
    fireEvent.click(within(dialog).getByRole('radio', { name: '4 de 5' }));
    fireEvent.click(within(dialog).getByRole('button', { name: 'Enviar valoración' }));
    expect(await screen.findByText('¡Gracias por tu valoración!')).toBeInTheDocument();
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument());
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
        locale: 'es', strings: {}, version: '0.2.0', config: {},
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
