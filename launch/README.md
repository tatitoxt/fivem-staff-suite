# launch/ — Materiales de lanzamiento (BUILD_PLAN #23–25)

Todo listo para copiar y pegar. Lo publica Fausto con sus cuentas (modelo A de `plan/DISTRIBUTION.md` §8).

| Archivo | Para qué | Dónde se publica |
|---|---|---|
| `tebex-listing.md` | Título, tagline, descripción de Core, comparativa Lite/Core, FAQ de compra, spec de imágenes. Pro como borrador | Tebex (paquete Core) |
| `tebex-descripcion-es.txt` / `tebex-description-en.txt` | Descripción corta del paquete en texto plano | Campo de descripción del paquete en Tebex (se pega a mano) |
| `forum-post-en.md` | Post de Releases: Lite gratis + Core (formato oficial + tabla obligatoria) | forum.cfx.re → FiveM Releases |
| `forum-post-es.md` | Mismo post en español | Bloque `[details]` del post EN, Discords ES/LATAM, README del GitHub de Lite |
| `video-script.md` | Showcase 60–90 s ES y EN, escena por escena | YouTube (ES y EN por separado) + embed en Tebex/foro |
| `clips.md` | 10 hooks + guion corto | TikTok / Shorts / Reels |
| `creator-outreach.md` | Criterios, plantilla de DM ES/EN, propuesta de creator code | DM / mail a creadores |
| `x-devlog.md` | Hilo devlog + 5 posts sueltos | X (@https_tatito) |

## Placeholders
Reemplazar antes de publicar: `{{TEBEX_URL}}`, `{{GITHUB_URL}}`, `{{DISCORD_URL}}`, `{{YOUTUBE_ES}}`, `{{YOUTUBE_EN}}`, `{{DOCS_URL}}`, `{{PRECIO_CORE}}`, `{{PRECIO_PRO}}`, `{{POLITICA_REEMBOLSO}}` / `{{REFUND_POLICY}}`, `{{STUDIO}}` (pendiente en `plan/DECISIONS.md`; `fxmanifest.lua` dice "Orkelya Studio").

**`[RESMON PENDIENTE]`** queda visible a propósito en el foro, el video y las capturas: el resmon de **cliente** todavía no está medido (`docs/es/qa.md` → "resmon en cliente"). Se mide entrando al server, `resmon 1` con el panel cerrado y abierto. Hasta entonces no se publica el topic de Releases (las reglas piden números de rendimiento).

## Regla de honestidad: matriz de claims (verificada contra `main` el 19/11/2026, con moderación, captura, SQL, tickets F2, ediciones, auditoría de seguridad y E2E en FXServer ya mergeados)
Cada feature mencionada en estos materiales sale de esta tabla. Lo que no esté en ✅ no se vende como disponible.

### Free Lite (MIT, GitHub/foro)
| Feature | Estado | Código |
|---|---|---|
| `/report <categoría> <descripción>`, máximo 3 reportes abiertos por jugador | ✅ | `server/lite.lua`, `editions/lite/config.lua` (`Limits`) |
| Cola de tickets en el panel (F6, `/reports`): reclamar (sin doble reclamo), resolver con texto, cerrar, reabrir | ✅ | `server/lite.lua` (`actions`), `TicketsView.tsx` con `isLite` |
| Cadena SHA-256 de lo que pasa por el panel, visor con filtros y "Verificar cadena" (`/audit` o consola) | ✅ | `core/audit_chain.lua`, `AuditView.tsx` |
| Standalone, un solo permiso ACE (`staff_suite.lite`), JSON, ES/EN | ✅ | `editions/lite/` |
| Rate limit y límites de texto | ✅ | `core/ratelimit.lua`, `tests/test_lite.lua` |
| Mis reportes: el jugador ve sus reportes abiertos y responde el hilo público; el staff contesta desde la cola y al jugador le llega un aviso | ✅ | `server/lite.lua` (`staff_suite:ticketReply`), `MyReportsView.tsx` |
| Licencia MIT, Lua editable | ✅ | `editions/lite/LICENSE` |
| Lite **no** tiene: transferir, prioridades, notas internas, moderación, duty, dashboard, anclaje a Discord/archivo, frameworks, oxmysql, exports | — | `editions/lite/fxmanifest.lua` (no carga `server/main.lua` ni `export.lua`) |

### Core (Tebex + Cfx Asset Escrow)
| Feature | Estado | Código |
|---|---|---|
| Todo Lite + ciclo completo: reclamar, liberar, transferir (a staff conectado que puede reclamar), en curso, resolver, cerrar, reabrir | ✅ | `core/tickets.lua`, `server/main.lua` (`transferTargets`) |
| Prioridades y notas internas (solo las ve el staff) | ✅ | `Config.Priorities`, `staff_suite:ticketMessage` |
| Chat con el jugador en Mis reportes: hilo público por reporte abierto, sin notas internas ni identificadores del staff; aviso en el juego cuando responde el staff | ✅ | `tickets.reporter_view`, `staff_suite:ticketReply`, `TicketChat.tsx` |
| Respuestas predefinidas (4 por defecto, configurables) | ✅ | `Config.CannedResponses`, `TicketsView.tsx` |
| Calificación 1–5 del jugador al resolverse su ticket | ✅ | `afterTransition` → `ratePrompt`, `staff_suite:ticketRate`, `RatePrompt` |
| Evidencia: captura de pantalla del jugador con screenshot-basic; SHA-256 en la cadena y se verifica al abrirla | ✅ (si `screenshot-basic` está iniciado) | `staff_suite:ticketEvidence` / `evidenceGet` |
| Analytics por staff: resueltos, tiempo de primera respuesta, rating promedio, horas, sesiones, leaderboard | ✅ | `duty.record_resolved` / `record_rating`, `DashboardView.tsx`, `DutyView.tsx` |
| Moderación desde el ticket: goto, bring, freeze, unfreeze, heal, kick, warn, ban, spectate, revive | ✅ | `server/main.lua` (`modActions`), `client/moderation.lua` |
| Ban temporal o permanente, por license + license2/fivem/steam/discord/xbl/live (+ tokens de hardware), se extiende a cuentas nuevas que compartan un identificador; sin IP | ✅ | `ban`, `playerConnecting`, `bridges.ban_identifiers` |
| Warn notificado en el juego; ban y warn con razón obligatoria; kick con razón (configurable) | ✅ | `modActions` |
| Spectate en la misma instancia; revive con el sistema médico del framework o standalone | ✅ | `bridges.revive`, `client/moderation.lua` |
| Jerarquía: no se puede traer, congelar, expulsar, advertir ni banear a un rango superior | ✅ | `perms.outranks` |
| Unfreeze con el mismo permiso que freeze (`mod.freeze`); el panel muestra quién está congelado | ✅ | `modActions.unfreeze`, `frozenPlayers` |
| Duty (`/duty` o botón), dashboard, alerta de cadena rota | ✅ | `core/duty.lua`, vistas |
| 5 rangos, 20 capabilities, overrides; ESX/QBCore/Qbox (auto) o ACE; nadie es staff por defecto | ✅ | `core/permissions.lua`, `server/bridges/` |
| Captura de eventos: ESX (job, grupo, items, dinero), QBCore/Qbox (job, dinero, grupos) y txAdmin (ban, kick, warn, heal) | ✅ | `server/capture.lua` |
| Anclaje off-box cada N entradas (20) a `audit_export.log` + webhook (`set staff_suite_webhook`, solo server) | ✅ | `server/export.lua` |
| JSON u oxmysql con migraciones automáticas al iniciar, transacciones y respaldo JSON; importa el JSON de Lite | ✅ | `server/persist_sql.lua`, `sql/001_*.sql`, `sql/002_*.sql` |
| Exports: `Record`, `Verify`, `GetChain`, `CreateTicket`, `TicketAction`, `GetState`, `SetDuty`, `Flush`, `GetPersistence` (devuelven `false, código` en error) | ✅ | `server/main.lua` |
| Rate limit por jugador y evento, límites de texto en bytes, 3 tickets abiertos por jugador | ✅ | `Config.RateLimit`, `Config.Limits` |
| Export de tickets a Discord, modo demo | ⏳ próximamente | roadmap F2 |

### Calidad y rendimiento
| Dato | Valor | Fuente |
|---|---|---|
| Tests unitarios | 83 Lua + 18 de la NUI | `lua5.4 tests/run_all.lua`, `cd ui && npm test` |
| E2E en FXServer real | Core 30/30 · Lite 29/29 | `scripts/e2e-fxserver.sh` (dato de la corrida informada por el equipo) |
| Costo por llamada (server) | `Record` 0.09 ms · `GetState` 0.30 ms | métricas del E2E; no es costo por tick: el server no tiene loops por tick |
| resmon de cliente | **[RESMON PENDIENTE]** | medir a mano |
| Líneas | Core ~2.400 Lua sin tests ni locales + panel React · Lite ~700 Lua + panel | recontar al empaquetar |

### Integrity Pro
Nada en código. Copy en `tebex-listing.md` como **borrador: no publicar**.

## Checklist antes de publicar
1. Medir el resmon de cliente y reemplazar cada `[RESMON PENDIENTE]`.
2. Probar Core en un server real con ESX, QBCore y Qbox (bridges, captura y revive). Si un framework falla, sacarlo de los títulos hasta arreglarlo.
3. Subir Core a portal.cfx.re con escrow (#22) y crear el paquete en Tebex.
4. Repo público de Lite en GitHub (el foro pide que un release gratis se pueda bajar al instante).
5. Grabar capturas y video in-game en el server QA, sin datos demo del navegador.
6. No listar Pro hasta que exista una feature Pro real.
7. Pasar los textos por la voz de Fausto: las reglas del foro piden no pegar tal cual la salida de un LLM.

## Reglas externas verificadas (19/11/2026)
- **forum.cfx.re Releases** ([Releases Rules and FAQ](https://forum.cfx.re/t/releases-rules-and-faq/240725)): un release cada 48 h, trust level 1, tags `free`/`paid` obligatorios y `escrow` si usa escrow. Los pagos solo por Tebex. Tabla "Code is accessible / Subscription-based / Lines / Requirements / Support" obligatoria al final si es pago o escrow. Hay que incluir datos de rendimiento (resmon/profiler). Se prefiere un video demo. No usar "Open source" en un release pago. Links permitidos: Discord, soporte, Tebex, YouTube/marketing, docs, GitHub (no X/TikTok). La primera imagen subida al foro es la preview. No pedir reviews en Discord. No hay categoría en español: el post principal va en inglés.
- **Tebex** ([Fees](https://docs.tebex.io/creators/pricing-overview/tebex-fees-and-billing-overview), [Creator Codes](https://docs.tebex.io/creators/tebex-control-panel/engagement/creator-codes), [Packages](https://docs.tebex.io/creators/tebex-control-panel/how-to-create-packages/how-to-create-a-package), [FiveM best practices](https://docs.tebex.io/creators/growth-and-success/fivem-best-practices-for-packages)): 15% de fee de plataforma en FiveM, PayPal 2.49% + $0.40. Creator code: +1% de fee, revenue share máximo 50%, en suscripciones solo aplica al primer pago, liquidación a 30 días hábiles. Imagen del paquete: PNG de 165 px de alto como máximo (depende del template). Se pueden sumar videos de YouTube al carrusel. Video showcase recomendado: 30–90 s.
