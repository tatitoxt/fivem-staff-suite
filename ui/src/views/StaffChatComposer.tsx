import { MessageSquare, Send } from 'lucide-react';
import { useState } from 'react';
import { Button, cx, ui } from '../components/ui';
import { useApp } from '../store';
import type { TicketCreateResult } from '../types';
import { LimitHint, overLimit } from './TicketChat';
import v from './views.module.css';

export function StaffChatComposer() {
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
    <form className={cx(ui.card, v.setCard)} aria-labelledby="staff-chat-heading"
      onSubmit={(e) => { e.preventDefault(); void submit(); }}>
      <div className={v.setHead}>
        <span className={v.setIcon}><MessageSquare size={20} /></span>
        <h2 id="staff-chat-heading">{t('ui_staff_chat')}</h2>
      </div>
      <textarea className={ui.input} aria-label={t('ui_staff_chat_message')}
        placeholder={t('ui_staff_chat_message')} value={body} disabled={sending}
        onChange={(e) => setBody(e.target.value)} />
      <LimitHint text={body} max={max} />
      {result && <p className={v.setHint} role={result.ok ? 'status' : 'alert'}>{result.text}</p>}
      <Button variant="primary" size="small" type="submit" disabled={!canSend}>
        <Send size={16} />{t('ui_send')}
      </Button>
    </form>
  );
}
