import { Bell, Inbox, Megaphone, MessageSquare, TriangleAlert } from 'lucide-react';
import { useEffect, type ReactNode } from 'react';
import { priorityLabel, priorityTone } from '../labels';
import { useApp, type Notice } from '../store';
import type { NoticeKind } from '../types';
import s from './layout.module.css';
import { Badge, cx } from './ui';

const ICONS: Record<NoticeKind, ReactNode> = {
  info: <Bell size={15} />, reply: <MessageSquare size={15} />, warn: <TriangleAlert size={15} />,
  announce: <Megaphone size={15} />, report: <Inbox size={15} />,
};

function NoticeItem({ n }: { n: Notice }) {
  const { dispatch, t } = useApp();
  useEffect(() => {
    const id = window.setTimeout(() => dispatch({ type: 'dismissNotice', id: n.id }), n.duration ?? 6000);
    return () => window.clearTimeout(id);
  }, [n.id, n.duration, dispatch]);
  return (
    <div className={cx(s.notice, s[`notice-${n.kind}`])}>
      <span className={s.noticeIcon} aria-hidden>{ICONS[n.kind] ?? ICONS.info}</span>
      <div className={s.noticeBody}>
        <div className={s.noticeTitle}>
          {t(`ui_notice_${n.kind}`)}
          {n.priority && <Badge tone={priorityTone[n.priority]} dot>{priorityLabel(t, n.priority)}</Badge>}
        </div>
        <div className={s.noticeText}>{n.text}</div>
      </div>
    </div>
  );
}

// Avisos con el panel cerrado: no toman el foco ni reciben clics (pointer-events: none).
export function Notices() {
  const { state, t } = useApp();
  if (!state.notices.length) return null;
  return (
    <div className={s.notices} role="status" aria-live="polite" aria-label={t('ui_notice_region')}>
      {state.notices.map((n) => <NoticeItem key={n.id} n={n} />)}
    </div>
  );
}
