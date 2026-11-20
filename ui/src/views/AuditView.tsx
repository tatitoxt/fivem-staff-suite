import { ChevronDown, SearchX, Shield, ShieldAlert, ShieldCheck } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { Badge, Button, Empty, ViewHeader, cx, ui } from '../components/ui';
import lay from '../components/layout.module.css';
import { formatDateTime, formatRelative, shortHash, shortId, toDayStart } from '../format';
import { actionLabel } from '../labels';
import { useApp } from '../store';
import type { AuditEntry } from '../types';
import v from './views.module.css';

function EntryRow({ e, brokenAt }: { e: AuditEntry; brokenAt: number | null }) {
  const { t, state } = useApp();
  const [open, setOpen] = useState(false);
  const broken = brokenAt != null && e.seq === brokenAt;
  const after = brokenAt != null && e.seq > brokenAt;
  return (
    <li className={cx(v.entry, broken && v.entryBroken, after && v.entryAfter)} data-testid={`entry-${e.seq}`}>
      <button type="button" className={v.entryRow} aria-expanded={open} onClick={() => setOpen((o) => !o)}>
        <span className={v.seq}>#{e.seq}</span>
        <span className={v.entryMain}>
          <span className={v.entryTop}>
            <span className={v.entryAction}>{actionLabel(t, e.action)}</span>
            {broken && <Badge tone="red" dot>{t('ui_entry_broken')}</Badge>}
            {after && <Badge tone="orange">{t('ui_entry_unverified')}</Badge>}
            <span className={v.entryWho}>
              {shortId(e.actor)}
              {e.target && <> → {shortId(e.target)}</>}
              {e.reason && <em> · {e.reason}</em>}
            </span>
          </span>
          <span className={v.entryHash}>{shortHash(e.hash, 16, 8)}</span>
        </span>
        <span className={v.entryTime} title={formatDateTime(e.ts, state.locale)}>
          {formatRelative(e.ts, state.locale)}
        </span>
        <ChevronDown size={16} className={cx(v.chev, open && v.chevOpen)} />
      </button>
      {open && (
        <dl className={v.entryDetail}>
          <dt>{t('ui_audit_time')}</dt>
          <dd>{formatDateTime(e.ts, state.locale)}</dd>
          <dt>{t('ui_audit_actor')}</dt>
          <dd>{e.actor}</dd>
          {e.target && (<><dt>{t('ui_audit_target')}</dt><dd>{e.target}</dd></>)}
          <dt>{t('ui_hash')}</dt>
          <dd>{e.hash}</dd>
          <dt>{t('ui_prev_hash')}</dt>
          <dd>{e.prev_hash}</dd>
          {e.payload && (<><dt>{t('ui_payload')}</dt><dd>{e.payload}</dd></>)}
        </dl>
      )}
    </li>
  );
}

export function AuditView() {
  const { state, dispatch, t, can, send } = useApp();
  const { entries, verify, checking, checkedAt, head } = state.audit;
  const [action, setAction] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const actor = state.auditActor;

  const actors = useMemo(() => [...new Set(entries.map((e) => e.actor))].sort(), [entries]);
  const actions = useMemo(() => [...new Set(entries.map((e) => e.action))].sort(), [entries]);

  const fromTs = toDayStart(from);
  const toTs = toDayStart(to);
  const rows = useMemo(
    () =>
      entries
        .filter((e) => (!actor || e.actor === actor || e.target === actor)
          && (!action || e.action === action)
          && (fromTs == null || e.ts >= fromTs)
          && (toTs == null || e.ts < toTs + 86400))
        .slice()
        .reverse(),
    [entries, actor, action, fromTs, toTs],
  );

  useEffect(() => {
    if (!actor && !action && fromTs == null && toTs == null) return;
    void send('audit_filter', { actor, action, from: fromTs, to: toTs });
  }, [actor, action, fromTs, toTs, send]);

  const status = verify == null ? 'unknown' : verify.ok ? 'ok' : 'bad';
  const brokenAt = verify && !verify.ok ? verify.broken_at : null;
  const hasFilters = !!(actor || action || from || to);

  const runVerify = () => {
    dispatch({ type: 'checking' });
    void send('audit_verify');
  };

  return (
    <main className={lay.main}>
      <ViewHeader title={t('tab_audit')} subtitle={t('ui_audit_sub')} />
      <div className={lay.viewBody}>
        <section
          className={cx(ui.card, v.chainCard, status === 'ok' && v.chainOk, status === 'bad' && v.chainBad)}
          aria-live="polite"
          data-testid="chain-status"
        >
          <div className={v.chainIcon}>
            {status === 'ok' ? <ShieldCheck size={16} /> : status === 'bad' ? <ShieldAlert size={18} /> : <Shield size={18} />}
          </div>
          <div className={v.chainText}>
            <div className={v.chainTitle}>
              {status === 'ok' ? t('ui_chain_ok') : status === 'bad' ? t('ui_chain_broken', { seq: brokenAt ?? '?' }) : t('ui_chain_unknown')}
            </div>
            <div className={v.chainSub}>
              {status === 'ok'
                ? t('audit_ok', { n: entries.length })
                : status === 'bad'
                  ? t('audit_broken', { seq: brokenAt ?? '?' })
                  : t('ui_chain_unknown_sub')}
            </div>
          </div>
          <div className={v.chainMeta}>
            <span>{t('ui_chain_head')}</span>
            <span className={ui.mono} title={head}>{shortHash(head, 12, 6) || '—'}</span>
            <span>{checkedAt ? t('ui_last_check', { when: formatRelative(checkedAt, state.locale) }) : '\u00a0'}</span>
          </div>
          <Button
            variant="primary"
            className={v.verifyBtn}
            disabled={checking || !can('audit.verify')}
            onClick={runVerify}
          >
            <ShieldCheck size={16} />
            {checking ? t('ui_verifying') : t('audit_verify')}
          </Button>
        </section>

        <div className={v.filters}>
          <label className={ui.field}>
            <span className={ui.label}>{t('ui_filter_actor')}</span>
            <select className={ui.input} value={actor} onChange={(e) => dispatch({ type: 'setAuditActor', actor: e.target.value })}>
              <option value="">{t('ui_filter_all')}</option>
              {actors.map((a) => <option key={a} value={a}>{shortId(a)}</option>)}
            </select>
          </label>
          <label className={ui.field}>
            <span className={ui.label}>{t('ui_filter_action')}</span>
            <select className={ui.input} value={action} onChange={(e) => setAction(e.target.value)}>
              <option value="">{t('ui_filter_all_f')}</option>
              {actions.map((a) => <option key={a} value={a}>{actionLabel(t, a)}</option>)}
            </select>
          </label>
          <label className={ui.field}>
            <span className={ui.label}>{t('ui_filter_from')}</span>
            <input type="date" className={ui.input} value={from} onChange={(e) => setFrom(e.target.value)} />
          </label>
          <label className={ui.field}>
            <span className={ui.label}>{t('ui_filter_to')}</span>
            <input type="date" className={ui.input} value={to} onChange={(e) => setTo(e.target.value)} />
          </label>
          <div className={v.filterEnd}>
            <span>{t('ui_audit_count', { n: rows.length, total: entries.length })}</span>
            <Button
              size="small"
              variant="ghost"
              disabled={!hasFilters}
              onClick={() => { dispatch({ type: 'setAuditActor', actor: '' }); setAction(''); setFrom(''); setTo(''); }}
            >
              {t('ui_filter_clear')}
            </Button>
          </div>
        </div>

        <section className={cx(ui.card, v.listCard)}>
          {rows.length ? (
            <ul className={cx(ui.scroll, v.list)} style={{ listStyle: 'none', margin: 0 }} aria-label={t('audit_title')}>
              {rows.map((e) => <EntryRow key={e.seq} e={e} brokenAt={brokenAt} />)}
            </ul>
          ) : (
            <Empty icon={<SearchX size={18} />}>{entries.length ? t('ui_audit_no_match') : t('audit_empty')}</Empty>
          )}
        </section>
      </div>
    </main>
  );
}
