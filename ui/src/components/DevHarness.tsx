import { useEffect, useState } from 'react';
import { isForumDemo, loadMock } from '../nui';
import { useApp } from '../store';
import s from './layout.module.css';
import { Button } from './ui';

// Controles del simulador del navegador y de la demo para el foro.
export function DevHarness() {
  const { state, t } = useApp();
  const [tampered, setTampered] = useState(false);
  const [noticeIdx, setNoticeIdx] = useState(0);
  const [backend, setBackend] = useState<Awaited<ReturnType<typeof loadMock>>['backend'] | null>(null);
  useEffect(() => {
    void loadMock().then((m) => setBackend(m.backend));
  }, []);
  if (!backend) return null;
  return (
    <aside className={s.harness} aria-label={t('ui_demo_title')}>
      <span>{isForumDemo() ? t('ui_demo_title') : 'Harness dev'}</span>
      {!state.visible && <Button size="small" onClick={() => window.postMessage({ type: 'open' }, window.location.origin)}>{t('ui_demo_open')}</Button>}
      <Button size="small" onClick={() => {
        const demo = [
          { kind: 'reply', text: 'Te respondieron el reporte #12.' },
          { kind: 'report', text: 'Reporte #13 · Jugador · prioridad Urgente', priority: 'urgent' },
          { kind: 'warn', text: 'Recibiste una advertencia del staff: lenguaje ofensivo por radio.' },
          { kind: 'announce', text: 'Reinicio del servidor en 10 minutos.' },
        ];
        const n = demo[noticeIdx % demo.length];
        setNoticeIdx((i) => i + 1);
        window.postMessage({ type: 'notice', payload: { ...n, duration: 6000, max: 3 } }, window.location.origin);
      }}>Simular aviso</Button>
      <Button size="small" onClick={() => backend.promptRate()}>{t('ui_demo_rating')}</Button>
      {tampered ? (
        <Button size="small" onClick={() => { backend.restore(); setTampered(false); }}>{t('ui_demo_restore')}</Button>
      ) : (
        <Button size="small" onClick={() => { backend.tamper(); setTampered(true); }}>{t('ui_demo_tamper')}</Button>
      )}
    </aside>
  );
}
