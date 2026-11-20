import { Eye, MapPin, Search, Users } from 'lucide-react';
import { useEffect, useState } from 'react';
import lay from '../components/layout.module.css';
import { Button, Empty, ViewHeader, cx, ui } from '../components/ui';
import { formatDuration } from '../format';
import { useApp } from '../store';
import type { OnlinePlayer } from '../types';
import v from './views.module.css';

const normalize = (value: string) => value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

export function OnlinePlayersView() {
  const { send, t, can } = useApp();
  const [query, setQuery] = useState('');
  const [rows, setRows] = useState<OnlinePlayer[]>();
  const [error, setError] = useState<string>();
  const seeTickets = can('report.view');

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
  const visible = (rows ?? []).filter(({ id, name }) => String(id).includes(term) || normalize(name).includes(term))
    .sort((a, b) => a.id - b.id);
  const title = t('ui_nav_players');
  const acts = can('mod.goto') || can('mod.spectate');
  return (
    <main className={lay.main}>
      <ViewHeader title={title} />
      <div className={lay.viewBody}>
        <label className={v.playerSearch}>
          <Search size={16} aria-hidden />
          <input className={ui.input} aria-label={t('ui_online_search')} placeholder={t('ui_online_search')}
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
                    {key !== undefined && !self && can('mod.goto') && (
                      <Button size="small" onClick={() => void send('mod_action', { action: 'goto', target: { id, key }, reason: '' })}>
                        <MapPin size={14} aria-hidden />{t('mod_goto')}
                      </Button>
                    )}
                    {key !== undefined && !self && can('mod.spectate') && (
                      <Button size="small" onClick={() => void send('mod_action', { action: 'spectate', target: { id, key }, reason: '' })}>
                        <Eye size={14} aria-hidden />{t('mod_spectate')}
                      </Button>
                    )}
                  </div></td>}
                </tr>
              ))}</tbody>
            </table>
          </div>
        )}
      </div>
    </main>
  );
}
