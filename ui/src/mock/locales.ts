import esLua from '../../../locales/es.lua?raw';
import enLua from '../../../locales/en.lua?raw';

// Lee las tablas Locale['xx'] de locales/*.lua (fuente única de strings) para
// que el harness de dev muestre exactamente lo que enviaría el adapter.
export function parseLuaLocale(src: string): Record<string, string> {
  const out: Record<string, string> = {};
  const noComments = src.replace(/--[^\n]*/g, '');
  const re = /([A-Za-z_][A-Za-z0-9_]*)\s*=\s*'((?:[^'\\]|\\.)*)'/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(noComments))) {
    out[m[1]] = m[2].replace(/\\(.)/g, (_, c: string) => (c === 'n' ? '\n' : c));
  }
  return out;
}

export const LOCALES: Record<string, Record<string, string>> = {
  es: parseLuaLocale(esLua),
  en: parseLuaLocale(enLua),
};
