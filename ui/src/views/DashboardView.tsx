import { Activity, ShieldAlert, Star } from 'lucide-react';
import { useMemo } from 'react';
import { Badge, Button, Empty, ViewHeader, cx, ui } from '../components/ui';
import lay from '../components/layout.module.css';
import { Sparkline, dailySeries } from '../components/Sparkline';
import { formatDuration, formatNumber, formatRelative, intlLocale, shortId } from '../format';
import { severityTone } from '../labels';
import { useApp } from '../store';
import v from './views.module.css';

function Kpi({ label, value, series, hint }: { label: string; value: string; series?: number[]; hint?: string }) {
  return (
    <div className={v.kpi}>
      <div className={v.kpiLabel}>{label}</div>
      <div className={v.kpiRow}>
        <div className={v.kpiValue} title={value}>{value}</div>
        {series && <Sparkline values={series} label={hint ? `${label}, ${hint}` : label} />}
      </div>
      {hint && <div className={v.kpiHint}>{hint}</div>}
    </div>
  );
}

export function DashboardView() {
  const { state, dispatch, t } = useApp();
  const d = state.dashboard;
  const loc = state.locale;
  const week = t('ui_kpi_7d');
  const created = useMemo(() => dailySeries(state.tickets.map((x) => x.created_ts)), [state.tickets]);
  const resolved = useMemo(
    () => dailySeries(state.tickets.filter((x) => x.state === 'resolved' || x.state === 'closed').map((x) => x.updated_ts)),
    [state.tickets],
  );
  const days = useMemo(() => {
    const f = new Intl.DateTimeFormat(intlLocale(loc), { weekday: 'short' });
    const today = Math.floor(Date.now() / 86400000);
    return created.map((_, i) => f.format(new Date((today - (created.length - 1 - i)) * 86400000 + 43200000)));
  }, [created, loc]);
  const peak = Math.max(1, ...created, ...resolved);

  return (
    <main className={lay.main}>
      <ViewHeader title={t('ui_nav_dashboard')} subtitle={t('ui_dashboard_sub')} />
      <div className={lay.viewBody}>
        <div className={cx(ui.card, v.kpis)}>
          <Kpi label={t('ui_kpi_open')} value={d ? String(d.kpis.open) : '—'} series={created} hint={week} />
          <Kpi label={t('ui_kpi_resolved')} value={d ? String(d.kpis.resolved) : '—'} series={resolved} hint={week} />
          <Kpi label={t('ui_kpi_response')} value={formatDuration(d?.kpis.avg_response)} />
          <Kpi label={t('ui_kpi_rating')} value={formatNumber(d?.kpis.avg_rating, loc)} />
          <Kpi label={t('ui_kpi_on_duty')} value={d ? String(d.kpis.on_duty) : '—'} />
        </div>
        <div className={v.dashGrid}>
          <section className={cx(ui.card, v.section)}>
            <div className={v.sectionHead}><h2>{t('ui_leaderboard')}</h2></div>
            {d?.leaderboard.length ? (
              <div className={cx(ui.scroll, v.tableWrap)} tabIndex={0} role="region" aria-label={t('ui_leaderboard')}>
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
                          <span className={v.ratingCell}><Star size={13} fill="currentColor" />{formatNumber(s.avg_rating, loc)}</span>
                        </td>
                        <td className={v.num}>{formatNumber(s.duty_hours, loc)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <Empty icon={<Activity size={18} />}>{t('ui_leaderboard_empty')}</Empty>
            )}
          </section>
          <div className={v.dashSide}>
            <section className={cx(ui.card, v.section, v.activity)}>
              <div className={v.sectionHead}>
                <h2>{t('ui_activity')}</h2>
                <span className={v.legend}>
                  <span><i className={v.legendCreated} />{t('ui_activity_created')}</span>
                  <span><i className={v.legendResolved} />{t('ui_activity_resolved')}</span>
                </span>
              </div>
              <div className={v.bars} role="list" aria-label={t('ui_activity')}>
                {created.map((c, i) => (
                  <div key={i} className={v.barCol} role="listitem" aria-label={t('ui_activity_label', { day: days[i], created: c, resolved: resolved[i] })}>
                    <div className={v.barPair} aria-hidden>
                      <span className={v.barCreated} style={{ height: `${(c / peak) * 100}%` }} />
                      <span className={v.barResolved} style={{ height: `${(resolved[i] / peak) * 100}%` }} />
                    </div>
                    <span className={v.barDay} aria-hidden>{days[i]}</span>
                  </div>
                ))}
              </div>
            </section>
            <section className={cx(ui.card, v.section, v.alertsCard)}>
              <div className={v.sectionHead}>
                <h2>{t('ui_alerts')}</h2>
                {!!d?.alerts.length && <Badge tone="red">{d.alerts.length}</Badge>}
              </div>
              {d?.alerts.length ? (
                <ul className={cx(ui.scroll, v.alerts)}>
                  {d.alerts.map((a) => (
                    <li key={a.id} className={v.alert}>
                      <span className={cx(v.alertDot, a.severity === 'high' && v.alertHigh)} aria-hidden />
                      <div className={v.alertMain}>
                        <div className={v.alertText}>{t(`ui_alert_${a.kind}`, { actor: shortId(a.actor), ...(a.vars ?? {}) })}</div>
                        <div className={v.alertFoot}>
                          <Badge tone={severityTone[a.severity]}>{t(`ui_sev_${a.severity}`)}</Badge>
                          <span>{formatRelative(a.ts, loc)}</span>
                        </div>
                      </div>
                      <Button size="small" variant="ghost" onClick={() => dispatch({ type: 'view', view: 'audit', auditActor: a.actor === 'system' ? '' : a.actor })}>
                        {t('ui_alert_view')}
                      </Button>
                    </li>
                  ))}
                </ul>
              ) : (
                <Empty icon={<ShieldAlert size={18} />}>{t('ui_alerts_empty')}</Empty>
              )}
            </section>
          </div>
        </div>
      </div>
    </main>
  );
}
