import { Inbox, Plus } from 'lucide-react';
import { useState } from 'react';
import lay from '../components/layout.module.css';
import { ReportDialog } from '../components/ReportDialog';
import { Badge, Button, Empty, ViewHeader, cx, ui } from '../components/ui';
import { categoryLabel, stateLabel, stateTone } from '../labels';
import { useApp } from '../store';
import type { TicketState } from '../types';
import { TicketChat } from './TicketChat';
import v from './views.module.css';

const STEP: Record<TicketState, number> = { open: 0, reopened: 0, claimed: 1, in_progress: 1, resolved: 2, closed: 2 };
const STEPS = ['ui_progress_sent', 'ui_progress_active', 'ui_progress_done'];

function Progress({ state: st }: { state: TicketState }) {
  const { t } = useApp();
  const at = STEP[st];
  return (
    <ol className={v.progress} aria-label={stateLabel(t, st)}>
      {STEPS.map((k, i) => (
        <li key={k} className={cx(v.step, i <= at && v.stepDone, i === at && v.stepNow)} aria-current={i === at ? 'step' : undefined}>
          <span className={v.stepDot} aria-hidden />{t(k)}
        </li>
      ))}
    </ol>
  );
}

export function MyReportsView() {
  const { state, dispatch, t } = useApp();
  const [selected, setSelected] = useState<number | null>(null);
  const tickets = state.myTickets;
  const active = tickets.find((ticket) => ticket.id === selected) ?? tickets[0];
  const openReport = () => dispatch({ type: 'report', open: true });

  return (
    <main className={lay.main}>
      <ViewHeader title={t('ui_my_reports')} subtitle={t('ui_my_reports_sub')}>
        <Button variant="primary" onClick={openReport} aria-keyshortcuts="N"><Plus size={16} />{t('ui_report_new')}</Button>
      </ViewHeader>
      {!active ? (
        <section className={cx(ui.card, v.listCard)}>
          <Empty icon={<Inbox size={18} />}>
            <div className={v.emptyCta}>
              {t('ui_my_reports_empty')}
              <Button onClick={openReport}><Plus size={16} />{t('ui_report_new')}</Button>
            </div>
          </Empty>
        </section>
      ) : (
        <div className={v.tickets}>
          <div className={v.queue}>
            <div className={cx(ui.scroll, v.queueList)} aria-label={t('ui_my_reports')}>
              {tickets.map((ticket) => (
                <button
                  key={ticket.id}
                  type="button"
                  className={cx(v.tcard, ticket.id === active.id && v.tcardOn)}
                  aria-pressed={ticket.id === active.id}
                  onClick={() => setSelected(ticket.id)}
                >
                  <div className={v.tcardTop}>
                    <span className={v.tcardTitle}>#{ticket.id} · {categoryLabel(t, ticket.category)}</span>
                    <Badge tone={stateTone[ticket.state]}>{stateLabel(t, ticket.state)}</Badge>
                  </div>
                  <div className={v.tcardDesc}>{ticket.description}</div>
                </button>
              ))}
            </div>
          </div>
          <div className={v.detail}>
            <section className={cx(ui.card, v.detailHead)}>
              <div className={v.detailTitle}>
                <h2>#{active.id} · {categoryLabel(t, active.category)}</h2>
                <Progress state={active.state} />
              </div>
              <div className={v.desc}>{active.description}</div>
            </section>
            <TicketChat
              key={active.id}
              id={active.id}
              asReporter
              allowPublic={active.state !== 'resolved'}
              messages={active.messages.map((msg) => ({ ...msg, label: t(msg.mine ? 'ui_chat_you' : 'ui_chat_staff') }))}
            />
          </div>
        </div>
      )}
      {state.reportOpen && <ReportDialog onClose={() => dispatch({ type: 'report', open: false })} />}
    </main>
  );
}
