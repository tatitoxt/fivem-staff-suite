import { Info, Keyboard, Languages, MapPin, Megaphone, MessageSquare, Send, ShieldBan } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { Badge, Button, Segmented, ViewHeader, cx, ui } from '../components/ui';
import lay from '../components/layout.module.css';
import { isLite } from '../edition';
import { rankLabel } from '../labels';
import { useApp } from '../store';
import type { TicketCreateResult } from '../types';
import { LimitHint, overLimit } from './TicketChat';
import v from './views.module.css';

function AnnouncementForm() {
  const { state, t, send } = useApp();
  const [body, setBody] = useState('');
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<TicketCreateResult>();
  const max = state.config.limits?.announcement ?? 300;
  const disabled = sending || !body.trim() || overLimit(body, max);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (disabled) return;
    setSending(true);
    setResult(undefined);
    const response = await send('announce', { body: body.trim() }) as TicketCreateResult | null;
    setSending(false);
    setResult(response ?? { ok: false });
    if (response?.ok) setBody('');
  }

  return (
    <form className={cx(ui.card, v.setCard)} onSubmit={submit} aria-labelledby="announcement-heading">
      <div className={v.setHead}><span className={v.setIcon}><Megaphone size={20} /></span><h2 id="announcement-heading">{t('announcement_title')}</h2></div>
      <textarea className={ui.input} aria-label={t('announcement_title')} value={body} disabled={sending}
        onChange={(event) => { setBody(event.target.value); setResult(undefined); }} />
      <LimitHint text={body} max={max} />
      <Button type="submit" variant="primary" disabled={disabled}>{t('ui_announcement_send')}</Button>
      {result?.ok && <p className={v.setHint} role="status">{t('announcement_sent')}</p>}
      {result && !result.ok && <p className={v.setHint} role="alert">{result.error ?? t('announcement_failed')}</p>}
    </form>
  );
}

export function SettingsView() {
  const { state, dispatch, t, send, can } = useApp();
  const cfg = state.config;
  const locales = cfg.locales?.length ? cfg.locales : ['es', 'en'];
  const exp = cfg.export;
  const canViewBans = !isLite && state.player?.capabilities?.includes('ban.view');
  const canChat = !isLite && state.player?.capabilities?.includes('staff.chat');
  const canWaypoint = !isLite && can('staff.waypoint');
  return (
    <main className={lay.main}>
      <ViewHeader title={t('ui_nav_settings')} subtitle={t('ui_settings_sub')} />
      <div className={cx(lay.viewBody, ui.scroll)}>
        <div className={v.settings}>
          {(canViewBans || canChat || canWaypoint) && <div className={v.settingsTools}>
            {canViewBans && <Button size="small" onClick={() => dispatch({ type: 'staffDialog', dialog: 'ban.view' })}>
              <ShieldBan size={15} aria-hidden />{t('ban_review_title')}
            </Button>}
            {canChat && <Button size="small" onClick={() => dispatch({ type: 'staffDialog', dialog: 'staff.chat' })}>
              <MessageSquare size={15} aria-hidden />{t('ui_staff_chat')}
            </Button>}
            {canWaypoint && <Button size="small" onClick={() => void send('goto_waypoint')}>
              <MapPin size={15} aria-hidden />{t('ui_waypoint_go')}
            </Button>}
          </div>}
          {!isLite && state.player?.capabilities?.includes('staff.announce') && <AnnouncementForm />}
          <section className={cx(ui.card, v.setCard)}>
            <div className={v.setHead}><span className={v.setIcon}><Languages size={15} /></span><h2>{t('ui_set_language')}</h2></div>
            <Segmented
              label={t('ui_set_language')}
              value={state.locale}
              options={locales.map((l) => ({ value: l, label: t(`ui_lang_${l}`) }))}
              onChange={(locale) => void send('set_locale', { locale })}
            />
            <p className={v.setHint}>{t('ui_set_language_hint')}</p>
          </section>
          <section className={cx(ui.card, v.setCard)}>
            <div className={v.setHead}><span className={v.setIcon}><Keyboard size={15} /></span><h2>{t('ui_set_keybind')}</h2></div>
            <span className={v.kbd}>{cfg.panel_key ?? 'F6'}</span>
            <p className={v.setHint}>{t('ui_set_keybind_hint')}</p>
            <div className={v.shortcuts} aria-label={t('ui_shortcuts')} role="group">
              <span><span className={ui.kbd}>Ctrl</span><span className={ui.kbd}>K</span></span><span>{t('ui_cmd_title')}</span>
              <span><span className={ui.kbd}>1</span>–<span className={ui.kbd}>{isLite ? 4 : 6}</span></span><span>{t('ui_shortcut_views')}</span>
              <span><span className={ui.kbd}>N</span></span><span>{t('ui_report_new')}</span>
              <span><span className={ui.kbd}>Esc</span></span><span>{t('ui_cmd_close')}</span>
            </div>
          </section>
          {!isLite && <section className={cx(ui.card, v.setCard)}>
            <div className={v.setHead}><span className={v.setIcon}><Send size={15} /></span><h2>{t('ui_set_export')}</h2></div>
            <div className={v.rows}>
              <div className={v.row}>
                <span>{t('ui_export_discord')}</span>
                {!exp ? <Badge tone="gray" dot>{t('ui_export_unknown')}</Badge> : exp.webhook ? <Badge tone="green" dot>{t('ui_export_on')}</Badge> : <Badge tone="orange" dot>{t('ui_export_off')}</Badge>}
              </div>
              <div className={v.row}>
                <span>{t('ui_export_file')}</span>
                {!exp ? <Badge tone="gray" dot>{t('ui_export_unknown')}</Badge> : exp.file ? <Badge tone="green" dot>{t('ui_enabled')}</Badge> : <Badge tone="gray" dot>{t('ui_disabled')}</Badge>}
              </div>
              <div className={v.row}>
                <span>{t('ui_export_anchor')}</span>
                <strong>{exp?.anchor_every ? t('ui_export_anchor_every', { n: exp.anchor_every }) : '—'}</strong>
              </div>
            </div>
            <p className={v.setHint}>{t('ui_set_export_hint')}</p>
          </section>}
          <section className={cx(ui.card, v.setCard)}>
            <div className={v.setHead}><span className={v.setIcon}><Info size={15} /></span><h2>{t('ui_set_about')}</h2></div>
            <div className={v.rows}>
              <div className={v.row}><span>{t('ui_set_version')}</span><strong>v{state.version || '—'}</strong></div>
              {!isLite && <div className={v.row}><span>{t('ui_set_rank')}</span><strong>{state.player ? rankLabel(t, state.player.rank) : '—'}</strong></div>}
              <div className={v.row}><span>{t('ui_set_persistence')}</span><strong>{!isLite && cfg.persistence === 'oxmysql' ? 'MySQL (oxmysql)' : 'JSON'}</strong></div>
            </div>
          </section>
        </div>
      </div>
    </main>
  );
}
