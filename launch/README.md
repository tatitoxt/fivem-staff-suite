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

## Regla de honestidad: matriz de claims (verificada contra el código de `main` al 19/11/2026)
Cada feature mencionada en estos materiales sale de esta tabla. **Antes de publicar, re-verificar las filas 🔨/⏳** y pasar a ✅ solo lo que ya esté mergeado y probado. Lo que siga sin estar, queda como "próximamente" (sin fecha, `DISTRIBUTION.md` §10).

| Feature | Estado | Dónde está en el código | Depende de |
|---|---|---|---|
| Audit log con hash-chain SHA-256 (cada entrada encadena el hash de la anterior) | ✅ | `core/audit_chain.lua`, `core/sha256.lua` (vectores NIST) | — |
| Detecta entradas editadas, borradas o reordenadas | ✅ | `audit_chain.verify` + `tests/test_audit_chain.lua` | — |
| Detecta truncado del final comparando con un head anclado afuera | ✅ (core) | `audit_chain.verify_head` | verificación desde el ancla en UI: #14 |
| Verificar la cadena a demanda (`/audit` en consola o in-game; la verificación misma queda registrada) | ✅ | `server/main.lua` (`/audit`, evento `staff_suite:verify`) | — |
| Anclaje off-box cada N entradas (default 20) a archivo `audit_export.log` + webhook de Discord | ✅ | `server/export.lua`, `Config.Export` | — |
| `/report <categoría> <descripción>` crea ticket | ✅ | `server/main.lua` | — |
| Ciclo de ticket: reclamar, liberar, transferir, en curso, resolver, cerrar, reabrir; doble reclamo bloqueado; cada paso queda en la cadena | ✅ (server) | `core/tickets.lua`, evento `staff_suite:ticketAction` | botones en panel: #15 |
| Moderación desde el ticket: goto, bring, freeze, heal, kick; razón obligatoria en kick/warn/ban; queda en la cadena | ✅ (server) | `server/main.lua` (`modActions`, `doMod`) | botones en panel: #15 |
| Moderación: ban, warn, spectate, revive | ⏳ próximamente | capabilities en `core/permissions.lua`, sin acción implementada | #9/#12 |
| `/duty` on/off con duración del turno, registrado en la cadena | ✅ | `core/duty.lua`, `server/main.lua` | — |
| 5 rangos (helper → owner) + 20 capabilities + overrides por persona | ✅ (core) | `core/permissions.lua` | — |
| Rangos tomados del framework / bridges ESX, QBCore, Qbox | 🔨 | `server/bridges/*.lua` existen pero no se cargan; hoy todos reciben `Config.StandaloneRank` | **#12 (bloqueante para vender Core)** |
| Chat del ticket + notas internas | 🔨 core listo | `tickets.add_message` (no conectado al server) | #9/#15 |
| Calificación 1–5 del jugador | 🔨 core listo | `tickets.rate` (no conectado) | #9/#15 |
| Prioridades de ticket | 🔨 | campo + `Config.Priorities`; `/report` siempre crea "normal" | #15 |
| Analytics: tickets resueltos, tiempo de respuesta, rating promedio, leaderboard | 🔨 core listo | `duty.snapshot`; `record_resolved`/`record_rating` no se llaman todavía | #16 |
| Panel NUI (F6 / `/staffsuite`): tickets, auditoría, equipo | 🔨 | `client/main.lua` listo; UI solo en `ui/prototype/` (falta `ui/dist/`) | #13–16 |
| Captura best-effort de comandos `ban`, `kick`, `warn`, `giveitem`, `givemoney`, `setjob` | ✅ (best-effort) | `server/main.lua` (`Config.Audit.capture_commands`) | validar en QA #19 |
| Captura de eventos de framework / txAdmin | ⏳ próximamente | `server/capture.lua` no se carga | #9 |
| API para otros resources (`exports.staff_suite:Record`, `Verify`, `GetChain`, `CreateTicket`, `TicketAction`, `GetState`) | ✅ | `server/main.lua` | — |
| Persistencia JSON sin base de datos u oxmysql opcional; guardado cada 60 s y al apagar | ✅ | `server/persist.lua` | — |
| Español e inglés, config y locales editables | ✅ | `locales/`, `config.lua` | completar #17 |
| Tests: 27 unitarios + E2E server-side | ✅ | `tests/` | — |
| Rendimiento (resmon) | ⏳ sin medir | objetivo <0.05 ms idle (`plan/ARCHITECTURE.md`) | **#19 (el foro exige números)** |
| Escrow (core cerrado, config/locales/NUI abiertos) | ⏳ | — | #22 |
| Separación Lite vs Core en el paquete | ⏳ | hoy es un solo resource | #22 |
| Respuestas predefinidas, evidencia con screenshot-basic, export de tickets a Discord, modo demo | ⏳ próximamente (Core) | — | roadmap F2 |
| Integrity Pro: inventario de permisos cross-system, permisos con vencimiento, flags de anomalías, case files, apelaciones, dashboard del dueño + resumen semanal | ⏳ próximamente (Pro) | nada en código | roadmap F4 |

## Checklist antes de publicar
1. Actualizar la matriz de arriba con lo mergeado (#9–#19) y ajustar cada archivo: lo que pase a ✅ deja de decir "próximamente".
2. **No vender Core hasta que #12 esté hecho**: hoy todos los jugadores son `owner` en standalone, o sea que el "least-privilege" todavía no aplica en el adapter.
3. No listar el paquete Pro hasta que exista al menos una feature Pro real. El copy de Pro está listo como borrador.
4. Medir resmon (#19) y completar `{{RESMON_*}}`: las reglas de Releases piden números de rendimiento.
5. Grabar capturas y video recién con el panel final (#13–16). Nada de mockups presentados como producto.
6. GitHub público para el Lite (el foro exige que un release gratis esté disponible al instante: repo público, upload al foro o paquete gratis en Tebex).
7. Pasar los textos por la voz de Fausto: las reglas del foro piden no pegar tal cual la salida de un LLM.

## Reglas externas verificadas (19/11/2026)
- **forum.cfx.re Releases** ([Releases Rules and FAQ](https://forum.cfx.re/t/releases-rules-and-faq/240725)): un release cada 48 h, trust level 1, tags `free`/`paid` obligatorios y `escrow` si usa escrow. Los pagos solo por Tebex. Tabla "Code is accessible / Subscription-based / Lines / Requirements / Support" obligatoria al final si es pago o escrow. Hay que incluir datos de rendimiento (resmon/profiler). Se prefiere un video demo. No usar "Open source" en un release pago. Links permitidos: Discord, soporte, Tebex, YouTube/marketing, docs, GitHub (no X/TikTok). La primera imagen subida al foro es la preview. No pedir reviews en Discord. No hay categoría en español: el post principal va en inglés.
- **Tebex** ([Fees](https://docs.tebex.io/creators/pricing-overview/tebex-fees-and-billing-overview), [Creator Codes](https://docs.tebex.io/creators/tebex-control-panel/engagement/creator-codes), [Packages](https://docs.tebex.io/creators/tebex-control-panel/how-to-create-packages/how-to-create-a-package), [FiveM best practices](https://docs.tebex.io/creators/growth-and-success/fivem-best-practices-for-packages)): 15% de fee de plataforma en FiveM, PayPal 2.49% + $0.40. Creator code: +1% de fee, revenue share máximo 50%, en suscripciones solo aplica al primer pago, liquidación a 30 días hábiles. Imagen del paquete: PNG de 165 px de alto como máximo (depende del template). Se pueden sumar videos de YouTube al carrusel. Video showcase recomendado: 30–90 s.
