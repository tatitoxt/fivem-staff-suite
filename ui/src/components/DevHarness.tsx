import { useEffect, useState } from 'react';
import { isForumDemo, loadMock } from '../nui';
import { useApp } from '../store';
import s from './layout.module.css';

// Controles del simulador del navegador y de la demo para el foro.
export function DevHarness() {
  const { state, t } = useApp();
  const [tampered, setTampered] = useState(false);
  const [backend, setBackend] = useState<Awaited<ReturnType<typeof loadMock>>['backend'] | null>(null);
  useEffect(() => {
    void loadMock().then((m) => setBackend(m.backend));
  }, []);
  if (!backend) return null;
  return (
    <aside className={s.harness} aria-label={t('ui_demo_title')}>
      <span>{isForumDemo() ? t('ui_demo_title') : 'Harness dev'}</span>
      {!state.visible && <button onClick={() => window.postMessage({ type: 'open' }, window.location.origin)}>{t('ui_demo_open')}</button>}
      <button onClick={() => backend.promptRate()}>{t('ui_demo_rating')}</button>
      {tampered ? (
        <button onClick={() => { backend.restore(); setTampered(false); }}>{t('ui_demo_restore')}</button>
      ) : (
        <button onClick={() => { backend.tamper(); setTampered(true); }}>{t('ui_demo_tamper')}</button>
      )}
    </aside>
  );
}
