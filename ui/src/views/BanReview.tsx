import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { Badge, Button, cx, Dialog, ui } from '../components/ui';
import { formatDateTime, shortId } from '../format';
import { useApp } from '../store';
import type { BanRow, TicketCreateResult } from '../types';
import { LimitHint, overLimit } from './TicketChat';
import v from './views.module.css';

type Page = { rows: BanRow[]; hasMore: boolean };
type PageResult = TicketCreateResult & { data?: Page };

export function BanReview({ onClose }: { onClose: () => void }) {
  const { state, t, send } = useApp();
  const [page, setPage] = useState(1);
  const [result, setResult] = useState<Page>();
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<string>();
  const [revoke, setRevoke] = useState<number>();
  const [reason, setReason] = useState('');
  const max = state.config.limits?.reason ?? 300;
  const canRevoke = state.player?.capabilities?.includes('ban.revoke');

  const load = useCallback(async (next: number) => {
    setBusy(true);
    setError(undefined);
    const response = await send('ban_list', { page: next }) as PageResult | null;
    setBusy(false);
    if (!response?.ok || !response.data) {
      setError(response?.error ?? '');
      return;
    }
    setPage(next);
    setResult({ ...response.data, rows: Array.isArray(response.data.rows) ? response.data.rows : [] });
  }, [send]);

  useEffect(() => {
    const timer = window.setTimeout(() => void load(1), 0);
    return () => window.clearTimeout(timer);
  }, [load]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!revoke || !canRevoke || busy || !reason.trim() || overLimit(reason, max)) return;
    setBusy(true);
    setError(undefined);
    const response = await send('ban_revoke', { id: revoke, reason: reason.trim() }) as TicketCreateResult | null;
    if (!response?.ok) {
      setError(response?.error ?? t('ban_review_failed'));
      setBusy(false);
      return;
    }
    setRevoke(undefined);
    setReason('');
    await load(page);
  }

  return (
    <Dialog title={t('ban_review_title')} onClose={onClose} footer={<>
      <Button size="small" disabled={busy} onClick={() => void load(1)}>{t('ban_review_refresh')}</Button>
      <Button size="small" onClick={onClose}>{t('close')}</Button>
    </>}>
      {busy && !result && <p className={v.setHint} role="status">{t('ui_loading')}</p>}
      {error !== undefined && <p className={v.setHint} role="alert">{error || t('ban_review_failed')}</p>}
      {result && (
        <>
          {!result.rows.length && <p className={v.setHint}>{t('ban_review_empty')}</p>}
          <ul className={cx(v.banList, ui.scroll)} aria-busy={busy}>
            {result.rows.map((ban) => (
              <li className={v.banItem} key={ban.id ?? ban.identifier}>
                <div className={v.banLine}>
                  <strong title={ban.identifier}>{shortId(ban.identifier)}</strong>
                  <Badge tone={ban.status === 'active' ? 'red' : 'gray'}>{t(`ban_review_${ban.status}`)}</Badge>
                </div>
                <p>{ban.reason}</p>
                <p className={v.setHint}>{t('ban_review_actor', { actor: shortId(ban.actor) })}
                  {' · '}{ban.expires_at ? t('ban_review_until', { date: formatDateTime(ban.expires_at, state.locale) }) : t('ban_review_permanent')}
                  {' · '}{t('ban_review_aliases', { n: ban.aliases })}
                </p>
                {ban.status === 'active' && !ban.id && <p className={v.setHint}>{t('ban_review_legacy')}</p>}
                {canRevoke && ban.status === 'active' && ban.id && (
                  revoke === ban.id ? (
                    <form className={v.actionForm} onSubmit={submit}>
                      <input className={ui.input} aria-label={t('ban_review_reason')} value={reason} disabled={busy}
                        onChange={(event) => setReason(event.target.value)} />
                      <LimitHint text={reason} max={max} />
                      <div className={v.banLine}>
                        <Button size="small" disabled={busy} onClick={() => setRevoke(undefined)}>{t('ui_cancel')}</Button>
                        <Button variant="danger" size="small" type="submit" disabled={busy || !reason.trim() || overLimit(reason, max)}>
                          {t('ban_review_revoke')}
                        </Button>
                      </div>
                    </form>
                  ) : <Button size="small" disabled={busy} onClick={() => { setRevoke(ban.id); setReason(''); }}>
                    {t('ban_review_revoke')}
                  </Button>
                )}
              </li>
            ))}
          </ul>
          {(page > 1 || result.hasMore) && <div className={v.banLine}>
            <Button size="small" disabled={busy || page === 1} onClick={() => void load(page - 1)}>{t('ban_review_previous')}</Button>
            <Button size="small" disabled={busy || !result.hasMore} onClick={() => void load(page + 1)}>{t('ban_review_next')}</Button>
          </div>}
        </>
      )}
    </Dialog>
  );
}
