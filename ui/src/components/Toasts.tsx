import { useEffect } from 'react';
import { useApp } from '../store';
import { cx } from './ui';
import s from './layout.module.css';

export function Toasts() {
  const { state, dispatch } = useApp();
  const first = state.toasts[0];
  useEffect(() => {
    if (!first) return;
    const id = setTimeout(() => dispatch({ type: 'dismissToast', id: first.id }), 3600);
    return () => clearTimeout(id);
  }, [first, dispatch]);
  return (
    <div className={s.toasts} role="status" aria-live="polite">
      {state.toasts.map((x) => (
        <div key={x.id} className={cx(s.toast, s[`toast-${x.kind}`])}>
          <span className={s.toastDot} />
          {x.text}
        </div>
      ))}
    </div>
  );
}
