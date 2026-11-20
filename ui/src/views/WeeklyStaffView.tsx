import { Download } from 'lucide-react';
import { useEffect, useState } from 'react';
import lay from '../components/layout.module.css';
import { Button, Empty, ViewHeader, cx, ui } from '../components/ui';
import { formatDuration, formatNumber } from '../format';
import { useApp } from '../store';
import type { WeeklyStaffReport } from '../types';
import v from './views.module.css';

function toCsv({ from, to, staff }: WeeklyStaffReport) {
  const date = (ts: number) => new Date(ts * 1000).toISOString();
  const quote = (value: string) => {
    const safe = /^[\s]*[=+@-]|^[\t\r\n]/.test(value) ? `'${value}` : value;
    return `"${safe.replaceAll('"', '""')}"`;
  };
  return [
    'from_utc,to_utc,staff,duty_seconds,sessions,resolved,ratings,average_rating',
    ...staff.map((row) => [
      date(from), date(to), quote(row.actor), row.duty_seconds, row.sessions, row.resolved, row.ratings, row.avg_rating ?? '',
    ].join(',')),
  ].join('\r\n');
}

export function WeeklyStaffView() {
  const { can, send, state, t } = useApp();
  const [report, setReport] = useState<WeeklyStaffReport>();
  const [csv, setCsv] = useState('');
  const [error, setError] = useState('');
  const [exporting, setExporting] = useState(false);
  const locale = state.locale;
  const canExport = can('staff.analytics.export');
  const request = async (exportFile: boolean) => {
    return await send('staff_weekly', { export: exportFile }) as
      { ok?: boolean; data?: WeeklyStaffReport; error?: string } | null;
  };

  useEffect(() => {
    let active = true;
    void request(false).then((result) => {
      if (!active) return;
      if (result?.ok && result.data) setReport({ ...result.data, staff: Array.isArray(result.data.staff) ? result.data.staff : [] });
      else setError(result?.error ?? t('staff_weekly_failed'));
    });
    return () => { active = false; };
  }, [send, t]);

  const exportCsv = async () => {
    setError('');
    setExporting(true);
    const result = await request(true);
    if (result?.ok && result.data) {
      setCsv(toCsv({ ...result.data, staff: Array.isArray(result.data.staff) ? result.data.staff : [] }));
    } else setError(result?.error ?? t('staff_weekly_failed'));
    setExporting(false);
  };
  const dates = new Intl.DateTimeFormat(locale, { dateStyle: 'medium', timeStyle: 'short', timeZone: 'UTC' });
  const title = t('ui_nav_weekly');
  return (
    <main className={lay.main}>
      <ViewHeader title={title} subtitle={report && `${dates.format(report.from * 1000)} – ${dates.format(report.to * 1000)} UTC`}>
        {canExport && report && <Button onClick={() => void exportCsv()} disabled={exporting}>
          <Download size={16} aria-hidden />{t('ui_weekly_export')}
        </Button>}
      </ViewHeader>
      <div className={lay.viewBody}>
        {error && <p role="alert">{error}</p>}
        {!error && !report && <p role="status">{t('ui_loading')}</p>}
        {report && !report.staff.length && <Empty>{t('ui_weekly_empty')}</Empty>}
        {report && report.staff.length > 0 && (
          <div className={cx(ui.scroll, v.tableWrap)} role="region" aria-label={title} tabIndex={0}>
            <table className={v.table}>
              <thead><tr>
                <th scope="col">{t('ui_col_staff')}</th><th scope="col">{t('ui_col_hours')}</th>
                <th scope="col">{t('ui_col_sessions')}</th><th scope="col">{t('ui_col_resolved')}</th>
                <th scope="col">{t('ui_col_rating')}</th>
              </tr></thead>
              <tbody>{report.staff.map((row) => (
                <tr key={row.actor}>
                  <td>{row.actor}</td><td>{formatDuration(row.duty_seconds)}</td>
                  <td>{row.sessions}</td><td>{row.resolved}</td>
                  <td>{row.avg_rating === undefined ? '—' : `${formatNumber(row.avg_rating, locale)} (${row.ratings})`}</td>
                </tr>
              ))}</tbody>
            </table>
          </div>
        )}
        {canExport && csv && <textarea className={ui.input} aria-label={t('ui_weekly_csv')} readOnly
          value={csv} rows={5} onFocus={(event) => event.target.select()} />}
      </div>
    </main>
  );
}
