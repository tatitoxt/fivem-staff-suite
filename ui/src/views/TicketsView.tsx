import { Camera, Inbox, Plus, Star } from 'lucide-react';
import { useEffect, useMemo, useState } from 'react';
import { Badge, Button, Dialog, Empty, Segmented, ViewHeader, cx, ui } from '../components/ui';
import lay from '../components/layout.module.css';
import { formatDateTime, formatRelative, shortId } from '../format';
import { isLite } from '../edition';
import { PRIORITY_WEIGHT, categoryLabel, priorityLabel, priorityTone, stateLabel, stateTone } from '../labels';
import { useApp } from '../store';
import type { ModAction, Priority, Ticket, TicketCreateResult, TicketState } from '../types';
import { LimitHint, TicketChat, overLimit } from './TicketChat';
import { PlayerProfileButton } from './PlayerProfileDialog';
import v from './views.module.css';

type Group = 'all' | 'open' | 'active' | 'done';
const GROUPS: Record<Group, TicketState[] | null> = {
  all: null,
  open: ['open', 'reopened'],
  active: ['claimed', 'in_progress'],
  done: ['resolved', 'closed'],
};
const DONE = new Set<TicketState>(['resolved', 'closed']);
const MODS: ModAction[] = ['goto', 'bring', 'spectate', 'freeze', 'heal', 'revive', 'warn', 'kick', 'ban'];
const NEEDS_REASON = new Set<ModAction>(['warn', 'ban']);

type DialogState = null | { kind: 'transfer' | 'resolve' | 'ban' | 'create' };

function TicketCard({ tk, selected, onSelect }: { tk: Ticket; selected: boolean; onSelect: () => void }) {
  const { t, state } = useApp();
  return (
    <button type="button" className={cx(v.tcard, selected && v.tcardOn)} onClick={onSelect} aria-pressed={selected}>
      <div className={v.tcardTop}>
        <span className={v.tcardTitle}>#{tk.id} · {categoryLabel(t, tk.category)}</span>
        <Badge tone={stateTone[tk.state]}>{stateLabel(t, tk.state)}</Badge>
      </div>
      <div className={v.tcardDesc}>{tk.description}</div>
      <div className={v.tcardMeta}>
        {!isLite && <Badge tone={priorityTone[tk.priority]} dot>{priorityLabel(t, tk.priority)}</Badge>}
        <span>{formatRelative(tk.created_ts, state.locale)}</span>
        <span>{tk.claimer ? shortId(tk.claimer) : t('ui_unassigned')}</span>
      </div>
    </button>
  );
}

interface DetailProps {
  tk: Ticket;
  openDialog: (d: DialogState) => void;
  reason: string;
  setReason: (r: string) => void;
}

function Detail({ tk, openDialog, reason, setReason }: DetailProps) {
  const { state, dispatch, t, can, send } = useApp();
  const [viewing, setViewing] = useState<number | null>(null);
  const shot = state.evidence;
  const closeViewer = () => { setViewing(null); dispatch({ type: 'evidenceClose' }); };
  const me = state.player?.identifier || state.player?.name;
  const requireReason = state.config.require_reason !== false;

  const st = tk.state;
  const canClaim = (st === 'open' || st === 'reopened') && can('report.claim');
  const canTransfer = !isLite && st === 'claimed' && can('report.resolve');
  const canResolve = (st === 'claimed' || st === 'in_progress') && can('report.resolve');
  const canClose = st !== 'closed' && can('report.resolve');
  const canReopen = DONE.has(st) && can('report.resolve');
  const canMessage = can('report.message');
  const frozen = state.frozenPlayers[tk.reporter] === true;

  const mod = (action: ModAction) => {
    if (action === 'ban') return openDialog({ kind: 'ban' });
    void send('mod_action', { action, target: tk.reporter, reason: reason.trim(), ticket: tk.id });
    if (NEEDS_REASON.has(action) || action === 'kick') setReason('');
  };

  return (
    <div className={v.detail}>
      <section className={cx(ui.card, v.detailHead)}>
        <div className={v.detailTitle}>
          <h2>#{tk.id} · {categoryLabel(t, tk.category)}</h2>
          <Badge tone={stateTone[st]}>{stateLabel(t, st)}</Badge>
          {!isLite && <Badge tone={priorityTone[tk.priority]} dot>{priorityLabel(t, tk.priority)}</Badge>}
        </div>
        <dl className={v.detailMeta}>
          <div><dt>{t('ui_ticket_reporter')}</dt><dd title={tk.reporter}>{shortId(tk.reporter)}</dd></div>
          <div><dt>{t('ui_ticket_claimer')}</dt><dd>{tk.claimer ? shortId(tk.claimer) : t('ui_unassigned')}</dd></div>
          <div><dt>{t('ui_ticket_created')}</dt><dd title={formatDateTime(tk.created_ts, state.locale)}>{formatRelative(tk.created_ts, state.locale)}</dd></div>
        </dl>
        <div className={v.desc}>{tk.description}</div>
        {tk.resolution != null && DONE.has(st) && (
          <div className={v.resolution}>
            <span><strong>{t('ui_ticket_resolution')}:</strong> {tk.resolution || '—'}</span>
            {!isLite && tk.rating != null && (
              <span className={v.stars} aria-label={`${tk.rating}/5`}>
                {[1, 2, 3, 4, 5].map((n) => (
                  <Star key={n} size={16} fill="currentColor" className={n > tk.rating! ? v.starOff : undefined} />
                ))}
              </span>
            )}
          </div>
        )}
      </section>

      <div className={v.detailBody}>
        <TicketChat
          key={tk.id}
          id={tk.id}
          messages={tk.messages.filter((m) => !isLite || !m.internal).map((m) => ({
            ...m, label: shortId(m.author), mine: m.author === me,
          }))}
          allowPublic={canMessage && !DONE.has(st)}
          allowInternal={!isLite && canMessage && st !== 'closed'}
        />

        <div className={cx(v.rail, ui.scroll)}>
          <section className={cx(ui.card, v.railCard)}>
            <h3>{t('ui_ticket_actions')}</h3>
            <div className={v.railGrid}>
              <Button variant="primary" className={v.railWide} disabled={!canClaim} onClick={() => void send('ticket_claim', { id: tk.id })}>{t('claim')}</Button>
              {!isLite && <Button disabled={!canTransfer} onClick={() => openDialog({ kind: 'transfer' })}>{t('transfer')}</Button>}
              <Button disabled={!canResolve} onClick={() => openDialog({ kind: 'resolve' })}>{t('resolve')}</Button>
              <Button disabled={!canClose} onClick={() => void send('ticket_close', { id: tk.id })}>{t('close')}</Button>
              <Button disabled={!canReopen} onClick={() => void send('ticket_reopen', { id: tk.id })}>{t('reopen')}</Button>
              {!isLite && can('player.profile.view') && <PlayerProfileButton key={tk.id} id={tk.id} />}
            </div>
          </section>
          {!isLite && (state.config.evidence || (tk.evidence?.length ?? 0) > 0) && (
            <section className={cx(ui.card, v.railCard)}>
              <h3>{t('ui_evidence')}</h3>
              {tk.evidence?.length ? (
                <ul className={v.evidenceList}>
                  {tk.evidence.map((e) => (
                    <li key={e.n}>
                      <span><strong>{t('ui_evidence_item', { n: e.n })}</strong> · {shortId(e.by)} · {formatRelative(e.ts, state.locale)}</span>
                      <Button size="small" onClick={() => { setViewing(e.n); void send('evidence_get', { id: tk.id, n: e.n }); }}>{t('ui_evidence_view')}</Button>
                    </li>
                  ))}
                </ul>
              ) : <p className={v.setHint}>{t('ui_evidence_empty')}</p>}
              {state.config.evidence && (
                <Button disabled={!can('report.claim') || st === 'closed'} onClick={() => void send('ticket_evidence', { id: tk.id })}>
                  <Camera size={16} />{t('ui_evidence_request')}
                </Button>
              )}
            </section>
          )}
          {!isLite && viewing != null && (
            <Dialog
              title={t('ui_evidence_item', { n: viewing })}
              onClose={closeViewer}
              footer={<Button onClick={closeViewer}>{t('ui_evidence_close')}</Button>}
            >
              {shot && shot.id === tk.id && shot.n === viewing ? (
                <figure className={v.evidenceFig}>
                  <img src={shot.data} alt={t('ui_evidence_item', { n: viewing })} />
                  <figcaption>
                    <Badge tone={shot.ok ? 'green' : 'red'} dot>{shot.ok ? t('ui_evidence_ok') : t('ui_evidence_bad')}</Badge>
                  </figcaption>
                </figure>
              ) : <p className={v.setHint}>{t('ui_evidence_loading')}</p>}
            </Dialog>
          )}
          {!isLite && <section className={cx(ui.card, v.railCard)}>
            <h3>{t('ui_mod_title')}</h3>
            <div className={v.target}>{t('ui_mod_target')}: <strong>{shortId(tk.reporter)}</strong></div>
            <label className={ui.field}>
              <span className={ui.label}>{t('ui_mod_reason')}</span>
              <input
                className={ui.input}
                value={reason}
                placeholder={t('ui_mod_reason_ph')}
                onChange={(e) => setReason(e.target.value)}
              />
            </label>
            <div className={v.railGrid}>
              {MODS.map((m) => (
                <Button
                  key={m}
                  size="small"
                  variant={m === 'ban' ? 'danger' : 'secondary'}
                  className={m === 'ban' ? v.railWide : undefined}
                  disabled={!can(`mod.${m}`) || ((NEEDS_REASON.has(m) || (m === 'kick' && requireReason)) && !reason.trim())}
                  aria-pressed={m === 'freeze' ? frozen : undefined}
                  onClick={() => mod(m === 'freeze' && frozen ? 'unfreeze' : m)}
                >
                  {t(m === 'freeze' && frozen ? 'mod_unfreeze' : `mod_${m}`)}
                </Button>
              ))}
            </div>
          </section>}
        </div>
      </div>
    </div>
  );
}

export function TicketsView() {
  const { state, t, can, send } = useApp();
  const resolutionMax = state.config.limits?.resolution ?? state.config.limits?.message_body;
  const reportMax = state.config.limits?.ticket_body;
  const [group, setGroup] = useState<Group>('all');
  const [priority, setPriority] = useState<'' | Priority>('');
  const [selected, setSelected] = useState<number | null>(null);
  const [dialog, setDialog] = useState<DialogState>(null);
  const [text, setText] = useState('');
  const [createError, setCreateError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [target, setTarget] = useState('');
  const [category, setCategory] = useState('player');
  const [newPriority, setNewPriority] = useState<Priority>('normal');
  const [reason, setReason] = useState('');
  const [banDuration, setBanDuration] = useState('');
  useEffect(() => setReason(''), [selected]);

  const list = useMemo(() => {
    const states = GROUPS[group];
    return state.tickets
      .filter((x) => (!states || states.includes(x.state)) && (isLite || !priority || x.priority === priority))
      .sort((a, b) =>
        Number(DONE.has(a.state)) - Number(DONE.has(b.state))
        || (isLite ? 0 : PRIORITY_WEIGHT[b.priority] - PRIORITY_WEIGHT[a.priority])
        || b.created_ts - a.created_ts);
  }, [state.tickets, group, priority]);

  const tk = state.tickets.find((x) => x.id === selected) ?? null;
  useEffect(() => {
    if (selected == null && list.length) setSelected(list[0].id);
  }, [list, selected]);

  const close = () => { setDialog(null); setText(''); setTarget(''); setBanDuration(''); setCreateError(null); };
  const submitReport = async () => {
    setCreating(true);
    setCreateError(null);
    const res = (await send('ticket_create', { category, priority: isLite ? 'normal' : newPriority, body: text.trim() })) as TicketCreateResult | null;
    setCreating(false);
    if (res?.ok) close();
    else setCreateError(res?.error || t('report_failed'));
  };
  const targets = Array.isArray(state.config.transfer_targets)
    ? state.config.transfer_targets.map((x) => ({ value: x.identifier, label: x.name || shortId(x.identifier) }))
    : (state.duty?.staff ?? []).map((s) => ({ value: s.actor, label: shortId(s.actor) }));
  const staff = targets.filter((x) => x.value !== tk?.claimer);
  const categories = state.config.categories ?? ['bug', 'player', 'staff', 'question', 'other'];
  const priorities = state.config.priorities ?? ['low', 'normal', 'high', 'urgent'];

  return (
    <main className={lay.main}>
      <ViewHeader title={t('tab_tickets')} subtitle={t(isLite ? 'ui_lite_tickets_sub' : 'ui_tickets_sub')}>
        <Button variant="primary" onClick={() => setDialog({ kind: 'create' })}><Plus size={18} />{t('ui_ticket_new')}</Button>
      </ViewHeader>
      <div className={v.tickets}>
        <div className={v.queue}>
          <div className={v.queueFilters}>
            <Segmented<Group>
              label={t('ui_filter_state')}
              value={group}
              onChange={setGroup}
              options={[
                { value: 'all', label: t('ui_tickets_all') },
                { value: 'open', label: t('ui_tickets_open') },
                { value: 'active', label: t('ui_tickets_active') },
                { value: 'done', label: t('ui_tickets_done') },
              ]}
            />
            {!isLite && <div className={v.queueRow}>
              <select className={ui.input} aria-label={t('report_priority')} value={priority} onChange={(e) => setPriority(e.target.value as Priority | '')}>
                <option value="">{t('report_priority')}: {t('ui_filter_all_f')}</option>
                {priorities.map((p) => <option key={p} value={p}>{priorityLabel(t, p)}</option>)}
              </select>
            </div>}
          </div>
          <div className={cx(ui.scroll, v.queueList)} aria-label={t('ui_queue')}>
            {list.length ? list.map((x) => (
              <TicketCard key={x.id} tk={x} selected={x.id === selected} onSelect={() => setSelected(x.id)} />
            )) : <Empty icon={<Inbox size={22} />}>{t('queue_empty')}</Empty>}
          </div>
        </div>
        {tk ? <Detail tk={tk} openDialog={setDialog} reason={reason} setReason={setReason} /> : (
          <section className={ui.card}><Empty icon={<Inbox size={22} />}>{t('ui_ticket_select')}</Empty></section>
        )}
      </div>

      {!isLite && dialog?.kind === 'transfer' && tk && (
        <Dialog
          title={t('ui_transfer_title', { id: tk.id })}
          onClose={close}
          footer={<>
            <Button onClick={close}>{t('ui_cancel')}</Button>
            <Button variant="primary" disabled={!target} onClick={() => { void send('ticket_transfer', { id: tk.id, to: target }); close(); }}>{t('transfer')}</Button>
          </>}
        >
          <label className={ui.field}>
            <span className={ui.label}>{t('ui_transfer_to')}</span>
            <select className={ui.input} value={target} onChange={(e) => setTarget(e.target.value)} disabled={!staff.length}>
              <option value="">—</option>
              {staff.map((x) => <option key={x.value} value={x.value}>{x.label}</option>)}
            </select>
          </label>
          {!staff.length && <p className={v.setHint}>{t('ui_transfer_none')}</p>}
        </Dialog>
      )}
      {dialog?.kind === 'resolve' && tk && (
        <Dialog
          title={t('ui_resolve_title', { id: tk.id })}
          onClose={close}
          footer={<>
            <Button onClick={close}>{t('ui_cancel')}</Button>
            <Button variant="primary" disabled={!text.trim() || overLimit(text, resolutionMax)} onClick={() => { void send('ticket_resolve', { id: tk.id, resolution: text.trim() }); close(); }}>{t('resolve')}</Button>
          </>}
        >
          <label className={ui.field}>
            <span className={ui.label}>{t('ui_ticket_resolution')}</span>
            <textarea className={ui.input} rows={4} value={text} placeholder={t('ui_resolution_ph')} onChange={(e) => setText(e.target.value)} />
          </label>
          <LimitHint text={text} max={resolutionMax} />
        </Dialog>
      )}
      {!isLite && dialog?.kind === 'ban' && tk && (
        <Dialog
          title={t('ui_confirm_ban_title')}
          onClose={close}
          footer={<>
            <Button onClick={close}>{t('ui_cancel')}</Button>
            <Button
              variant="danger"
              disabled={!can('mod.ban') || !reason.trim()}
              onClick={() => {
                const duration = banDuration === '' ? undefined : Number(banDuration);
                void send('mod_action', { action: 'ban', target: tk.reporter, reason: reason.trim(), ticket: tk.id, duration });
                setReason('');
                close();
              }}
            >
              {t('mod_ban')}
            </Button>
          </>}
        >
          <p>{t('ui_confirm_ban_body', { target: shortId(tk.reporter) })}</p>
          <p className={ui.label}>{t('ui_mod_reason')}: {reason || '—'}</p>
          <label className={ui.field}>
            <span className={ui.label}>{t('ui_ban_duration')}</span>
            <select className={ui.input} value={banDuration} onChange={(e) => setBanDuration(e.target.value)}>
              <option value="">{t('ui_ban_default')}</option>
              <option value="3600">{t('ui_ban_hour')}</option>
              <option value="86400">{t('ui_ban_day')}</option>
              <option value="604800">{t('ui_ban_week')}</option>
              <option value="0">{t('ui_ban_permanent')}</option>
            </select>
          </label>
        </Dialog>
      )}
      {dialog?.kind === 'create' && (
        <Dialog
          title={t('report_open')}
          onClose={close}
          footer={<>
            <Button onClick={close}>{t('ui_cancel')}</Button>
            <Button variant="primary" disabled={creating || !text.trim() || overLimit(text, reportMax)} onClick={() => { void submitReport(); }}>{t('report_submit')}</Button>
          </>}
        >
          <div className={v.queueRow}>
            <label className={ui.field} style={{ flex: 1 }}>
              <span className={ui.label}>{t('report_category')}</span>
              <select className={ui.input} value={category} onChange={(e) => setCategory(e.target.value)}>
                {categories.map((c) => <option key={c} value={c}>{categoryLabel(t, c)}</option>)}
              </select>
            </label>
            {!isLite && <label className={ui.field} style={{ flex: 1 }}>
              <span className={ui.label}>{t('report_priority')}</span>
              <select className={ui.input} value={newPriority} onChange={(e) => setNewPriority(e.target.value as Priority)}>
                {priorities.map((p) => <option key={p} value={p}>{priorityLabel(t, p)}</option>)}
              </select>
            </label>}
          </div>
          <label className={ui.field}>
            <span className={ui.label}>{t('report_description')}</span>
            <textarea className={ui.input} rows={4} value={text} onChange={(e) => setText(e.target.value)} />
          </label>
          <LimitHint text={text} max={reportMax} />
          {createError && <p className={v.setHint} role="alert">{createError}</p>}
        </Dialog>
      )}
    </main>
  );
}
