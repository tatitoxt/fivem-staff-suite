import { useCallback, useEffect, useState } from 'react';
import { Button, Dialog, ui } from '../components/ui';
import { useApp } from '../store';
import type { OutgoingPayloads } from '../types';
import { LimitHint, overLimit } from './TicketChat';

interface Directory {
  players: { id: number; name: string }[];
  ranks: string[];
  capabilities: string[];
}

interface Access {
  id: number;
  identifier: string;
  baseRank?: string;
  rank: string;
  rules: Record<string, string>;
}

export function OwnerPermissionsDialog({ onClose }: { onClose: () => void }) {
  const { send, state, t } = useApp();
  const [directory, setDirectory] = useState<Directory>();
  const [access, setAccess] = useState<Access>();
  const [target, setTarget] = useState('');
  const [field, setField] = useState('rank');
  const [draft, setDraft] = useState<string>();
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const max = state.config.limits?.reason ?? 300;
  const current = field === 'rank' ? access?.rank : access?.rules[field];
  const options = field === 'rank' ? directory?.ranks ?? [] : ['allow', 'deny'];
  const request = useCallback(async (payload: OutgoingPayloads['owner_permissions']) => {
    setBusy(true);
    setError('');
    const result = await send('owner_permissions', payload) as
      { ok?: boolean; error?: string; data?: Directory | Access } | null;
    if (result?.ok && result.data) {
      if ('players' in result.data) setDirectory(result.data);
      else {
        setAccess(result.data);
        setDraft(undefined);
        setReason('');
      }
    } else setError(result?.error ?? t('permissions_failed'));
    setBusy(false);
  }, [send, t]);
  useEffect(() => void request({}), [request]);

  return (
    <Dialog title={t('ui_permissions_title')} onClose={onClose} footer={<>
      <Button onClick={onClose}>{t('close')}</Button>
      {!directory && <Button disabled={busy} onClick={() => void request({})}>{t('ui_retry')}</Button>}
      {access && draft && draft !== current && <Button variant="primary"
        disabled={busy || !reason.trim() || overLimit(reason.trim(), max)}
        onClick={() => void request({ target: access.id, identifier: access.identifier, field, value: draft, reason: reason.trim() })}>
        {t('ui_permissions_save')}
      </Button>}
    </>}>
      {busy && <p role="status">{t('ui_loading')}</p>}
      {error && <p role="alert">{error}</p>}
      {directory && <>
        <label>{t('ui_permissions_player')}
          <select className={ui.input} value={target} disabled={busy} onChange={(event) => {
            setTarget(event.target.value);
            setAccess(undefined);
            setField('rank');
            setDraft(undefined);
            if (event.target.value) void request({ target: Number(event.target.value) });
          }}>
            <option value="">{t('ui_permissions_select')}</option>
            {directory.players.map((player) => <option key={player.id} value={player.id}>{player.name} #{player.id}</option>)}
          </select>
        </label>
        {access && <>
          <label>{t('ui_permissions_field')}
            <select className={ui.input} value={field} disabled={busy}
              onChange={(event) => { setField(event.target.value); setDraft(undefined); }}>
              <option value="rank">{t('ui_permissions_rank')}</option>
              {directory.capabilities.map((cap) => <option key={cap} value={cap}>ACE · {cap}</option>)}
            </select>
          </label>
          {field === 'rank' && access.baseRank && <p>{t('ui_permissions_base', { rank: t('ui_rank_' + access.baseRank) })}</p>}
          <label>{t('ui_permissions_value')}
            <select className={ui.input} value={draft ?? current ?? 'inherit'} disabled={busy}
              onChange={(event) => setDraft(event.target.value)}>
              <option value="inherit">{t('ui_permissions_inherit')}</option>
              {options.map((value) => <option key={value} value={value}>
                {t((field === 'rank' ? 'ui_rank_' : 'ui_permissions_') + value)}
              </option>)}
            </select>
          </label>
          <label>{t('ui_vehicle_reason')}
            <input className={ui.input} value={reason} disabled={busy} onChange={(event) => setReason(event.target.value)} />
          </label>
          <LimitHint text={reason.trim()} max={max} />
        </>}
      </>}
    </Dialog>
  );
}
