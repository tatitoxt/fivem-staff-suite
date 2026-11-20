export type ThemePref = 'light' | 'dark' | 'auto';
export type Theme = 'light' | 'dark';

const SURFACE: Record<Theme, string> = { light: '#ffffff', dark: '#161a21' };
const DARK_TEXT = '#0b1f12';

export function isThemePref(v: unknown): v is ThemePref {
  return v === 'light' || v === 'dark' || v === 'auto';
}

export function resolveTheme(pref: ThemePref): Theme {
  if (pref !== 'auto') return pref;
  return typeof window !== 'undefined' && window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function rgb(hex: string): [number, number, number] | null {
  const m = /^#([0-9a-f]{6})$/i.exec(hex.trim());
  if (!m) return null;
  const n = parseInt(m[1], 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function luminance([r, g, b]: [number, number, number]): number {
  const c = [r, g, b].map((x) => {
    const v = x / 255;
    return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
}

export function contrast(a: string, b: string): number {
  const x = rgb(a);
  const y = rgb(b);
  if (!x || !y) return 0;
  const [l1, l2] = [luminance(x), luminance(y)].sort((p, q) => q - p);
  return (l1 + 0.05) / (l2 + 0.05);
}

function mix(a: string, b: string, t: number): string {
  const x = rgb(a)!;
  const y = rgb(b)!;
  return '#' + x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join('');
}

// Un acento de marca se acepta si como texto sobre la superficie y como fondo de botón cumple AA (4.5:1).
export function brandAccent(hex: string | undefined, theme: Theme): Record<string, string> | null {
  if (!hex || !rgb(hex)) return null;
  const surface = SURFACE[theme];
  if (contrast(hex, surface) < 4.5) return null;
  const onAccent = contrast(hex, '#ffffff') >= 4.5 ? '#ffffff' : contrast(hex, DARK_TEXT) >= 4.5 ? DARK_TEXT : null;
  if (!onAccent) return null;
  return {
    '--accent': hex,
    '--accent-hover': mix(hex, theme === 'light' ? '#000000' : '#ffffff', 0.15),
    '--accent-soft': mix(surface, hex, theme === 'light' ? 0.1 : 0.16),
    '--accent-ink': theme === 'light' ? mix(hex, '#000000', 0.35) : mix(hex, '#ffffff', 0.35),
    '--on-accent': onAccent,
    '--focus-ring': hex + '33',
  };
}

const BRAND_VARS = ['--accent', '--accent-hover', '--accent-soft', '--accent-ink', '--on-accent', '--focus-ring'];

export function applyTheme(theme: Theme, accent?: string): boolean {
  const root = document.documentElement;
  root.dataset.theme = theme;
  for (const k of BRAND_VARS) root.style.removeProperty(k);
  const vars = brandAccent(accent, theme);
  if (vars) for (const [k, v] of Object.entries(vars)) root.style.setProperty(k, v);
  return !accent || vars != null;
}
