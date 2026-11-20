import { UserRound } from 'lucide-react';
import { useState } from 'react';
import { Button, Dialog, ui } from '../components/ui';
import { formatDateTime, shortId } from '../format';
import { stateLabel } from '../labels';
import { useApp } from '../store';
import type { PlayerProfile, PlayerProfileEntry } from '../types';
import { LimitHint, overLimit } from './TicketChat';
import v from './views.module.css';

interface ProfileResult {
  ok?: boolean;
  error?: string;
  data?: PlayerProfile;
}

function History({ title, items }: { title: string; items: PlayerProfileEntry[] }) {
  const { state, t } = useApp();
  return (
    <section>
      <h3>{title}</h3>
      {Array.isArray(items) && items.length > 0 ? (
        <ul className={v.evidenceList}>
          {items.map((item) => (
            <li key={item.seq}>
              <div>
                <strong>{item.failed ? t('ui_player_profile_ban_failed') : item.text}</strong>
                {item.failed && <div>{item.text}</div>}
                <div>{shortId(item.actor)} · {formatDateTime(item.ts, state.locale)}</div>
              </div>
            </li>
          ))}
        </ul>
      ) : <p>{t('ui_player_profile_empty')}</p>}
    </section>
  );
}

export function PlayerProfileButton({ id }: { id: number }) {
  const { state, t, send, can } = useApp();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  const [profile, setProfile] = useState<PlayerProfile>();
  const [error, setError] = useState<string>();
  const [note, setNote] = useState('');
  const max = state.config.limits?.message_body ?? 1000;

  async function load() {
    setOpen(true);
    setProfile(undefined);
    setError(undefined);
    setBusy(true);
    const result = await send('player_profile', { id }) as ProfileResult | null;
    setBusy(false);
    if (result?.ok && result.data) setProfile(result.data);
    else setError(result?.error ?? t('player_profile_failed'));
  }

  async function saveNote() {
    if (busy || !note.trim() || overLimit(note, max)) return;
    setError(undefined);
    setBusy(true);
    const result = await send('player_profile_note', { id, body: note.trim() }) as ProfileResult | null;
    setBusy(false);
    if (result?.ok && result.data) {
      setProfile(result.data);
      setNote('');
    } else setError(result?.error ?? t('player_profile_note_failed'));
  }

  return (
    <>
      <Button className={v.railWide} onClick={() => void load()} disabled={busy}>
        <UserRound size={16} />{t('ui_player_profile')}
      </Button>
      {open && (
        <Dialog title={t('ui_player_profile')} onClose={() => setOpen(false)}
          footer={<Button onClick={() => setOpen(false)}>{t('close')}</Button>}>
          {busy && !profile && <p role="status">{t('ui_evidence_loading')}</p>}
          {profile && <div className={v.rows}>
            <History title={t('ui_player_profile_warns')} items={profile.warns} />
            <History title={t('ui_player_profile_bans')} items={profile.bans} />
            <section>
              <h3>{t('ui_player_profile_tickets')}</h3>
              {Array.isArray(profile.tickets) && profile.tickets.length > 0 ? (
                <ul className={v.evidenceList}>
                  {profile.tickets.map((item) => (
                    <li key={item.id}>
                      <span>#{item.id} · {stateLabel(t, item.state)} · {formatDateTime(item.ts, state.locale)}</span>
                    </li>
                  ))}
                </ul>
              ) : <p>{t('ui_player_profile_empty')}</p>}
            </section>
            <History title={t('ui_player_profile_notes')} items={profile.notes} />
            {can('player.profile.note') && (
              <form onSubmit={(e) => { e.preventDefault(); void saveNote(); }}>
                <textarea className={ui.input} aria-label={t('ui_player_profile_note')}
                  placeholder={t('ui_player_profile_note')} value={note} disabled={busy}
                  onChange={(e) => setNote(e.target.value)} />
                <LimitHint text={note} max={max} />
                <Button type="submit" disabled={busy || !note.trim() || overLimit(note, max)}>
                  {t('ui_player_profile_save')}
                </Button>
              </form>
            )}
          </div>}
          {error && <p role="alert">{error}</p>}
        </Dialog>
      )}
    </>
  );
}
