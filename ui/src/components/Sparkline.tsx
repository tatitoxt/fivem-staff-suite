// Sparkline SVG sin dependencias: una línea con área suave y el último punto marcado.
export function Sparkline({ values, width = 88, height = 28, tone = 'var(--accent)', label }: {
  values: number[]; width?: number; height?: number; tone?: string; label?: string;
}) {
  if (values.length < 2) return null;
  const max = Math.max(...values, 1);
  const min = Math.min(...values, 0);
  const span = max - min || 1;
  const step = width / (values.length - 1);
  const pts = values.map((v, i) => [i * step, height - 3 - ((v - min) / span) * (height - 6)] as const);
  const line = pts.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`).join('');
  const [lx, ly] = pts[pts.length - 1];
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} role={label ? 'img' : undefined} aria-label={label} aria-hidden={label ? undefined : true}>
      <path d={`${line}L${width},${height}L0,${height}Z`} fill={tone} opacity={0.08} />
      <path d={line} fill="none" stroke={tone} strokeWidth={1.5} strokeLinejoin="round" strokeLinecap="round" />
      <circle cx={lx} cy={ly} r={2.5} fill={tone} />
    </svg>
  );
}

// Serie de n días terminando hoy: cuenta los timestamps que caen en cada día.
export function dailySeries(timestamps: number[], days = 7, now = Date.now() / 1000): number[] {
  const end = Math.floor(now / 86400) * 86400 + 86400;
  const out = new Array<number>(days).fill(0);
  for (const ts of timestamps) {
    const i = days - 1 - Math.floor((end - 1 - ts) / 86400);
    if (i >= 0 && i < days) out[i] += 1;
  }
  return out;
}
