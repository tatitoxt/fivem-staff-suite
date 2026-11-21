export function fmt(template: string, vars?: Record<string, string | number>): string {
  if (!vars) return template;
  return template.replace(/%\{(\w+)\}/g, (m, k: string) => (k in vars ? String(vars[k]) : m));
}

const INTL_LOCALES: Record<string, string> = {
  es: 'es-AR', en: 'en-US', pt: 'pt-BR', fr: 'fr-FR', de: 'de-DE',
};

export function intlLocale(locale: string): string {
  return INTL_LOCALES[locale] ?? 'en-US';
}

export function shortId(id: string | null | undefined): string {
  if (!id) return '';
  const m = /^(license2?|steam|discord|fivem|xbl|live):(.+)$/.exec(id);
  if (m) return `${m[1]}:${m[2].slice(0, 8)}`;
  return id;
}

export function shortHash(hash: string, head = 10, tail = 6): string {
  if (!hash || hash.length <= head + tail + 1) return hash ?? '';
  return `${hash.slice(0, head)}…${hash.slice(-tail)}`;
}

export function formatDateTime(ts: number, locale: string): string {
  return new Intl.DateTimeFormat(intlLocale(locale), {
    day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit',
  }).format(new Date(ts * 1000));
}

export function formatRelative(ts: number, locale: string, now = Date.now() / 1000): string {
  const rtf = new Intl.RelativeTimeFormat(intlLocale(locale), { numeric: 'auto', style: 'short' });
  const diff = Math.round(ts - now);
  const abs = Math.abs(diff);
  if (abs < 60) return rtf.format(diff, 'second');
  if (abs < 3600) return rtf.format(Math.round(diff / 60), 'minute');
  if (abs < 86400) return rtf.format(Math.round(diff / 3600), 'hour');
  return rtf.format(Math.round(diff / 86400), 'day');
}

export function formatDuration(seconds: number | null | undefined): string {
  if (seconds == null || !Number.isFinite(seconds)) return '—';
  const s = Math.max(0, Math.round(seconds));
  if (s < 60) return `${s} s`;
  if (s < 3600) {
    const m = Math.floor(s / 60);
    const r = s % 60;
    return r ? `${m} min ${r} s` : `${m} min`;
  }
  const h = Math.floor(s / 3600);
  const m = Math.round((s % 3600) / 60);
  return m ? `${h} h ${m} min` : `${h} h`;
}

export function formatNumber(n: number | null | undefined, locale: string, digits = 1): string {
  if (n == null || !Number.isFinite(n)) return '—';
  return new Intl.NumberFormat(intlLocale(locale), {
    minimumFractionDigits: digits, maximumFractionDigits: digits,
  }).format(n);
}

export function toDayStart(value: string): number | null {
  if (!value) return null;
  const [y, m, d] = value.split('-').map(Number);
  return new Date(y, m - 1, d).getTime() / 1000;
}
