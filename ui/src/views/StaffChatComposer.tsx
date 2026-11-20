import { Send } from 'lucide-react';
import { useState } from 'react';
import { Button, Dialog, ui } from '../components/ui';
import { useApp } from '../store';
import type { TicketCreateResult } from '../types';
import { LimitHint, overLimit } from './TicketChat';
import v from './views.module.css';

export function StaffChatComposer({ onClose }: { onClose: () => void }) {
  const { state, t, send } = useApp();
  const [body, setBody] = useState('');
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; text: string }>();
  const max = state.config.limits?.message_body ?? 1000;
  const canSend = !sending && !!body.trim() && !overLimit(body, max);

  async function submit() {
    if (!canSend) return;
    setSending(true);
    setResult(undefined);
    const response = await send('staff_chat', { body: body.trim() }) as TicketCreateResult | null;
    setSending(false);
    if (response?.ok) setBody('');
    setResult(response?.ok
      ? { ok: true, text: t('staff_chat_sent') }
      : { ok: false, text: response?.error ?? t('staff_chat_failed') });
  }

  return (
    <Dialog title={t('ui_staff_chat')} onClose={onClose} footer={<>
      <Button size="small" onClick={onClose}>{t('close')}</Button>
      <Button variant="primary" size="small" type="submit" form="staff-chat-form" disabled={!canSend}>
        <Send size={15} aria-hidden />{t('ui_send')}
      </Button>
    </>}>
      <form id="staff-chat-form" className={v.actionForm} onSubmit={(e) => { e.preventDefault(); void submit(); }}>
        <label className={ui.field}>
          <span className={ui.label}>{t('ui_staff_chat_message')}</span>
          <textarea className={ui.input} value={body} disabled={sending}
            onChange={(e) => setBody(e.target.value)} />
        </label>
        <LimitHint text={body} max={max} />
        {result && <p className={v.setHint} role={result.ok ? 'status' : 'alert'}>{result.text}</p>}
      </form>
    </Dialog>
  );
}
