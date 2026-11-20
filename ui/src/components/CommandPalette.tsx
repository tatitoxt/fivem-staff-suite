import { ArrowRight, CornerDownLeft, Languages, MapPin, MessageSquare, MessageSquarePlus, Power, RefreshCw, Search, ShieldBan, ShieldCheck, X } from 'lucide-react';
import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { isLite } from '../edition';
import { useApp } from '../store';
import { useNav } from './Sidebar';
import s from './layout.module.css';
import { cx, ui } from './ui';

interface Cmd { id: string; group: string; label: string; icon: ReactNode; hint?: string; run: () => void }

const norm = (x: string) => x.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

export function useCommands(): Cmd[] {
  const { state, dispatch, t, can, send } = useApp();
  const nav = useNav();
  const caps = state.player?.capabilities;
  return useMemo(() => {
    const go = t('ui_cmd_views');
    const act = t('ui_cmd_actions');
    const other = (state.config.locales?.length ? state.config.locales : ['es', 'en']).find((l) => l !== state.locale);
    const list: Cmd[] = nav.map((n, i) => ({
      id: `view:${n.id}`, group: go, label: n.label, icon: n.icon, hint: String(i + 1),
      run: () => dispatch({ type: 'view', view: n.id }),
    }));
    list.push({ id: 'report', group: act, label: t('ui_report_new'), icon: <MessageSquarePlus size={16} />, hint: 'N', run: () => dispatch({ type: 'report', open: true }) });
    if (!isLite && can('staff.duty')) {
      list.push({ id: 'duty', group: act, label: state.duty?.self.on_duty ? t('ui_duty_stop') : t('ui_duty_start'), icon: <Power size={16} />, run: () => void send('duty_toggle') });
    }
    if (can('audit.verify')) {
      list.push({ id: 'verify', group: act, label: t('audit_verify'), icon: <ShieldCheck size={16} />, run: () => { dispatch({ type: 'view', view: 'audit' }); dispatch({ type: 'checking' }); void send('audit_verify'); } });
    }
    if (!isLite && caps?.includes('ban.view')) {
      list.push({ id: 'bans', group: act, label: t('ban_review_title'), icon: <ShieldBan size={16} />, run: () => dispatch({ type: 'staffDialog', dialog: 'ban.view' }) });
    }
    if (!isLite && caps?.includes('staff.chat')) {
      list.push({ id: 'staff-chat', group: act, label: t('ui_staff_chat'), icon: <MessageSquare size={16} />, run: () => dispatch({ type: 'staffDialog', dialog: 'staff.chat' }) });
    }
    if (!isLite && can('staff.waypoint')) {
      list.push({ id: 'waypoint', group: act, label: t('ui_waypoint_go'), icon: <MapPin size={16} />, run: () => void send('goto_waypoint') });
    }
    if (!isLite && can('mod.spectate')) {
      list.push({ id: 'spectate-stop', group: act, label: t('spectate_stop'), icon: <X size={16} />,
        run: () => void send('spectate_stop') });
    }
    if (other) list.push({ id: 'lang', group: act, label: t('ui_cmd_lang', { lang: t(`ui_lang_${other}`) }), icon: <Languages size={16} />, run: () => void send('set_locale', { locale: other }) });
    list.push({ id: 'refresh', group: act, label: t('ui_cmd_refresh'), icon: <RefreshCw size={16} />, run: () => void send('refresh') });
    list.push({ id: 'close', group: act, label: t('ui_cmd_close'), icon: <X size={16} />, hint: 'Esc', run: () => void send('close_ui') });
    return list;
  }, [nav, state.config.locales, state.locale, state.duty, dispatch, t, can, caps, send]);
}

export function CommandPalette() {
  const { dispatch, t } = useApp();
  const cmds = useCommands();
  const [q, setQ] = useState('');
  const [i, setI] = useState(0);
  const input = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLUListElement>(null);
  const items = useMemo(() => {
    const n = norm(q.trim());
    return n ? cmds.filter((c) => norm(c.label).includes(n)) : cmds;
  }, [cmds, q]);
  const close = () => dispatch({ type: 'palette', open: false });
  const run = (c: Cmd | undefined) => { if (!c) return; close(); c.run(); };

  useEffect(() => {
    const opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    input.current?.focus();
    return () => { if (opener?.isConnected) opener.focus(); };
  }, []);
  useEffect(() => setI(0), [q]);
  useEffect(() => {
    listRef.current?.querySelector<HTMLElement>(`[data-i="${i}"]`)?.scrollIntoView({ block: 'nearest' });
  }, [i]);

  const onKey = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); setI((x) => (x + 1) % Math.max(items.length, 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setI((x) => (x - 1 + items.length) % Math.max(items.length, 1)); }
    else if (e.key === 'Enter') { e.preventDefault(); run(items[i]); }
    else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); e.nativeEvent.stopImmediatePropagation(); close(); }
    else if (e.key === 'Tab') e.preventDefault();
  };

  let lastGroup = '';
  return (
    <div className={cx(s.overlay, s.paletteLayer)} onMouseDown={(e) => e.target === e.currentTarget && close()}>
      <div className={s.palette} role="dialog" aria-modal="true" aria-label={t('ui_cmd_title')} onKeyDown={onKey}>
        <div className={s.paletteSearch}>
          <Search size={16} />
          <input
            ref={input}
            className={s.paletteInput}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder={t('ui_cmd_placeholder')}
            aria-label={t('ui_cmd_placeholder')}
            role="combobox"
            aria-expanded="true"
            aria-controls="cmd-list"
            aria-activedescendant={items[i] ? `cmd-${items[i].id}` : undefined}
          />
          <span className={ui.kbd}>Esc</span>
        </div>
        {items.length ? (
          <ul id="cmd-list" ref={listRef} className={s.paletteList} role="listbox" aria-label={t('ui_cmd_title')}>
            {items.map((c, n) => {
              const head = c.group !== lastGroup ? c.group : null;
              lastGroup = c.group;
              return [
                head && <li key={`g-${head}`} className={s.paletteGroup} role="presentation">{head}</li>,
                <li
                  key={c.id}
                  id={`cmd-${c.id}`}
                  data-i={n}
                  role="option"
                  aria-selected={n === i}
                  className={cx(s.paletteItem, n === i && s.paletteOn)}
                  onMouseMove={() => setI(n)}
                  onClick={() => run(c)}
                >
                  {c.icon}
                  <span>{c.label}</span>
                  {c.hint ? <span className={ui.kbd}>{c.hint}</span> : <ArrowRight size={14} />}
                </li>,
              ];
            })}
          </ul>
        ) : <div className={s.paletteEmpty}>{t('ui_cmd_empty')}</div>}
        <div className={s.paletteFoot}>
          <span><span className={ui.kbd}>↑</span><span className={ui.kbd}>↓</span>{t('ui_cmd_navigate')}</span>
          <span><span className={ui.kbd}><CornerDownLeft size={12} /></span>{t('ui_cmd_run')}</span>
        </div>
      </div>
    </div>
  );
}
