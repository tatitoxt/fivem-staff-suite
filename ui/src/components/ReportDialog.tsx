import { Bug, CircleHelp, Ellipsis, ShieldAlert, UserX } from 'lucide-react';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { isLite } from '../edition';
import { categoryLabel, priorityLabel } from '../labels';
import { useApp } from '../store';
import type { Priority, TicketCreateResult } from '../types';
import { LimitHint, overLimit } from '../views/TicketChat';
import v from '../views/views.module.css';
import { Button, cx, Dialog, ui } from './ui';

const ICONS: Record<string, ReactNode> = {
  bug: <Bug size={16} />, player: <UserX size={16} />, staff: <ShieldAlert size={16} />,
  question: <CircleHelp size={16} />, other: <Ellipsis size={16} />,
};

// Reporte rápido: categoría en tiles, descripción y captura opcional (screenshot-basic).
export function ReportDialog({ onClose, staff = false }: { onClose: () => void; staff?: boolean }) {
  const { state, t, send } = useApp();
  const categories = state.config.categories ?? ['bug', 'player', 'staff', 'question', 'other'];
  const priorities = state.config.priorities ?? ['low', 'normal', 'high', 'urgent'];
  const max = state.config.limits?.ticket_body;
  const canAttach = !isLite && !!state.config.evidence;
  const [category, setCategory] = useState(categories.includes('player') ? 'player' : categories[0]);
  const [priority, setPriority] = useState<Priority>('normal');
  const [text, setText] = useState('');
  const [attach, setAttach] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const tiles = useRef<(HTMLButtonElement | null)[]>([]);
  const ok = !busy && !!text.trim() && !overLimit(text, max);

  const submit = async () => {
    if (!ok) return;
    setBusy(true);
    setError(null);
    const res = (await send('ticket_create', {
      category, priority: isLite || !staff ? 'normal' : priority, body: text.trim(), ...(canAttach && attach ? { attach: true } : {}),
    })) as TicketCreateResult | null;
    setBusy(false);
    if (res?.ok) onClose();
    else setError(res?.error || t('report_failed'));
  };

  const submitRef = useRef(submit);
  submitRef.current = submit;
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); void submitRef.current(); }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const cur = Math.max(0, categories.indexOf(category));
  const onTileKey = (e: React.KeyboardEvent) => {
    const step = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[e.key];
    if (!step) return;
    e.preventDefault();
    const next = (cur + step + categories.length) % categories.length;
    setCategory(categories[next]);
    tiles.current[next]?.focus();
  };

  return (
    <Dialog
      title={staff ? t('report_open') : t('ui_report_new')}
      onClose={onClose}
      footer={<>
        <span className={v.footHint}>{t('ui_report_send_hint')}</span>
        <Button onClick={onClose}>{t('ui_cancel')}</Button>
        <Button variant="primary" disabled={!ok} onClick={() => void submit()}>{t('report_submit')}</Button>
      </>}
    >
      <div className={v.reportBody}>
        <div className={ui.field}>
          <span className={ui.label} id="report-cat">{t('report_category')}</span>
          <div className={v.tiles} role="radiogroup" aria-labelledby="report-cat" onKeyDown={onTileKey}>
            {categories.map((c, i) => (
              <button
                key={c}
                ref={(el) => { tiles.current[i] = el; }}
                type="button"
                role="radio"
                aria-checked={c === category}
                tabIndex={i === cur ? 0 : -1}
                className={cx(v.tile, c === category && v.tileOn)}
                onClick={() => setCategory(c)}
              >
                {ICONS[c] ?? ICONS.other}
                {categoryLabel(t, c)}
              </button>
            ))}
          </div>
        </div>
        {staff && !isLite && (
          <label className={ui.field}>
            <span className={ui.label}>{t('report_priority')}</span>
            <select className={ui.input} value={priority} onChange={(e) => setPriority(e.target.value as Priority)}>
              {priorities.map((p) => <option key={p} value={p}>{priorityLabel(t, p)}</option>)}
            </select>
          </label>
        )}
        <label className={ui.field}>
          <span className={ui.label}>{t('report_description')}</span>
          <textarea className={ui.input} rows={4} value={text} placeholder={t('ui_report_what')} onChange={(e) => setText(e.target.value)} />
          {max != null && <span className={v.counter} aria-hidden>{new TextEncoder().encode(text.trim()).length}/{max}</span>}
        </label>
        <LimitHint text={text} max={max} />
        {canAttach && (
          <label className={v.attach}>
            <input type="checkbox" checked={attach} onChange={(e) => setAttach(e.target.checked)} />
            <span>{t('ui_report_attach')}<small>{t('ui_report_attach_hint')}</small></span>
          </label>
        )}
        {error && <p className={v.setHint} role="alert">{error}</p>}
      </div>
    </Dialog>
  );
}
