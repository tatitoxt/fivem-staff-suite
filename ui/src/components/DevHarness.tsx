import { useEffect, useState } from 'react';
import { loadMock } from '../nui';
import { useApp } from '../store';
import s from './layout.module.css';

// Controles del harness de desarrollo. No se incluye en el build de producción.
export function DevHarness() {
  const { state } = useApp();
  const [tampered, setTampered] = useState(false);
  const [noticeIdx, setNoticeIdx] = useState(0);
  const [backend, setBackend] = useState<Awaited<ReturnType<typeof loadMock>>['backend'] | null>(null);
  useEffect(() => {
    void loadMock().then((m) => setBackend(m.backend));
  }, []);
  if (!backend) return null;
  return (
    <aside className={s.harness} aria-label="Harness dev">
      <span>Harness dev</span>
      {!state.visible && <button onClick={() => window.postMessage({ type: 'open' }, '*')}>Abrir panel</button>}
      <button onClick={() => {
        const demo = [
          { kind: 'reply', text: 'Te respondieron el reporte #12.' },
          { kind: 'report', text: 'Reporte #13 · Jugador · prioridad Urgente', priority: 'urgent' },
          { kind: 'warn', text: 'Recibiste una advertencia del staff: lenguaje ofensivo por radio.' },
          { kind: 'announce', text: 'Reinicio del servidor en 10 minutos.' },
        ];
        const n = demo[noticeIdx % demo.length];
        setNoticeIdx((i) => i + 1);
        window.postMessage({ type: 'notice', payload: { ...n, duration: 6000, max: 3 } }, '*');
      }}>Simular aviso</button>
      <button onClick={() => backend.promptRate()}>Simular valoración del jugador</button>
      {tampered ? (
        <button onClick={() => { backend.restore(); setTampered(false); }}>Restaurar entrada #27</button>
      ) : (
        <button onClick={() => { backend.tamper(); setTampered(true); }}>Simular manipulación #27</button>
      )}
    </aside>
  );
}
