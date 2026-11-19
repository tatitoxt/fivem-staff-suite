import { useEffect } from 'react';
import { DevHarness } from './components/DevHarness';
import { RatePrompt } from './components/RatePrompt';
import { Sidebar, useNav } from './components/Sidebar';
import { Toasts } from './components/Toasts';
import { Empty } from './components/ui';
import s from './components/layout.module.css';
import { useMock } from './nui';
import { isLite } from './edition';
import { AppProvider, useApp } from './store';
import { AuditView } from './views/AuditView';
import { DashboardView } from './views/DashboardView';
import { DutyView } from './views/DutyView';
import { SettingsView } from './views/SettingsView';
import { TicketsView } from './views/TicketsView';

function CurrentView() {
  const { state, dispatch, t } = useApp();
  const nav = useNav();
  const allowed = nav.some((n) => n.id === state.view);
  useEffect(() => {
    if (!allowed && nav.length) dispatch({ type: 'view', view: nav[0].id });
  }, [allowed, nav, dispatch]);
  if (!allowed) {
    return <main className={s.main}><Empty>{t('ui_no_access')}</Empty></main>;
  }
  switch (state.view) {
    case 'audit': return <AuditView />;
    case 'tickets': return <TicketsView />;
    case 'dashboard': return isLite ? null : <DashboardView />;
    case 'duty': return isLite ? null : <DutyView />;
    case 'settings': return <SettingsView />;
  }
}

function Shell() {
  const { state, send } = useApp();

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
              <div className={s.loading} aria-busy="true" />
            )}
            <Toasts />
          </div>
        </div>
      )}
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
