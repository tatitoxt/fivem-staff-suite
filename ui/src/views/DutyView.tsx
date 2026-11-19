import { Clock3, Star, Users } from 'lucide-react';
import { useMemo } from 'react';
import { Badge, Button, Empty, ViewHeader, cx, ui } from '../components/ui';
import lay from '../components/layout.module.css';
import { formatDuration, formatNumber, shortId } from '../format';
import { useApp } from '../store';
import v from './views.module.css';

export function DutyView() {
  const { state, t, send } = useApp();
  const loc = state.locale;
  const onDuty = !!state.duty?.self.on_duty;
  const staff = useMemo(
    () => [...(state.duty?.staff ?? [])].sort((a, b) => Number(b.on_duty) - Number(a.on_duty) || b.duty_hours - a.duty_hours),
    [state.duty],
  );
  const me = staff.find((s) => s.actor === state.player?.name);
  const onCount = staff.filter((s) => s.on_duty).length;

  return (
    <main className={lay.main}>
      <ViewHeader title={t('ui_nav_duty')} subtitle={t('ui_duty_sub')} />
      <div className={lay.viewBody}>
        <section className={cx(ui.card, v.dutyHero, onDuty && v.dutyHeroOn)} aria-live="polite">
          <div className={v.dutyIcon}><Clock3 size={30} /></div>
          <div className={v.dutyText}>
            <h2>{onDuty ? t('ui_duty_on') : t('ui_duty_off')}</h2>
            <p>{t('ui_duty_hint')}</p>
          </div>
          {me && (
            <div className={v.dutyStats}>
              <div className={v.dutyStat}><b>{formatNumber(me.duty_hours, loc)}</b><span>{t('ui_col_hours')}</span></div>
              <div className={v.dutyStat}><b>{me.sessions}</b><span>{t('ui_col_sessions')}</span></div>
              <div className={v.dutyStat}><b>{me.resolved}</b><span>{t('ui_col_resolved')}</span></div>
            </div>
          )}
          <Button variant={onDuty ? 'secondary' : 'primary'} className={v.dutyBtn} onClick={() => void send('duty_toggle')}>
            {onDuty ? t('ui_duty_stop') : t('ui_duty_start')}
          </Button>
        </section>

        <section className={cx(ui.card, v.section)} style={{ flex: 1 }}>
          <div className={v.sectionHead}>
            <h2>{t('ui_duty_team')}</h2>
            <Badge tone="green" dot>{t('ui_duty_count', { n: onCount, total: staff.length })}</Badge>
          </div>
          {staff.length ? (
            <div className={cx(ui.scroll, v.tableWrap)}>
              <table className={v.table}>
                <thead>
                  <tr>
                    <th>{t('ui_col_staff')}</th>
                    <th>{t('ui_col_status')}</th>
                    <th className={v.num}>{t('ui_col_hours')}</th>
                    <th className={v.num}>{t('ui_col_sessions')}</th>
                    <th className={v.num}>{t('ui_col_resolved')}</th>
                    <th className={v.num}>{t('ui_col_response')}</th>
                    <th className={v.num}>{t('ui_col_rating')}</th>
                  </tr>
                </thead>
                <tbody>
                  {staff.map((s) => (
                    <tr key={s.actor}>
                      <td><span className={v.staffCell}><span className={cx(v.statusDot, s.on_duty && v.statusOn)} />{shortId(s.actor)}</span></td>
                      <td>
                        <Badge tone={s.on_duty ? 'green' : 'gray'}>{s.on_duty ? t('ui_status_on') : t('ui_status_off')}</Badge>
                      </td>
                      <td className={v.num}>{formatNumber(s.duty_hours, loc)}</td>
                      <td className={v.num}>{s.sessions}</td>
                      <td className={v.num}>{s.resolved}</td>
                      <td className={v.num}>{formatDuration(s.avg_response)}</td>
                      <td className={v.num}><span className={v.ratingCell}><Star size={14} fill="currentColor" />{formatNumber(s.avg_rating, loc)}</span></td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <Empty icon={<Users size={22} />}>{t('ui_duty_empty')}</Empty>
          )}
        </section>
      </div>
    </main>
  );
}
