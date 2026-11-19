# launch/ — Materiales de lanzamiento (BUILD_PLAN #23–25)

Todo listo para copiar y pegar. Lo publica Fausto con sus cuentas (modelo A de `plan/DISTRIBUTION.md` §8).

| Archivo | Para qué | Dónde se publica |
|---|---|---|
| `tebex-listing.md` | Título, tagline, descripciones ES/EN por edición, FAQ de compra, spec de imágenes | Tebex (paquetes Lite / Core / Pro) |
| `forum-post-en.md` | Post de Releases (formato oficial + tabla obligatoria) | forum.cfx.re → FiveM Releases |
| `forum-post-es.md` | Mismo post en español | Discords ES/LATAM, bloque `[details]` del post EN, GitHub README |
| `video-script.md` | Showcase 60–90 s ES y EN, escena por escena | YouTube (ES y EN por separado) + embed en Tebex/foro |
| `clips.md` | 10 hooks + guion corto | TikTok / Shorts / Reels |
| `creator-outreach.md` | Criterios, plantilla de DM ES/EN, propuesta de creator code | DM / mail a creadores |
| `x-devlog.md` | Hilo devlog + 5 posts sueltos | X (@https_tatito) |

## Placeholders
Reemplazar antes de publicar: `{{TEBEX_URL}}`, `{{GITHUB_URL}}`, `{{DISCORD_URL}}`, `{{YOUTUBE_ES}}`, `{{YOUTUBE_EN}}`, `{{DOCS_URL}}`, `{{PRECIO_CORE}}`, `{{PRECIO_PRO}}`, `{{CODIGO}}`, `{{STUDIO}}` (nombre del studio: pendiente en `plan/DECISIONS.md`; `fxmanifest.lua` dice "Orkelya Studio"), `{{RESMON_IDLE}}` / `{{RESMON_ACTIVO}}` (números reales de #19), `{{LINEAS}}`.

## Regla de honestidad: matriz de claims (verificada contra el código de `main` al 19/11/2026, después del merge de los PR #1, #4 y #5)
Cada feature mencionada en estos materiales sale de esta tabla. **Antes de publicar, re-verificar las filas 🔨/⏳** y pasar a ✅ solo lo que ya esté mergeado y probado. Lo que siga sin estar, queda como "próximamente" (sin fecha, `DISTRIBUTION.md` §10).

| Feature | Estado | Dónde está en el código | Depende de |
|---|---|---|---|
| Audit log con hash-chain SHA-256 (cada entrada encadena el hash de la anterior) | ✅ | `core/audit_chain.lua`, `core/sha256.lua` (vectores NIST) | — |
| Detecta entradas editadas, borradas o reordenadas | ✅ | `audit_chain.verify` + `tests/test_audit_chain.lua` | — |
| Detecta truncado del final comparando con un head anclado afuera | ✅ (core) | `audit_chain.verify_head` | el panel muestra el head actual pero no lo compara con el ancla: roadmap |
| Verificar la cadena a demanda (`/audit` en consola o in-game, o el botón "Verificar cadena" del panel; la verificación misma queda registrada) | ✅ | `server/main.lua` (`/audit`, evento `staff_suite:verify`), `ui/src/views/AuditView.tsx` | — |
| Anclaje off-box cada N entradas (default 20) a archivo `audit_export.log` + webhook de Discord. La URL va por convar en `server.cfg` (`set staff_suite_webhook`) y no llega a los clientes | ✅ | `server/export.lua`, `server/config.lua` (solo server) | — |
| `/report <categoría> <descripción>` crea ticket | ✅ | `server/main.lua` | — |
| Ciclo de ticket: reclamar, liberar, transferir, en curso, resolver, cerrar, reabrir; doble reclamo bloqueado; transferir solo a un staff conectado que pueda reclamar; cada paso queda en la cadena | ✅ | `core/tickets.lua`, evento `staff_suite:ticketAction`; panel: botones Reclamar / Transferir / Resolver (con texto de resolución) / Cerrar / Reabrir en `TicketsView.tsx`. El panel no tiene botón de liberar ni de "en curso" (solo server/API) | — |
| Transferir a un staff de una lista (solo staff conectado que puede ver y reclamar reportes; la ve quien tiene `report.resolve`) | ✅ | `server/main.lua` (`transferTargets`), diálogo en `TicketsView.tsx` | — |
| Moderación desde el ticket: goto, bring, freeze, heal, kick; razón obligatoria en kick (en el panel el botón Expulsar queda deshabilitado sin razón); target validado; queda en la cadena | ✅ | `server/main.lua` (`modActions`, `doMod`), botones en `TicketsView.tsx` | — |
| Moderación: ban, warn, spectate, revive | ⏳ próximamente | deshabilitadas: `getState` no expone `mod.*` sin acción en `modActions` y `doMod` responde `mod_unavailable`. Ojo al grabar: el panel muestra Advertir y Banear en gris | roadmap |
| `/duty` on/off con duración del turno, registrado en la cadena; también con el botón de la vista Servicio | ✅ | `core/duty.lua`, `server/main.lua`, `ui/src/views/DutyView.tsx` | — |
| 5 rangos (helper → owner) + 20 capabilities + overrides por persona | ✅ (core) | `core/permissions.lua` | — |
| Rangos tomados del framework: bridges ESX, QBCore, Qbox (auto-detección Qbox → QBCore → ESX → standalone, o `Config.Framework`); grupos/permisos/jobs vía `Config.RankMap` y `Config.JobRankMap` | ✅ | `server/bridges/init.lua`, `server/bridges/*.lua`, `tests/test_bridges.lua` (mocks) | validar en server real con cada framework: #19 |
| Sin staff por defecto: en standalone los rangos salen de ACE (`staff_suite.<rango>`) o de `Config.StandaloneRanks`; sin configurar, nadie tiene permisos | ✅ | `server/bridges/init.lua`, `server/bridges/standalone.lua`, `server/config.lua` | — |
| Mensajes del staff + notas internas en el ticket | ✅ | `tickets.add_message`, evento `staff_suite:ticketMessage` (requiere `report.message`); en el panel: hilo del ticket + interruptor "Nota interna" | — |
| Chat con el jugador (que el jugador vea y responda) | ⏳ próximamente | el estado de tickets solo se manda a quien tiene `report.view`; el panel es solo para staff | roadmap |
| Calificación 1–5 del jugador | 🔨 core listo | `tickets.rate` (no conectado); el panel muestra las estrellas si existe un rating | #9 |
| Prioridades de ticket | ✅ | `Config.Priorities`, evento `staff_suite:ticketCreate`; el panel tiene "Nuevo ticket" con categoría y prioridad, y filtra/ordena la cola por prioridad. `/report` sigue creando "normal" | — |
| Dashboard: tickets abiertos y resueltos, staff en servicio, tabla del equipo con horas de servicio y sesiones | ✅ | `ui/src/views/DashboardView.tsx`, `DutyView.tsx`; datos de `duty.snapshot` (requiere `staff.analytics`) | — |
| Analytics por staff: tickets resueltos, tiempo de respuesta, rating promedio (ranking por resueltos) | 🔨 core + vistas listas | las columnas existen en el panel, pero `record_resolved`/`record_rating` no se llaman: resueltos queda en 0 y tiempo/rating en "—" | #9/#16 |
| Alerta "cadena rota" en el dashboard (con botón para ir a la auditoría) | ✅ | `getState` → `alerts` (`audit_chain_broken`), `DashboardView.tsx` | — |
| Panel NUI (F6 / `/staffsuite`), React: Tickets, Auditoría, Dashboard, Servicio, Ajustes | ✅ | `ui/` (React 18 + Vite), puente `client/main.lua`. `ui/dist/` no se versiona: se genera con `npm run build` al empaquetar (`ui/README.md`) | probarlo in-game en el server QA: #19 |
| Visor de auditoría: timeline con seq, acción, actor → target, razón y hash; detalle con `hash`/`prev_hash`/payload; filtros por staff, acción y fechas; la entrada rota se marca "Alterada" y las siguientes "Sin garantía" | ✅ | `ui/src/views/AuditView.tsx` | — |
| Ajustes: idioma ES/EN, tecla del panel, estado del webhook y del archivo de export, versión, rango y persistencia | ✅ | `ui/src/views/SettingsView.tsx`. El intervalo de anclaje se ve como "—" porque `exportStatus` no lo manda | — |
| Captura best-effort de comandos `ban`, `kick`, `warn`, `giveitem`, `givemoney`, `setjob` | ✅ (best-effort) | `server/main.lua` (`Config.Audit.capture_commands`) | validar en QA #19 |
| Captura de eventos de framework / txAdmin | ⏳ próximamente | `server/capture.lua` no se carga; `Config.Audit.capture_framework` todavía no hace nada | #9 |
| API para otros resources (`exports.staff_suite:Record`, `Verify`, `GetChain`, `CreateTicket`, `TicketAction`, `GetState`) | ✅ | `server/main.lua` | — |
| Persistencia JSON sin base de datos u oxmysql opcional; guardado cada 60 s y al apagar | ✅ | `server/persist.lua` | — |
| Español e inglés, config y locales editables | ✅ | `locales/`, `config.lua` | completar #17 |
| Tests: 41 unitarios Lua (core + bridges) + E2E server-side; CI en GitHub Actions (Lua 5.4 + luacheck); 11 smoke tests del panel (vitest, se corren a mano, no están en CI) | ✅ | `tests/`, `.github/workflows/lua.yml`, `ui/src/test/` | — |
| Rendimiento (resmon) | ⏳ sin medir | objetivo <0.05 ms idle (`plan/ARCHITECTURE.md`) | **#19 (el foro exige números)** |
| Escrow (core cerrado, config/locales/NUI abiertos) | ⏳ | — | #22 (incluir `ui/dist/` en el zip) |
| Separación Lite vs Core en el paquete | ⏳ | hoy es un solo resource | #22 |
| Respuestas predefinidas, evidencia con screenshot-basic, export de tickets a Discord, modo demo | ⏳ próximamente (Core) | — | roadmap F2 |
| Integrity Pro: inventario de permisos cross-system, permisos con vencimiento, flags de anomalías, case files, apelaciones, dashboard del dueño + resumen semanal | ⏳ próximamente (Pro) | nada en código | roadmap F4 |

## Checklist antes de publicar
1. Actualizar la matriz de arriba con lo mergeado (#9, #17–#19) y ajustar cada archivo: lo que pase a ✅ deja de decir "próximamente".
2. Probar los bridges en un server real con ESX, QBCore y Qbox (#19). Hoy están probados con mocks; si alguno falla, sacarlo de los títulos hasta arreglarlo.
3. No listar el paquete Pro hasta que exista al menos una feature Pro real. El copy de Pro está listo como borrador.
4. Medir resmon (#19) y completar `{{RESMON_*}}`: las reglas de Releases piden números de rendimiento.
5. Grabar capturas y video con el panel corriendo in-game en el server QA (no con el harness del navegador ni los datos demo de `npm run dev`). Nada de mockups presentados como producto.
6. GitHub público para el Lite (el foro exige que un release gratis esté disponible al instante: repo público, upload al foro o paquete gratis en Tebex).
7. Pasar los textos por la voz de Fausto: las reglas del foro piden no pegar tal cual la salida de un LLM.

## Reglas externas verificadas (19/11/2026)
- **forum.cfx.re Releases** ([Releases Rules and FAQ](https://forum.cfx.re/t/releases-rules-and-faq/240725)): un release cada 48 h, trust level 1, tags `free`/`paid` obligatorios y `escrow` si usa escrow. Los pagos solo por Tebex. Tabla "Code is accessible / Subscription-based / Lines / Requirements / Support" obligatoria al final si es pago o escrow. Hay que incluir datos de rendimiento (resmon/profiler). Se prefiere un video demo. No usar "Open source" en un release pago. Links permitidos: Discord, soporte, Tebex, YouTube/marketing, docs, GitHub (no X/TikTok). La primera imagen subida al foro es la preview. No pedir reviews en Discord. No hay categoría en español: el post principal va en inglés.
- **Tebex** ([Fees](https://docs.tebex.io/creators/pricing-overview/tebex-fees-and-billing-overview), [Creator Codes](https://docs.tebex.io/creators/tebex-control-panel/engagement/creator-codes), [Packages](https://docs.tebex.io/creators/tebex-control-panel/how-to-create-packages/how-to-create-a-package), [FiveM best practices](https://docs.tebex.io/creators/growth-and-success/fivem-best-practices-for-packages)): 15% de fee de plataforma en FiveM, PayPal 2.49% + $0.40. Creator code: +1% de fee, revenue share máximo 50%, en suscripciones solo aplica al primer pago, liquidación a 30 días hábiles. Imagen del paquete: PNG de 165 px de alto como máximo (depende del template). Se pueden sumar videos de YouTube al carrusel. Video showcase recomendado: 30–90 s.
