# Panel (NUI)

> Versión documentada: **0.2.0**. Lo marcado como **(próximamente)** está planeado pero todavía no está implementado.

El panel se abre con `/staffsuite` o la tecla `F6` (`Config.PanelKey`) y se cierra con `Esc`. Está hecho en React 18 + TypeScript + Vite (código en `ui/`) y el resource carga la versión compilada de `ui/dist/`.

## Compilar el panel

`ui/dist/` no está en el repo. Si instalás desde el código fuente (no desde un paquete de release), compilalo una vez con Node.js 18 o superior:

```bash
cd ui && npm ci && npm run build
```

Genera `ui/dist/index.html` y `ui/dist/assets/*`, que es lo que lista `fxmanifest.lua`. Para el server solo hace falta `ui/dist/`; `ui/src` y `ui/node_modules` no se usan en runtime.

## Qué ve cada uno

El server solo manda los datos que permiten las capabilities del jugador (ver [Rangos y permisos](permisos.md)) y el panel oculta las vistas sin permiso. Si la vista actual no está permitida, salta a la primera que sí lo esté.

| Vista | Capability | Qué muestra |
|---|---|---|
| Auditoría | `audit.view` | Timeline de entradas con filtros y detalle (actor, acción, target, razón, hash). Botón "Verificar cadena" con `audit.verify`. Si la cadena está rota, marca la primera entrada que no coincide y las siguientes como no verificadas. |
| Reportes | `report.view` | Cola de tickets, chat del ticket, notas internas y panel de moderación. |
| Mis reportes | ninguna | Tus reportes abiertos y sus conversaciones públicas con el staff. |
| Dashboard | `staff.analytics` | KPIs (abiertos, resueltos, tiempo de respuesta, staff en servicio), leaderboard y alertas, como la de cadena de auditoría rota. |
| Servicio | `staff.duty` | Botón para entrar o salir de servicio (equivale a `/duty`), tus horas y sesiones, y el estado del equipo. |
| Ajustes | ninguna | Idioma del panel (ES/EN), tecla para abrirlo, estado del export (webhook, archivo, ancla cada N entradas), versión, tu rango y la persistencia. |

Creá reportes con `/report`. En Mis reportes podés leer y responder el hilo público de cada reporte abierto. Recibís una notificación cuando el staff responde. El chat público está disponible en Core y Lite.

## Reportes

| Acción en el panel | Capability | Estados en los que aparece |
|---|---|---|
| Reclamar | `report.claim` | abierto, reabierto |
| Transferir a otro staff conectado | `report.resolve` | reclamado |
| Resolver (con texto de resolución) | `report.resolve` | reclamado, en curso |
| Cerrar | `report.resolve` | cualquiera menos cerrado |
| Reabrir | `report.resolve` | resuelto, cerrado |
| Mensaje público | `report.message` | abierto, reclamado, en curso, reabierto |
| Nota interna (Core) | `report.message` | cualquiera menos cerrado |

La lista de destinatarios de transferencia la manda el server: staff conectado que puede reclamar reportes. Liberar un ticket y pasarlo a "en curso" no tienen botón todavía **(próximamente)**; se pueden hacer con el export `TicketAction`.

## Moderación

El panel de moderación del ticket actúa sobre quien hizo el reporte. Congelar y Descongelar comparten `mod.freeze`. Los otros botones necesitan `mod.<acción>`. Con `Config.Moderation.require_reason = true`, kick pide una razón.

- Ban y warn siempre piden una razón. El ban puede ser temporal o permanente y el warn se notifica al jugador en el juego.
- Spectate requiere que el objetivo esté en la misma instancia. Usá Retroceso para salir.
- Revive usa la integración médica del framework si está disponible, con una implementación standalone para los demás casos.

## Idioma

El idioma inicial es `Config.Locale`. Desde Ajustes cada jugador lo cambia solo para su panel; no se guarda entre sesiones. Los textos salen de `locales/es.lua` y `locales/en.lua` (claves `ui_*`), así que se pueden editar sin recompilar.

## Desarrollo

`cd ui && npm run dev` levanta el panel en el navegador con datos de prueba y un backend simulado. Ver `ui/README.md`.
