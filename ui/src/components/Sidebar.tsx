import { ArrowUpRight, Search, Clock3, Inbox, LayoutDashboard, Link2, MessageSquare, Settings, ShieldCheck, Check } from 'lucide-react';
import { useState, type ReactNode } from 'react';
import { isLite } from '../edition';
import { rankLabel } from '../labels';
import { useApp } from '../store';
import type { ViewId } from '../types';
import { Button, cx, Dialog, ui } from './ui';
import s from './layout.module.css';

export interface NavDef { id: ViewId; label: string; icon: ReactNode; cap?: string }

export function useNav(): NavDef[] {
  const { t, can } = useApp();
  const all: NavDef[] = [
    { id: 'audit', label: t('tab_audit'), icon: <ShieldCheck size={16} />, cap: 'audit.view' },
    { id: 'tickets', label: t('tab_tickets'), icon: <Inbox size={16} />, cap: 'report.view' },
    ...(isLite ? [] : [
      { id: 'dashboard', label: t('ui_nav_dashboard'), icon: <LayoutDashboard size={16} />, cap: 'staff.analytics' } as const,
      { id: 'duty', label: t('ui_nav_duty'), icon: <Clock3 size={16} />, cap: 'staff.duty' } as const,
    ]),
    { id: 'myReports', label: t('ui_my_reports'), icon: <MessageSquare size={16} /> },
    { id: 'settings', label: t('ui_nav_settings'), icon: <Settings size={16} /> },
  ];
  return all.filter((n) => !n.cap || can(n.cap));
}

const UPGRADE_FEATURES = ['ui_upgrade_f_moderation', 'ui_upgrade_f_duty', 'ui_upgrade_f_frameworks', 'ui_upgrade_f_audit'];

export function Sidebar() {
  const { state, dispatch, t, can } = useApp();
  const [showCore, setShowCore] = useState(false);
  const coreUrl = state.config.core_url && /^https:\/\/[^\s]+$/.test(state.config.core_url) ? state.config.core_url : null;
  const nav = useNav();
  const openTickets = state.tickets.filter((x) => x.state === 'open' || x.state === 'reopened').length;
  const broken = state.audit.verify?.ok === false;
  const name = state.player?.name ?? '';

  return (
    <aside className={s.sidebar}>
      <div className={s.brand}>
        <div className={s.logo}><Link2 size={16} strokeWidth={2.4} /></div>
        <div>
          <div className={s.brandName}>{t('panel_title')}</div>
          <div className={s.brandTag}>{isLite ? 'Free Lite' : t('ui_brand_tag')}</div>
        </div>
      </div>
      <button type="button" className={s.cmdk} onClick={() => dispatch({ type: 'palette', open: true })} aria-keyshortcuts="Control+K">
        <Search size={14} />
        <span>{t('ui_cmd_open')}</span>
        <span className={ui.kbd}>Ctrl K</span>
      </button>
      <nav className={s.nav} aria-label={t('panel_title')}>
        {nav.map((n, i) => (
          <button
            key={n.id}
            type="button"
            className={cx(s.navItem, state.view === n.id && s.navOn)}
            aria-current={state.view === n.id ? 'page' : undefined}
            aria-keyshortcuts={String(i + 1)}
            onClick={() => dispatch({ type: 'view', view: n.id })}
          >
            {n.icon}
            <span className={s.navLabel}>{n.label}</span>
            {n.id === 'tickets' && openTickets > 0 && <span className={s.navCount}>{openTickets}</span>}
            {n.id === 'audit' && broken && <span className={cx(s.navCount, s.navAlert)} aria-label={t('ui_chain_broken_short')}>!</span>}
            {!(n.id === 'tickets' && openTickets > 0) && !(n.id === 'audit' && broken) && <span className={s.navKey} aria-hidden>{i + 1}</span>}
          </button>
        ))}
      </nav>
      {isLite && can('report.view') && (
        <button type="button" className={s.upgrade} onClick={() => setShowCore(true)}>
          {t('ui_upgrade_core')} <ArrowUpRight size={15} />
        </button>
      )}
      {isLite && showCore && (
        <Dialog title={t('ui_upgrade_core')} onClose={() => setShowCore(false)} footer={(
          <>
            <Button onClick={() => setShowCore(false)}>{t('ui_cancel')}</Button>
            {coreUrl && (
              <a className={cx(ui.btn, ui.primary)} href={coreUrl} target="_blank" rel="noreferrer" onClick={(e) => {
                if (window.invokeNative) {
                  e.preventDefault();
                  window.invokeNative('openUrl', coreUrl);
                }
              }}>{t('ui_upgrade_tebex')} <ArrowUpRight size={15} aria-hidden /></a>
            )}
          </>
        )}>
          <p className={s.upgradeLead}>{t('ui_upgrade_details')}</p>
          <ul className={s.upgradeList}>
            {UPGRADE_FEATURES.map((key) => (
              <li key={key}><span className={s.upgradeCheck} aria-hidden><Check size={13} /></span>{t(key)}</li>
            ))}
          </ul>
        </Dialog>
      )}
      {state.player && (
        <div className={s.sideFooter}>
          <div className={s.avatar} aria-hidden>
            {name.slice(0, 1).toUpperCase()}
            {!isLite && <span className={cx(s.avatarDot, state.duty?.self.on_duty && s.avatarDotOn)} />}
          </div>
          <div className={s.who}>
            <div className={s.whoName}>{name}</div>
            <div className={s.whoRank}>
              {rankLabel(t, state.player.rank)}
              {!isLite && <> · {state.duty?.self.on_duty ? t('ui_status_on') : t('ui_status_off')}</>}
            </div>
          </div>
        </div>
      )}
    </aside>
  );
}
