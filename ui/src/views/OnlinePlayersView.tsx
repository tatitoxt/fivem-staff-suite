import { Eye, MapPin, Search, Trash2, Users, Wrench } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import lay from '../components/layout.module.css';
import { Button, Dialog, Empty, ViewHeader, cx, ui } from '../components/ui';
import { formatDuration } from '../format';
import { useApp } from '../store';
import type { OnlinePlayer, OnlinePlayerRef } from '../types';
import { LimitHint, overLimit } from './TicketChat';
import v from './views.module.css';

const normalize = (value: string) => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

export function OnlinePlayersView() {
  const { send, state, t, can } = useApp();
  const [query, setQuery] = useState('');
  const [rows, setRows] = useState<OnlinePlayer[]>();
  const [error, setError] = useState<string>();
  const [deleting, setDeleting] = useState<{ target: OnlinePlayerRef; name: string }>();
  const [reason, setReason] = useState('');
  const search = useRef<HTMLInputElement>(null);
  const selected = state.viewAction;
  const maxReason = state.config.limits?.reason ?? 300;
  const seeTickets = can('report.view');
  useEffect(() => { if (selected) search.current?.focus(); }, [selected]);

  useEffect(() => {
    let active = true;
    let timer: number;
    async function refresh() {
      const result = await send('online_players') as { ok?: boolean; data?: OnlinePlayer[]; error?: string } | null;
      if (!active) return;
      setRows(result?.ok ? (Array.isArray(result.data) ? result.data : []) : undefined);
      setError(result?.ok ? undefined : result?.error ?? t('online_players_failed'));
      timer = window.setTimeout(() => void refresh(), 15000);
    }
    void refresh();
    return () => { active = false; window.clearTimeout(timer); };
  }, [send, t]);

  const term = normalize(query.trim());
  const visible = (rows ?? []).filter(({ id, name, ping, played_seconds, tickets }) => {
    const values = [`#${id}`, name, `${ping} ms`, formatDuration(played_seconds)];
    if (seeTickets && tickets !== undefined) values.push(`${tickets} ${t('ui_online_tickets')}`);
    return values.some((value) => normalize(value).includes(term));
  })
    .sort((a, b) => a.id - b.id);
  const title = t('ui_nav_players');
  const actionAllowed = (action: string) => (!selected || selected === action) && can(`mod.${action}`);
  const canRepair = actionAllowed('repair_vehicle');
  const canDelete = actionAllowed('delete_vehicle');
  const canGoto = actionAllowed('goto');
  const canSpectate = actionAllowed('spectate');
  const acts = canGoto || canSpectate || canRepair || canDelete;
  return (
    <main className={lay.main}>
      <ViewHeader title={title} subtitle={selected ? t(`mod_${selected}`) : undefined} />
      <div className={lay.viewBody}>
        <label className={v.playerSearch}>
          <Search size={16} aria-hidden />
          <input ref={search} className={ui.input} aria-label={t('ui_online_search')} placeholder={t('ui_online_search')}
            value={query} onChange={(event) => setQuery(event.target.value)} maxLength={80} />
        </label>
        {error && <p role="alert">{error}</p>}
        {!error && !rows && <p role="status">{t('ui_loading')}</p>}
        {rows && !visible.length && <Empty icon={<Users size={18} />}>{t('ui_online_empty')}</Empty>}
        {visible.length > 0 && (
          <div className={cx(ui.scroll, v.tableWrap)} role="region" aria-label={title} tabIndex={0}>
            <table className={v.table}>
              <thead><tr>
                <th scope="col">ID</th>
                <th scope="col">{t('ui_online_name')}</th>
                <th scope="col">Ping</th>
                <th scope="col">{t('ui_player_profile_playtime')}</th>
                {seeTickets && <th scope="col">{t('ui_online_tickets')}</th>}
                {acts && <th scope="col">{t('ui_cmd_actions')}</th>}
              </tr></thead>
              <tbody>{visible.map(({ id, key, self, name, ping, played_seconds, tickets }) => (
                <tr key={id}>
                  <td>#{id}</td><td>{name}</td><td>{ping} ms</td><td>{formatDuration(played_seconds)}</td>
                  {seeTickets && <td>{tickets ?? '—'}</td>}
                  {acts && <td><div className={v.playerActions}>
                    {key !== undefined && !self && canGoto && (
                      <Button size="small" onClick={() => void send('mod_action', { action: 'goto', target: { id, key }, reason: '' })}>
                        <MapPin size={14} aria-hidden />{t('mod_goto')}
                      </Button>
                    )}
                    {key !== undefined && !self && canSpectate && (
                      <Button size="small" onClick={() => void send('mod_action', { action: 'spectate', target: { id, key }, reason: '' })}>
                        <Eye size={14} aria-hidden />{t('mod_spectate')}
                      </Button>
                    )}
                    {key !== undefined && canRepair && (
                      <Button size="small" icon aria-label={t('mod_repair_vehicle')} title={t('mod_repair_vehicle')}
                        onClick={() => void send('mod_action', { action: 'repair_vehicle', target: { id, key }, reason: '' })}>
                        <Wrench size={16} aria-hidden />
                      </Button>
                    )}
                    {key !== undefined && canDelete && (
                      <Button size="small" icon aria-label={t('mod_delete_vehicle')} title={t('mod_delete_vehicle')}
                        onClick={() => { setReason(''); setDeleting({ target: { id, key }, name }); }}>
                        <Trash2 size={16} aria-hidden />
                      </Button>
                    )}
                  </div></td>}
                </tr>
              ))}</tbody>
            </table>
          </div>
        )}
      </div>
      {deleting && canDelete && (
        <Dialog title={t('mod_delete_vehicle')} onClose={() => setDeleting(undefined)} footer={<>
          <Button onClick={() => setDeleting(undefined)}>{t('ui_cancel')}</Button>
          <Button variant="danger" disabled={!reason.trim() || overLimit(reason.trim(), maxReason)} onClick={() => {
            void send('mod_action', { action: 'delete_vehicle', target: deleting.target, reason: reason.trim() });
            setDeleting(undefined);
          }}>{t('mod_delete_vehicle')}</Button>
        </>}>
          <p>{t('ui_vehicle_confirm', { name: deleting.name, id: deleting.target.id })}</p>
          <label>{t('ui_vehicle_reason')}
            <input className={ui.input} value={reason} onChange={(event) => setReason(event.target.value)} />
          </label>
          <LimitHint text={reason.trim()} max={maxReason} />
        </Dialog>
      )}
    </main>
  );
}
