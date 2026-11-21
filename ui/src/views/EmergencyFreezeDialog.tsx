import { useCallback, useEffect, useState } from 'react';
import { Button, Dialog, ui } from '../components/ui';
import { useApp } from '../store';
import { LimitHint, overLimit } from './TicketChat';

export function EmergencyFreezeDialog({ onClose }: { onClose: () => void }) {
  const { send, state, t } = useApp();
  const [enabled, setEnabled] = useState<boolean>();
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const max = state.config.limits?.reason ?? 300;
  const request = useCallback(async (next?: boolean, explanation?: string) => {
    setBusy(true);
    setError('');
    const result = await send('emergency_freeze', { enabled: next, reason: explanation }) as
      { ok?: boolean; data?: { enabled: boolean }; error?: string } | null;
    if (result?.ok && result.data) {
      setEnabled(result.data.enabled);
      setReason('');
    } else setError(result?.error ?? t('emergency_failed'));
    setBusy(false);
  }, [send, t]);
  useEffect(() => void request(), [request]);
  return (
    <Dialog title={t('ui_emergency_title')} onClose={onClose} footer={<>
      <Button onClick={onClose}>{t('close')}</Button>
      {enabled === undefined ? <Button disabled={busy} onClick={() => void request()}>{t('ui_retry')}</Button>
        : <Button variant={enabled ? 'primary' : 'danger'}
          disabled={busy || !reason.trim() || overLimit(reason.trim(), max)}
          onClick={() => void request(!enabled, reason.trim())}>
          {t(enabled ? 'ui_emergency_release' : 'ui_emergency_freeze')}
        </Button>}
    </>}>
      <p role="status">{t(enabled === undefined ? 'ui_loading' : enabled ? 'emergency_started' : 'emergency_released')}</p>
      {error && <p role="alert">{error}</p>}
      {enabled !== undefined && <>
        <label>{t('ui_vehicle_reason')}
          <input className={ui.input} value={reason} onChange={(event) => setReason(event.target.value)} />
        </label>
        <LimitHint text={reason.trim()} max={max} />
      </>}
    </Dialog>
  );
}
