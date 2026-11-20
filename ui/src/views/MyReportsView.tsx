import { Inbox } from 'lucide-react';
import { useState } from 'react';
import lay from '../components/layout.module.css';
import { Badge, Empty, ViewHeader, cx, ui } from '../components/ui';
import { categoryLabel, stateLabel, stateTone } from '../labels';
import { useApp } from '../store';
import { TicketChat } from './TicketChat';
import v from './views.module.css';

export function MyReportsView() {
  const { state, t } = useApp();
  const [selected, setSelected] = useState<number | null>(null);
  const tickets = state.myTickets;
  const active = tickets.find((ticket) => ticket.id === selected) ?? tickets[0];

  return (
    <main className={lay.main}>
      <ViewHeader title={t('ui_my_reports')} />
      {!active ? <Empty icon={<Inbox size={22} />}>{t('ui_my_reports_empty')}</Empty> : (
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
              <div className={v.detailTitle}><h2>#{active.id} · {categoryLabel(t, active.category)}</h2></div>
              <div className={v.desc}>{active.description}</div>
            </section>
            <TicketChat
              key={active.id}
              id={active.id}
              asReporter
              messages={active.messages.map((msg) => ({ ...msg, label: t(msg.mine ? 'ui_chat_you' : 'ui_chat_staff') }))}
            />
          </div>
        </div>
      )}
    </main>
  );
}
