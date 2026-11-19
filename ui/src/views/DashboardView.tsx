import { Activity, CheckCircle2, Inbox, ShieldAlert, Star, Timer, Users } from 'lucide-react';
import type { ReactNode } from 'react';
import { Badge, Button, Empty, ViewHeader, cx, ui } from '../components/ui';
import lay from '../components/layout.module.css';
import { formatDuration, formatNumber, formatRelative, shortId } from '../format';
import { severityTone } from '../labels';
import { useApp } from '../store';
import v from './views.module.css';

function Kpi({ icon, tone, label, value }: { icon: ReactNode; tone: [string, string]; label: string; value: string }) {
  return (
    <div className={cx(ui.card, v.kpi)}>
      <div className={v.kpiLabel}>
        <span className={v.kpiIcon} style={{ background: tone[0], color: tone[1] }}>{icon}</span>
        {label}
      </div>
      <div className={v.kpiValue}>{value}</div>
    </div>
  );
}

export function DashboardView() {
  const { state, dispatch, t } = useApp();
  const d = state.dashboard;
  const loc = state.locale;
  return (
    <main className={lay.main}>
      <ViewHeader title={t('ui_nav_dashboard')} subtitle={t('ui_dashboard_sub')} />
      <div className={lay.viewBody}>
        <div className={v.kpis}>
          <Kpi icon={<Inbox size={18} />} tone={['var(--orange-soft)', 'var(--orange-ink)']} label={t('ui_kpi_open')} value={d ? String(d.kpis.open) : '—'} />
          <Kpi icon={<CheckCircle2 size={18} />} tone={['var(--green-soft)', 'var(--green-strong)']} label={t('ui_kpi_resolved')} value={d ? String(d.kpis.resolved) : '—'} />
          <Kpi icon={<Timer size={18} />} tone={['var(--blue-soft)', 'var(--blue-ink)']} label={t('ui_kpi_response')} value={formatDuration(d?.kpis.avg_response)} />
          <Kpi icon={<Star size={18} />} tone={['var(--orange-soft)', 'var(--orange-ink)']} label={t('ui_kpi_rating')} value={formatNumber(d?.kpis.avg_rating, loc)} />
          <Kpi icon={<Users size={18} />} tone={['var(--green-soft)', 'var(--green-strong)']} label={t('ui_kpi_on_duty')} value={d ? String(d.kpis.on_duty) : '—'} />
        </div>
        <div className={v.dashGrid}>
          <section className={cx(ui.card, v.section)}>
            <div className={v.sectionHead}><h2>{t('ui_leaderboard')}</h2></div>
            {d?.leaderboard.length ? (
              <div className={cx(ui.scroll, v.tableWrap)}>
                <table className={v.table}>
                  <thead>
                    <tr>
                      <th>#</th>
                      <th>{t('ui_col_staff')}</th>
                      <th className={v.num}>{t('ui_col_resolved')}</th>
                      <th className={v.num}>{t('ui_col_response')}</th>
                      <th className={v.num}>{t('ui_col_rating')}</th>
                      <th className={v.num}>{t('ui_col_hours')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {d.leaderboard.map((s, i) => (
                      <tr key={s.actor}>
                        <td className={v.rankCell}>{i + 1}</td>
                        <td>
                          <span className={v.staffCell}>
                            <span className={cx(v.statusDot, s.on_duty && v.statusOn)} title={s.on_duty ? t('ui_status_on') : t('ui_status_off')} />
                            {shortId(s.actor)}
                          </span>
                        </td>
                        <td className={v.num}>{s.resolved}</td>
                        <td className={v.num}>{formatDuration(s.avg_response)}</td>
                        <td className={v.num}>
                          <span className={v.ratingCell}><Star size={14} fill="currentColor" />{formatNumber(s.avg_rating, loc)}</span>
                        </td>
                        <td className={v.num}>{formatNumber(s.duty_hours, loc)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <Empty icon={<Activity size={22} />}>{t('ui_leaderboard_empty')}</Empty>
            )}
          </section>
          <section className={cx(ui.card, v.section)}>
            <div className={v.sectionHead}>
              <h2>{t('ui_alerts')}</h2>
              {!!d?.alerts.length && <Badge tone="red">{d.alerts.length}</Badge>}
            </div>
            {d?.alerts.length ? (
              <div className={cx(ui.scroll, v.alerts)}>
                {d.alerts.map((a) => (
                  <article key={a.id} className={cx(v.alert, a.severity === 'high' && v.alertHigh)}>
                    <div className={v.alertText}>{t(`ui_alert_${a.kind}`, { actor: shortId(a.actor), ...(a.vars ?? {}) })}</div>
                    <div className={v.alertFoot}>
                      <span>
                        <Badge tone={severityTone[a.severity]}>{t(`ui_sev_${a.severity}`)}</Badge>
                        {' '}{formatRelative(a.ts, loc)}
                      </span>
                      <Button size="small" onClick={() => dispatch({ type: 'view', view: 'audit', auditActor: a.actor })}>
                        {t('ui_alert_view')}
                      </Button>
                    </div>
                  </article>
                ))}
              </div>
            ) : (
              <Empty icon={<ShieldAlert size={22} />}>{t('ui_alerts_empty')}</Empty>
            )}
          </section>
        </div>
      </div>
    </main>
  );
}
