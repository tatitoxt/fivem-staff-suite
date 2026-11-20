# NUI — sistema de diseño (rediseño anti-slop)

Lectura del brief: panel de staff in-game para servidores RP. Es una herramienta de trabajo que se usa durante horas: tiene que ser densa, legible y calma, al estilo de un SaaS de operaciones (Linear, Attio), no de una landing page.

## Referencias

| Referencia | Qué tomamos | Qué no tomamos |
|---|---|---|
| Marcel Kargul, dashboard ([post](https://x.com/marcelkargul/status/2088626741363314967)) | KPIs chicos con icono y delta en una línea, barra de filtros fina, sidebar de 32 px por ítem | Cards de colección repetidas |
| Kargul Studio, Sales CRM ([repo](https://github.com/kargulstudio/sales-crm)) | Tabla densa con filas de unos 36 px, mini sparklines por fila, contadores en la nav, curvas de easing power2/power3 | Tema oscuro y acento violeta |
| Proceso de Kargul ([post](https://x.com/marcelkargul/status/2106802573114065103)) | Diseñar, construir y después pulir a mano los detalles: alineación, estados y medidas | — |
| shadcn + Base UI dashboard ([repo](https://github.com/shadcndashboard/shadcndashboard)) | KPIs en una sola tira dividida por hairlines, en lugar de cards sueltas | Base UI como dependencia: nuestros primitivos ya son accesibles y ocupan menos de 2 KB |
| Amicro ([sitio](https://amicro.vercel.app/)) | Microinteracciones: press de 0.98, aparición de overlays de 160 ms | Motion/Framer, porque sumaría unos 40 KB gzip |
| design-taste ([repo](https://github.com/madebymustafa/design-taste)) | Never-list y checklist final: un acento, profundidad con estructura y no con sombras, no anidar cards | — |

## Decisiones

- **Paleta:** neutros fríos y un solo acento de marca, verde `#15803d` (integridad, "todo en orden"). Rojo y ámbar solo como semántica (cadena rota, alertas, prioridad). Sin gradientes.
- **Tipografía:** Manrope 700 en títulos (vista 20 px, sección 15 px, KPI 22 px con `tabular-nums`) y DM Sans en el cuerpo (14 px, meta 13 px). Mínimo 13 px. Esta escala reemplaza el cuerpo ≥16 px de BUILD_PLAN para ganar densidad.
- **Espaciado:** escala de 4/8 (`--s1` 4 px, `--s2` 8, `--s3` 12, `--s4` 16, `--s5` 24, `--s6` 32).
- **Formas:** radio 14 px en el panel, 10 px en cards, 8 px en controles y 6 px en badges. Pills solo en contadores.
- **Profundidad:** hairlines de 1 px; las sombras quedan solo para lo que flota (panel, diálogos, palette, toasts).
- **Movimiento:** 120 ms para hover y press, 160 ms para que aparezcan overlays, `cubic-bezier(0.33, 1, 0.68, 1)`. Nada supera 200 ms y con `prefers-reduced-motion` se desactiva.
- **Dashboard:** una tira de 5 KPIs con delta y sparkline de 7 días, actividad de tickets en barras de 7 días, ranking en una tabla densa y alertas como lista.
- **Teclado:** `Ctrl+K` abre la command palette con acciones de staff (ir a una vista, servicio, verificar la cadena, nuevo reporte, idioma). `1`–`6` cambia de vista, `N` abre un reporte nuevo y `Esc` cierra.
- **Jugador:** el reporte rápido se hace en un modal con categorías en tiles, descripción con contador y la opción de adjuntar una captura (solo si screenshot-basic está activo). "Mis reportes" muestra el estado como progreso: Enviado → En curso → Resuelto.
- **Bundle:** sin librerías nuevas. Iconos de lucide (tree-shaken) y gráficos en SVG propio.
