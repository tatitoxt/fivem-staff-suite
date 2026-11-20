import { afterEach, describe, expect, it } from 'vitest';
import { applyTheme, brandAccent, contrast, resolveTheme } from '../theme';

afterEach(() => {
  document.documentElement.removeAttribute('data-theme');
  document.documentElement.removeAttribute('style');
});

describe('theme', () => {
  it('computes WCAG contrast', () => {
    expect(contrast('#000000', '#ffffff')).toBeCloseTo(21, 0);
    expect(contrast('#15803d', '#ffffff')).toBeGreaterThan(4.5);
    expect(contrast('nope', '#ffffff')).toBe(0);
  });

  it('keeps the default green accent at AA in both themes', () => {
    expect(contrast('#15803d', '#ffffff')).toBeGreaterThanOrEqual(4.5);
    expect(contrast('#4ade80', '#161a21')).toBeGreaterThanOrEqual(4.5);
    expect(contrast('#4ade80', '#0b1f12')).toBeGreaterThanOrEqual(4.5);
  });

  it('accepts a brand accent only when it passes AA for text and buttons', () => {
    expect(brandAccent('#1d4ed8', 'light')?.['--on-accent']).toBe('#ffffff');
    expect(brandAccent('#facc15', 'light')).toBeNull();
    expect(brandAccent('#facc15', 'dark')?.['--on-accent']).toBe('#0b1f12');
    expect(brandAccent('#1d4ed8', 'dark')).toBeNull();
    expect(brandAccent('red', 'light')).toBeNull();
  });

  it('applies the theme and a valid brand accent, and ignores an invalid one', () => {
    const root = document.documentElement;
    expect(applyTheme('dark')).toBe(true);
    expect(root.dataset.theme).toBe('dark');
    expect(applyTheme('light', '#1d4ed8')).toBe(true);
    expect(root.style.getPropertyValue('--accent')).toBe('#1d4ed8');
    expect(applyTheme('light', '#facc15')).toBe(false);
    expect(root.style.getPropertyValue('--accent')).toBe('');
  });

  it('resolves auto from the system preference', () => {
    expect(resolveTheme('dark')).toBe('dark');
    expect(['light', 'dark']).toContain(resolveTheme('auto'));
  });
});
