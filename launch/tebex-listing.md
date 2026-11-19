# Tebex listing — Staff Integrity Suite Core

> Fuente de verdad de features: matriz de claims en `launch/README.md`.
> En Tebex va **solo Core** (pago único). Lite es gratis y se distribuye por GitHub y el foro (MIT). Pro es borrador: no publicar.
> Descripción corta para pegar a mano en el paquete: `tebex-descripcion-es.txt` y `tebex-description-en.txt`.
> Precios según D010: Core $29–39 pago único (intro sugerido $29, ROADMAP F3) · Pro $8–12/mes por server.

## Nombre y tagline
- **Nombre del paquete:** Staff Integrity Suite Core
- **Título largo (SEO Tebex/Google):**
  - ES: `Staff Integrity Suite Core — Reportes, moderación y auditoría verificable del staff [Standalone / ESX / QBCore / Qbox]`
  - EN: `Staff Integrity Suite Core — Reports, moderation & verifiable staff audit log [Standalone / ESX / QBCore / Qbox]`
- **Tagline:**
  - ES: **"El staff suite que audita a tu staff."**
  - EN: **"The staff suite that audits your staff."**
- No usar "el único" ni "nadie más lo hace" (`plan/PRODUCTO1_SPEC.md` §2 y §9: Agency-Admin tiene logs parecidos).

---

## Descripción larga de Core

### ES
**Staff Integrity Suite Core**

Todo el trabajo de tu staff en un solo recurso: reportes, moderación desde el ticket, turnos y una auditoría que se puede verificar. Se usa junto a txAdmin, no lo reemplaza.

Cada acción queda en una cadena SHA-256. Cada entrada incluye el hash de la anterior. Si alguien edita, borra o reordena una entrada, la verificación te dice en qué número se rompió. Cada 20 entradas (configurable) el hash actual se copia a un webhook de Discord y a un archivo aparte, así que reescribir todo tampoco pasa desapercibido.

**Tickets**
- `/report` o el panel (F6). Reclamar sin pisarse, liberar, transferir a otro staff conectado, resolver con texto, cerrar y reabrir.
- Prioridades, mensajes entre el staff, notas internas y respuestas predefinidas que configurás en `config.lua`.
- Al resolverse el ticket, el jugador califica la atención de 1 a 5.
- Evidencia con screenshot-basic: se captura la pantalla del jugador, el hash va a la cadena y al abrir la captura el panel te dice si coincide.

**Moderación desde el ticket**
- Goto, bring, freeze, heal, kick, warn, ban, spectate y revive, cada una con su permiso.
- Ban temporal o permanente. Cubre license, license2, FiveM, Steam, Discord, Xbox y tokens de hardware. Si el baneado vuelve con una cuenta nueva que comparte alguno, el ban se extiende. No usa IP.
- Ban y warn siempre piden razón; kick también (configurable). El warn le llega al jugador en el juego.
- Nadie puede traer, congelar, expulsar, advertir ni banear a alguien de rango superior.
- Revive usa el sistema médico de tu framework si está, o uno standalone.

**Turnos y estadísticas**
- `/duty` o el botón del panel, con horas y sesiones por staff.
- Dashboard: tickets abiertos y resueltos, quién está en servicio, ranking del equipo con resueltos, tiempo de primera respuesta y calificación promedio. Alerta si la cadena se rompe.

**Auditoría**
- Visor con filtros por staff, acción y fecha; detalle con hash y hash anterior. La entrada alterada se marca en rojo y las siguientes como "sin garantía".
- Verificación con el botón del panel, `/audit` o la consola. La verificación también queda registrada.
- Registro de eventos de ESX (job, grupo, items, dinero), QBCore y Qbox (job, dinero, grupos) y txAdmin (ban, kick, warn, heal).
- `exports.staff_suite:Record(...)` para que tus otros scripts escriban en la misma cadena.

**Instalación y seguridad**
- Standalone (ACE), ESX, QBCore o Qbox, detectados solos. Nadie es staff hasta que configures los rangos: 5 rangos y 20 permisos, con excepciones por persona.
- JSON sin base de datos, u oxmysql con migraciones automáticas al iniciar, transacciones y respaldo JSON. Si venís de Lite, importa tus tickets y tu cadena.
- Límite de acciones por jugador, límite de texto y 3 reportes abiertos por jugador.
- Español e inglés. `config.lua`, locales y `sql/` quedan abiertos; el resto con Cfx Asset Escrow.
- Probado en un FXServer real: 30 de 30 checks E2E. Rendimiento en el cliente: **[RESMON PENDIENTE]**.

**Lo que no hace:** no es un anticheat ni un menú de admin (noclip, god y spawn siguen en txAdmin). El jugador no ve el chat del ticket: los mensajes son entre el staff. No hay unfreeze todavía.

**Requisitos:** FXServer actualizado con OneSync. Opcional: oxmysql, ESX Legacy, QBCore o Qbox, screenshot-basic (para evidencia).

### EN
**Staff Integrity Suite Core**

Your staff's whole workflow in one resource: reports, moderation from the ticket, duty tracking and an audit log you can verify. It runs alongside txAdmin, not instead of it.

Every action goes into a SHA-256 chain. Each entry contains the hash of the previous one. If someone edits, deletes or reorders an entry, verification tells you which one broke. Every 20 entries (configurable) the current hash is copied to a Discord webhook and a separate file, so rewriting everything doesn't go unnoticed either.

**Tickets**
- `/report` or the panel (F6). Claim without stepping on each other, unclaim, transfer to another online staff member, resolve with a note, close and reopen.
- Priorities, staff messages, internal notes and canned replies you set up in `config.lua`.
- When the ticket is resolved, the player rates the help from 1 to 5.
- Evidence with screenshot-basic: the player's screen is captured, its hash goes into the chain, and when you open it the panel tells you whether it still matches.

**Moderation from the ticket**
- Goto, bring, freeze, heal, kick, warn, ban, spectate and revive, each behind its own permission.
- Temporary or permanent bans. They cover license, license2, FiveM, Steam, Discord, Xbox and hardware tokens. If the banned player comes back on a new account that shares any of them, the ban extends to it. No IP bans.
- Bans and warnings always need a reason; kicks too (configurable). Warnings are shown to the player in-game.
- Nobody can bring, freeze, kick, warn or ban someone with a higher rank.
- Revive uses your framework's medical system when there is one, or a standalone fallback.

**Duty and stats**
- `/duty` or the panel button, with hours and sessions per staff member.
- Dashboard: open and resolved tickets, who's on duty, team leaderboard with resolved tickets, first-response time and average rating. Alert if the chain breaks.

**Audit log**
- Viewer with filters by staff member, action and date; details with hash and previous hash. The altered entry turns red and everything after it is flagged "not guaranteed".
- Verify from the panel button, `/audit` or the server console. The verification itself is logged.
- Logs ESX events (job, group, items, money), QBCore and Qbox events (job, money, groups) and txAdmin events (ban, kick, warn, heal).
- `exports.staff_suite:Record(...)` lets your other scripts write to the same chain.

**Setup and security**
- Standalone (ACE), ESX, QBCore or Qbox, detected automatically. Nobody is staff until you set up ranks: 5 ranks and 20 permissions, with per-person overrides.
- JSON with no database, or oxmysql with automatic migrations on start, transactions and a JSON backup. Coming from Lite, it imports your tickets and chain.
- Per-player rate limits, text length limits and up to 3 open reports per player.
- Spanish and English. `config.lua`, locales and `sql/` stay open; the rest uses Cfx Asset Escrow.
- Tested on a real FXServer: 30 of 30 E2E checks. Client performance: **[RESMON PENDIENTE]**.

**What it doesn't do:** it isn't an anticheat or an admin menu (noclip, god mode and spawning stay in txAdmin). Players don't see the ticket chat: messages are between staff. There's no unfreeze yet.

**Requirements:** up-to-date FXServer with OneSync. Optional: oxmysql, ESX Legacy, QBCore or Qbox, screenshot-basic (for evidence).

---

## Comparativa Lite / Core (tabla para la descripción y el foro)
| | Lite (gratis, MIT) | Core ({{PRECIO_CORE}} pago único) |
|---|---|---|
| `/report` y cola de tickets en el panel | ✅ | ✅ |
| Reclamar, resolver, cerrar, reabrir | ✅ | ✅ |
| Transferir, liberar, prioridades, notas internas | — | ✅ |
| Respuestas predefinidas, calificación 1–5, evidencia con screenshot-basic | — | ✅ |
| Auditoría SHA-256 con visor y verificación | ✅ (acciones del panel) | ✅ (todo, más eventos de framework y txAdmin) |
| Anclaje del hash a Discord y archivo | — | ✅ |
| Moderación: goto, bring, freeze, heal, kick, warn, ban, spectate, revive | — | ✅ |
| Turnos, dashboard y estadísticas por staff | — | ✅ |
| Permisos | 1 permiso ACE | 5 rangos, 20 permisos, ESX/QBCore/Qbox/ACE |
| Persistencia | JSON | JSON u oxmysql con migraciones |
| Exports para otros scripts | — | ✅ |
| Código | Abierto (MIT) | Config, locales y SQL abiertos; resto con escrow |

EN:
| | Lite (free, MIT) | Core ({{PRECIO_CORE}} one-time) |
|---|---|---|
| `/report` and ticket queue in the panel | ✅ | ✅ |
| Claim, resolve, close, reopen | ✅ | ✅ |
| Transfer, unclaim, priorities, internal notes | — | ✅ |
| Canned replies, 1–5 rating, screenshot-basic evidence | — | ✅ |
| SHA-256 audit log with viewer and verification | ✅ (panel actions) | ✅ (everything, plus framework and txAdmin events) |
| Hash anchor to Discord and file | — | ✅ |
| Moderation: goto, bring, freeze, heal, kick, warn, ban, spectate, revive | — | ✅ |
| Duty, dashboard and per-staff stats | — | ✅ |
| Permissions | 1 ACE permission | 5 ranks, 20 permissions, ESX/QBCore/Qbox/ACE |
| Storage | JSON | JSON or oxmysql with migrations |
| Exports for other scripts | — | ✅ |
| Code | Open (MIT) | Config, locales and SQL open; the rest escrowed |

## Bullets cortos (header de la tienda / cards)
| ES | EN |
|---|---|
| Auditoría SHA-256 verificable | Verifiable SHA-256 audit log |
| Detecta entradas editadas, borradas o reordenadas | Detects edited, deleted or reordered entries |
| Ancla del hash en Discord + archivo | Hash anchor in Discord + file |
| Moderación completa desde el ticket | Full moderation from the ticket |
| Bans por todas las cuentas del jugador | Bans across all of a player's accounts |
| Evidencia con screenshot-basic | screenshot-basic evidence |
| Estadísticas por staff y calificación del jugador | Per-staff stats and player ratings |
| Standalone, ESX, QBCore o Qbox | Standalone, ESX, QBCore or Qbox |
| Español e inglés | Spanish and English |

---

## FAQ de compra
**ES**
- **¿Reemplaza a txAdmin?** No. txAdmin sigue para noclip, god, spawn y su panel web. Core cubre el flujo del staff y además registra los bans, kicks y warns que se hagan desde txAdmin.
- **¿Qué significa "verificable"?** Cada entrada guarda el hash SHA-256 de la anterior. La verificación recalcula la cadena entera: si se editó, borró o reordenó algo, te dice en qué entrada. Con el ancla en Discord también detectás si se borró el final o se reescribió todo.
- **¿Impide que un admin abuse?** No del todo. Nadie puede sancionar a un rango superior y todo queda registrado, pero no es un anticheat.
- **¿Captura todo lo que pasa en mi server?** Lo que pasa por Staff Suite, los eventos compatibles de ESX, QBCore, Qbox y txAdmin, y lo que tus scripts manden por `Record`. Lo que otros recursos hagan sin emitir esos eventos no se ve.
- **¿Necesito base de datos?** No. JSON por defecto; con oxmysql las tablas se crean solas.
- **¿Funciona con ESX / QBCore / Qbox?** Sí, los detecta solo. Sin framework, los rangos van por ACE.
- **¿Quién tiene permisos apenas lo instalo?** Nadie, hasta que mapees los rangos.
- **¿Vengo de Lite, pierdo algo?** No. Core conserva los tickets y la cadena de Lite.
- **¿Cómo lo recibo?** En tu cuenta de cfx.re (portal.cfx.re → Granted Assets) apenas pagás.
- **¿Puedo editar el código?** `config.lua`, `server/config.lua`, locales y `sql/` sí. El resto va con escrow.
- **¿Pago por cada staff?** No. Pago único por server.
- **¿Hay updates?** Sí, de por vida para Core.
- **¿Reembolsos?** {{POLITICA_REEMBOLSO}} (recomendación: probar Lite antes de comprar).
- **¿Soporte?** En español y en inglés por {{DISCORD_URL}}.

**EN**
- **Does it replace txAdmin?** No. txAdmin stays for noclip, god mode, spawning and its web panel. Core covers the staff workflow and also logs bans, kicks and warnings issued from txAdmin.
- **What does "verifiable" mean?** Each entry stores the SHA-256 hash of the previous one. Verification recomputes the whole chain: if anything was edited, deleted or reordered, it tells you which entry. With the Discord anchor you can also catch a deleted tail or a full rewrite.
- **Does it stop admin abuse?** Not entirely. Nobody can sanction a higher rank and everything is logged, but it isn't an anticheat.
- **Does it capture everything on my server?** What goes through Staff Suite, supported ESX, QBCore, Qbox and txAdmin events, and whatever your scripts send through `Record`. Other resources that don't emit those events aren't visible.
- **Do I need a database?** No. JSON by default; with oxmysql the tables are created automatically.
- **ESX / QBCore / Qbox?** Yes, detected automatically. Without a framework, ranks come from ACE.
- **Who has permissions right after install?** Nobody, until you map ranks.
- **Coming from Lite, do I lose anything?** No. Core keeps Lite's tickets and chain.
- **How do I get it?** In your cfx.re account (portal.cfx.re → Granted Assets) right after payment.
- **Can I edit it?** `config.lua`, `server/config.lua`, locales and `sql/`, yes. The rest is escrowed.
- **Do I pay per staff member?** No. One-time payment per server.
- **Updates?** Yes, lifetime updates for Core.
- **Refunds?** {{REFUND_POLICY}} (recommendation: try Lite before buying).
- **Support?** Spanish and English via {{DISCORD_URL}}.

---

## Edición Integrity Pro — {{PRECIO_PRO}}/mes por server (BORRADOR: no publicar todavía)

> Ninguna feature Pro existe en código hoy (matriz en `launch/README.md`). Publicar este paquete recién cuando haya al menos una feature Pro real, y listar solo esas. No se menciona en Tebex ni en el foro hasta entonces.

### ES
**Staff Integrity Suite — Integrity Pro**

Para el dueño que quiere saber, sin tener que preguntar, quién tiene qué permisos y qué hizo con ellos.

- Inventario de permisos cruzado: ACE, txAdmin, grupos del framework y Discord. Encuentra permisos huérfanos, cuentas compartidas y escaladas.
- Permisos con vencimiento y offboarding cuando alguien deja el staff.
- Alertas de anomalías: permisos dados fuera de patrón, bans sin razón o repetidos sobre los mismos jugadores, uso de noclip/god fuera de servicio.
- Case files: reporte + acciones del staff + evidencia en un timeline exportable.
- Apelaciones, con aviso cuando se repite un patrón contra el mismo staff.
- Dashboard del dueño y resumen semanal por Discord.
- Updates continuos y soporte prioritario.

Precio por server, no por staff: si tu equipo crece, no pagás más. Si la suscripción vence, el resource deja de arrancar (así funciona el escrow por suscripción de Cfx).

### EN
**Staff Integrity Suite — Integrity Pro**

For owners who want to know, without asking, who holds which permissions and what they did with them.

- Cross-system permission inventory: ACE, txAdmin, framework groups and Discord. Finds orphaned permissions, shared accounts and escalations.
- Expiring permissions and offboarding when someone leaves the team.
- Anomaly flags: out-of-pattern grants, bans without a reason or repeated against the same players, noclip/god used while off duty.
- Case files: report + staff actions + evidence in one exportable timeline.
- Appeals, with a warning when a pattern repeats against the same staff member.
- Owner dashboard and weekly Discord summary.
- Ongoing updates and priority support.

Priced per server, not per staff member: your team can grow without paying more. If the subscription lapses, the resource stops starting (this is how Cfx subscription escrow works).

---

## Especificación de imágenes

Tebex: la imagen del paquete se muestra según el template; la guía de Tebex pide **PNG de ≤165 px de alto** para la imagen del paquete, y permite videos de YouTube en un carrusel junto a las imágenes ([doc](https://docs.tebex.io/creators/tebex-control-panel/how-to-create-packages/how-to-create-a-package)). Tebex recomienda un template consistente (Figma), título visible, colores con contraste y no sacar capturas de noche.

Estilo: el del panel (BUILD_PLAN: fondo claro, Manrope 800 para títulos, DM Sans para el cuerpo, verde #16A34A = íntegro, naranja #F58220 = acento, rojo #E5484D = cadena rota). Sin gradientes violetas ni emojis. Todas las capturas son reales: panel corriendo in-game en un server de QA con datos de prueba (no el modo demo de `npm run dev`), sin nombres reales de jugadores.

| # | Archivo | Tamaño | Contenido | Uso |
|---|---|---|---|---|
| 1 | `pkg-lite.png` | 330×165 (≤165 px de alto, 2:1) | Logo + "LITE · GRATIS" / "LITE · FREE" | README de GitHub y post del foro de Lite |
| 2 | `pkg-core.png` | 330×165 | Logo + "CORE" + candado verde | Imagen del paquete Core |
| 3 | `pkg-pro.png` | 330×165 | Logo + "INTEGRITY PRO" | Imagen del paquete Pro (cuando se publique) |
| 4 | `banner-store.png` | 1920×480 | Tagline + captura del visor con el badge "Cadena íntegra" | Header de la tienda (template) |
| 5 | `cover-1280x720.png` | 1280×720 (16:9) | Pantalla partida: a la izquierda, cadena verde "íntegra"; a la derecha, la misma cadena con una entrada en rojo "rota en #12". Texto: "¿Alguien borró un log?" | Miniatura de YouTube + primera imagen del post del foro (preview) |
| 6 | `shot-audit.png` | 1920×1080 | Visor de auditoría: timeline con seq, acción, actor → target, razón, hash truncado | Carrusel Tebex + foro |
| 7 | `shot-broken.png` | 1920×1080 | Resultado de verificar con una entrada manipulada a mano, resaltada en rojo | Carrusel + foro (la imagen más importante) |
| 8 | `shot-ticket.png` | 1920×1080 | Ticket abierto: estado, reclamado por, hilo con una nota interna, botones de moderación con la razón escrita. Mostrar el diálogo de ban con duración y razón | Carrusel + foro |
| 8b | `shot-dashboard.png` | 1920×1080 | Dashboard con tickets abiertos/resueltos, staff en servicio y la tabla del equipo. Con datos de prueba que tengan tickets resueltos y calificados | Carrusel |
| 8c | `shot-evidence.png` | 1920×1080 | Captura de evidencia abierta en el ticket con la marca de verificada | Carrusel |
| 9 | `shot-discord.png` | 1280×720 | Mensaje del webhook "Ancla de auditoría · seq N · hash" (EN: "Audit anchor · seq N · hash") en un canal de Discord | Carrusel + foro |
| 10 | `shot-console.png` | 1280×720 | Consola del server: `[StaffSuite] auditoría OK: N entradas` y después `auditoría ROTA en la entrada N` (o en inglés: `audit OK: N entries` / `audit BROKEN at entry N`) | Foro (prueba técnica) |
| 11 | `shot-resmon.png` | recorte real | resmon con `staff_suite`: **[RESMON PENDIENTE]** | Foro (exigido por las reglas) |
| 12 | `gif-verify.gif` | 600×338, ≤5 MB | Loop de 5–8 s: clic en "Verificar cadena" → verde; editar → rojo | Post del foro (como hacen los releases top) |

Para las imágenes 5, 7 y 12: frenar el resource, editar a mano una entrada en `staff_suite_data.json`, volver a iniciar y tocar "Verificar cadena" en el panel. La 10 sale de la consola con `/audit`.
