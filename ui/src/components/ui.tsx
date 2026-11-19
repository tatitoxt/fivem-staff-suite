import { useEffect, useRef, type ButtonHTMLAttributes, type ReactNode } from 'react';
import { X } from 'lucide-react';
import s from '../styles/ui.module.css';
import v from './layout.module.css';
import type { Tone } from '../labels';
import { useApp } from '../store';

export function cx(...xs: (string | false | null | undefined)[]) {
  return xs.filter(Boolean).join(' ');
}

type Variant = 'primary' | 'secondary' | 'danger' | 'ghost';

export function Button({
  variant = 'secondary', size, icon, className, ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; size?: 'small'; icon?: boolean }) {
  return (
    <button
      type="button"
      className={cx(s.btn, s[variant], size && s.small, icon && s.icon, className)}
      {...rest}
    />
  );
}

export function Badge({ tone, dot, children, title }: { tone: Tone; dot?: boolean; children: ReactNode; title?: string }) {
  return (
    <span className={cx(s.badge, s[`tone-${tone}`])} title={title}>
      {dot && <span className={s.dot} />}
      {children}
    </span>
  );
}

export function Empty({ icon, children }: { icon?: ReactNode; children: ReactNode }) {
  return (
    <div className={s.empty}>
      {icon && <div className={s.emptyIcon}>{icon}</div>}
      <div>{children}</div>
    </div>
  );
}

export function Segmented<T extends string>({
  value, options, onChange, label,
}: { value: T; options: { value: T; label: string }[]; onChange: (v: T) => void; label: string }) {
  const refs = useRef<(HTMLButtonElement | null)[]>([]);
  const current = Math.max(0, options.findIndex((o) => o.value === value));
  const move = (i: number) => {
    const next = (i + options.length) % options.length;
    onChange(options[next].value);
    refs.current[next]?.focus();
  };
  const onKeyDown = (e: React.KeyboardEvent) => {
    const step = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[e.key];
    if (step) { e.preventDefault(); move(current + step); }
    else if (e.key === 'Home') { e.preventDefault(); move(0); }
    else if (e.key === 'End') { e.preventDefault(); move(options.length - 1); }
  };
  return (
    <div className={s.segmented} role="radiogroup" aria-label={label} onKeyDown={onKeyDown}>
      {options.map((o, i) => (
        <button
          key={o.value}
          ref={(el) => { refs.current[i] = el; }}
          type="button"
          role="radio"
          aria-checked={value === o.value}
          tabIndex={i === current ? 0 : -1}
          className={cx(s.segment, value === o.value && s.segmentOn)}
          onClick={() => onChange(o.value)}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function ViewHeader({ title, subtitle, children }: { title: string; subtitle: string; children?: ReactNode }) {
  const { t, send } = useApp();
  return (
    <header className={v.viewHeader}>
      <div className={v.viewTitles}>
        <h1>{title}</h1>
        <p>{subtitle}</p>
      </div>
      <div className={v.viewActions}>
        {children}
        <Button variant="ghost" icon aria-label={t('close')} title={t('close')} onClick={() => void send('close_ui')}>
          <X size={20} />
        </Button>
      </div>
    </header>
  );
}

const FOCUSABLE = 'a[href], button, input, select, textarea, [tabindex]';

export function Dialog({
  title, children, footer, onClose,
}: { title: string; children: ReactNode; footer: ReactNode; onClose: () => void }) {
  const ref = useRef<HTMLDivElement>(null);
  const closeRef = useRef(onClose);
  closeRef.current = onClose;
  useEffect(() => {
    const opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    const focusables = () => Array.from(ref.current?.querySelectorAll<HTMLElement>(FOCUSABLE) ?? [])
      .filter((x) => !x.hasAttribute('disabled') && x.tabIndex >= 0);
    focusables()[0]?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.stopPropagation();
        closeRef.current();
        return;
      }
      if (e.key !== 'Tab') return;
      const items = focusables();
      if (!items.length) return;
      const first = items[0];
      const last = items[items.length - 1];
      const active = document.activeElement;
      if (!ref.current?.contains(active)) { e.preventDefault(); first.focus(); }
      else if (e.shiftKey && active === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && active === last) { e.preventDefault(); first.focus(); }
    };
    window.addEventListener('keydown', onKey, true);
    return () => {
      window.removeEventListener('keydown', onKey, true);
      if (opener?.isConnected) opener.focus();
    };
  }, []);
  return (
    <div className={v.overlay} onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <div className={v.dialog} role="dialog" aria-modal="true" aria-label={title} ref={ref}>
        <h2>{title}</h2>
        <div className={v.dialogBody}>{children}</div>
        <div className={v.dialogFooter}>{footer}</div>
      </div>
    </div>
  );
}

export { s as ui };
