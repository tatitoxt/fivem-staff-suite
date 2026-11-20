import { useEffect } from 'react';
import { DevHarness } from './components/DevHarness';
import { RatePrompt } from './components/RatePrompt';
import { Sidebar, useNav } from './components/Sidebar';
import { Toasts } from './components/Toasts';
import { Button, Empty } from './components/ui';
import s from './components/layout.module.css';
import { useMock } from './nui';
import { isLite } from './edition';
import { AppProvider, useApp } from './store';
import { AuditView } from './views/AuditView';
import { DashboardView } from './views/DashboardView';
import { DutyView } from './views/DutyView';
import { SettingsView } from './views/SettingsView';
import { TicketsView } from './views/TicketsView';
import { MyReportsView } from './views/MyReportsView';

function CurrentView() {
  const { state, dispatch, t, send } = useApp();
  const nav = useNav();
  const allowed = nav.some((n) => n.id === state.view);
  useEffect(() => {
    if (!allowed && nav.length) dispatch({ type: 'view', view: nav[0].id });
  }, [allowed, nav, dispatch]);
  if (!allowed) {
    return <main className={s.main}><Empty>{t('ui_no_access')}</Empty></main>;
  }
  if (state.view !== 'settings' && state.dataState === 'loading') {
    return (
      <main className={s.main}>
        <div className={s.loadingView} role="status"><span className={s.spinner} aria-hidden />{t('ui_loading')}</div>
      </main>
    );
  }
  if (state.view !== 'settings' && state.dataState === 'error') {
    return (
      <main className={s.main}>
        <div className={s.loadingView} role="alert">
          <span>{t('ui_load_error')}</span>
          <Button variant="primary" onClick={() => { dispatch({ type: 'retry' }); void send('refresh'); }}>{t('ui_retry')}</Button>
        </div>
      </main>
    );
  }
  switch (state.view) {
    case 'audit': return <AuditView />;
    case 'tickets': return <TicketsView />;
    case 'myReports': return <MyReportsView />;
    case 'dashboard': return isLite ? null : <DashboardView />;
    case 'duty': return isLite ? null : <DutyView />;
    case 'settings': return <SettingsView />;
  }
}

export const LOAD_TIMEOUT_MS = 8000;

function Shell() {
  const { state, dispatch, send } = useApp();

  useEffect(() => {
    if (!state.visible || state.dataState !== 'loading') return;
    const id = window.setTimeout(() => dispatch({ type: 'loadTimeout' }), LOAD_TIMEOUT_MS);
    return () => window.clearTimeout(id);
  }, [state.visible, state.dataState, dispatch]);

  useEffect(() => {
    document.documentElement.lang = state.locale;
  }, [state.locale]);

  useEffect(() => {
    if (!state.visible) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') void send('close_ui');
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [state.visible, send]);

  return (
    <>
      {state.visible && (
        <div className={s.stage}>
          <div className={s.panel}>
            {state.ready ? (
              <>
                <Sidebar />
                <CurrentView />
              </>
            ) : (
              <div className={s.loading} aria-busy="true"><span className={s.spinner} aria-hidden /></div>
            )}
            <Toasts />
          </div>
        </div>
      )}
      {!state.visible && state.toasts.some((toast) => toast.outside) && <Toasts outside />}
      {!isLite && state.ratePrompt != null && <RatePrompt />}
      {useMock() && <DevHarness />}
    </>
  );
}

export function App() {
  return (
    <AppProvider>
      <Shell />
    </AppProvider>
  );
}
