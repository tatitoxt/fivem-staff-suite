import { MessageSquare, Send } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { Button, Empty, cx, ui } from '../components/ui';
import { formatRelative } from '../format';
import { useApp } from '../store';
import type { TicketCreateResult } from '../types';
import v from './views.module.css';

const encoder = new TextEncoder();
// Los límites del servidor se miden en bytes.
export function overLimit(text: string, max?: number) {
  return max != null && encoder.encode(text.trim()).length > max;
}

export function LimitHint({ text, max }: { text: string; max?: number }) {
  const { t } = useApp();
  return overLimit(text, max) ? <p className={v.setHint} role="alert">{t('input_too_long', { max: max ?? 0 })}</p> : null;
}

interface ChatMessage {
  label: string;
  mine: boolean;
  body: string;
  ts: number;
  internal?: boolean;
}

interface ChatProps {
  id: number;
  messages: ChatMessage[];
  asReporter?: boolean;
  allowInternal?: boolean;
  allowPublic?: boolean;
}

export function TicketChat({ id, messages, asReporter = false, allowInternal = false, allowPublic = true }: ChatProps) {
  const { state, t, send } = useApp();
  const [body, setBody] = useState('');
  const [internal, setInternal] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string>();
  const list = useRef<HTMLDivElement>(null);
  const canned = !asReporter ? state.config.canned ?? [] : [];
  const disabled = sending || !(internal ? allowInternal : allowPublic);
  const max = state.config.limits?.message_body;
  const canSend = !disabled && !!body.trim() && !overLimit(body, max);
  const placeholder = t(asReporter ? 'ui_reply_placeholder' : internal ? 'ui_note_placeholder' : 'ui_msg_placeholder');

  useEffect(() => {
    if (list.current) list.current.scrollTop = list.current.scrollHeight;
  }, [id, messages.length]);

  const submit = async () => {
    if (!canSend) return;
    setSending(true);
    setError(undefined);
    const message = { id, body: body.trim() };
    const result = (asReporter
      ? await send('ticket_reply', message)
      : await send('ticket_message', { ...message, internal })) as TicketCreateResult | null;
    setSending(false);
    if (result?.ok) setBody('');
    else setError(result?.error ?? t('ticket_message_failed'));
  };

  return (
    <section className={cx(ui.card, v.chat)}>
      <div className={v.chatHead}>{t('ui_chat_title')}</div>
      {messages.length ? (
        <div className={cx(ui.scroll, v.messages)} ref={list} tabIndex={0} role="log" aria-label={t('ui_chat_title')}>
          {messages.map((message, i) => (
            <div key={i} className={cx(v.msg, message.mine && v.msgMine, message.internal && v.msgInternal)}>
              <div className={v.msgMeta}>
                <span>{message.label}</span>
                {message.internal && <span>· {t('ui_internal_note')}</span>}
                <span>· {formatRelative(message.ts, state.locale)}</span>
              </div>
              <div className={v.msgBody}>{message.body}</div>
            </div>
          ))}
        </div>
      ) : <Empty icon={<MessageSquare size={22} />}>{t('ui_chat_empty')}</Empty>}
      {(allowPublic || allowInternal) && (
        <div className={cx(v.composer, internal && v.composerInternal)}>
          {canned.length > 0 && (
            <select
              className={cx(ui.input, v.cannedPick)}
              aria-label={t('ui_canned')}
              value=""
              disabled={disabled}
              onChange={(e) => {
                const c = canned.find((x) => x.id === e.target.value);
                if (c) setBody((b) => (b.trim() ? `${b.trimEnd()} ${c.text}` : c.text));
              }}
            >
              <option value="">{t('ui_canned_pick')}</option>
              {canned.map((c) => <option key={c.id} value={c.id}>{c.title}</option>)}
            </select>
          )}
          <textarea
            className={ui.input}
            value={body}
            disabled={disabled}
            aria-label={placeholder}
            placeholder={placeholder}
            onChange={(e) => setBody(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && !e.shiftKey && !e.nativeEvent.isComposing) {
                e.preventDefault();
                void submit();
              }
            }}
          />
          <LimitHint text={body} max={max} />
          {error && <p className={v.setHint} role="alert">{error}</p>}
          <div className={v.composerRow}>
            {allowInternal && (
              <button
                type="button"
                role="switch"
                aria-checked={internal}
                className={cx(v.switch, internal && v.switchOn)}
                disabled={sending}
                onClick={() => setInternal((value) => !value)}
              >
                <span className={v.switchTrack} />
                {t('ui_internal_toggle')}
              </button>
            )}
            <Button variant="primary" size="small" disabled={!canSend} onClick={() => void submit()}>
              <Send size={16} />{t('ui_send')}
            </Button>
          </div>
        </div>
      )}
    </section>
  );
}
