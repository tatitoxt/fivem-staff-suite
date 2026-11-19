import { Star } from 'lucide-react';
import { useState } from 'react';
import { useApp } from '../store';
import v from '../views/views.module.css';
import { Button, cx, Dialog } from './ui';

// Valoración 1–5 que ve el jugador cuando el staff resuelve su reporte.
export function RatePrompt() {
  const { state, dispatch, t, send } = useApp();
  const [score, setScore] = useState(0);
  const id = state.ratePrompt;
  if (id == null) return null;
  const dismiss = () => {
    dispatch({ type: 'rateDone' });
    void send('rate_dismiss');
  };
  const submit = () => {
    if (!score) return;
    dispatch({ type: 'rateDone' });
    void send('ticket_rate', { id, score });
  };
  return (
    <div className={v.rateLayer}>
      <Dialog
        title={t('ui_rate_title', { id })}
        onClose={dismiss}
        footer={<>
          <Button onClick={dismiss}>{t('ui_rate_later')}</Button>
          <Button variant="primary" disabled={!score} onClick={submit}>{t('ui_rate_send')}</Button>
        </>}
      >
        <p className={v.rateQuestion}>{t('ui_rate_question')}</p>
        <div className={v.rateStars} role="radiogroup" aria-label={t('ui_rating')}>
          {[1, 2, 3, 4, 5].map((n) => (
            <button
              key={n}
              type="button"
              role="radio"
              aria-checked={score === n}
              aria-label={t('ui_rate_star', { n })}
              className={cx(v.rateStar, n <= score && v.rateStarOn)}
              onClick={() => setScore(n)}
            >
              <Star size={32} fill={n <= score ? 'currentColor' : 'none'} />
            </button>
          ))}
        </div>
      </Dialog>
    </div>
  );
}
