import { useEffect, useState } from 'react';
import { loadMock } from '../nui';
import { useApp } from '../store';
import s from './layout.module.css';

// Controles del harness de desarrollo. No se incluye en el build de producción.
export function DevHarness() {
  const { state } = useApp();
  const [tampered, setTampered] = useState(false);
  const [backend, setBackend] = useState<Awaited<ReturnType<typeof loadMock>>['backend'] | null>(null);
  useEffect(() => {
    void loadMock().then((m) => setBackend(m.backend));
  }, []);
  if (!backend) return null;
  return (
    <div className={s.harness}>
      <span>Harness dev</span>
      {!state.visible && <button onClick={() => window.postMessage({ type: 'open' }, '*')}>Abrir panel</button>}
      {tampered ? (
        <button onClick={() => { backend.restore(); setTampered(false); }}>Restaurar entrada #27</button>
      ) : (
        <button onClick={() => { backend.tamper(); setTampered(true); }}>Simular manipulación #27</button>
      )}
    </div>
  );
}
