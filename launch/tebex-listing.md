# Tebex listing — Staff Integrity Suite

> Fuente de verdad de features: matriz de claims en `launch/README.md`. Lo marcado *próximamente* se borra o se pasa a feature real antes de publicar, según el estado de ese día.
> Precios según D010: Lite $0 · Core $29–39 one-time (intro sugerido $29, ROADMAP F3) · Pro $8–12/mes por server.

## Nombre y tagline
- **Nombre del paquete:** Staff Integrity Suite
- **Título largo (SEO Tebex/Google):**
  - ES: `Staff Integrity Suite — Reportes, moderación y auditoría verificable del staff [Standalone / ESX / QBCore / Qbox]`
  - EN: `Staff Integrity Suite — Reports, moderation & verifiable staff audit log [Standalone / ESX / QBCore / Qbox]`
  - Los bridges están probados con mocks (`tests/test_bridges.lua`). Confirmarlos en un server real con cada framework (#19) antes de publicar.
- **Tagline:**
  - ES: **"El staff suite que audita a tu staff."**
  - EN: **"The staff suite that audits your staff."**
- Tagline alternativa (más fuerte, usar solo con el calificador): ES "El único que combina tickets, moderación y una auditoría de staff que se puede verificar." / EN "The only one that combines tickets, moderation and a staff audit log you can actually verify." Antes de usarla, revisar Agency-Admin (`plan/PRODUCTO1_SPEC.md` §2 y §9: no afirmar "nadie lo hace").

---

## Edición Lite — $0

### ES
**Staff Integrity Suite Lite (gratis)**

Reportes de jugadores y un registro de lo que hace tu staff que no se puede editar sin que se note.

Cada acción que pasa por el sistema (un reporte, un reclamo, una moderación, un turno) queda en una cadena de auditoría con SHA-256. Cada entrada incluye el hash de la anterior. Si alguien edita, borra o reordena una entrada, la verificación te dice en qué número se rompió la cadena.

**Qué incluye**
- `/report <categoría> <descripción>`: el jugador crea un ticket. Las categorías se configuran.
- Ciclo completo del ticket: reclamar, liberar, transferir, resolver, cerrar y reabrir. Dos staff no pueden reclamar el mismo ticket.
- Audit log con hash-chain SHA-256 y verificación con `/audit`, desde la consola o in-game.
- Anclaje fuera del server: cada N entradas el hash se manda a un webhook de Discord y a un archivo de log. Si alguien reescribe todo, el ancla externa no coincide.
- `/duty` para entrar y salir de servicio, con la duración del turno registrada.
- Funciona sin base de datos (JSON). oxmysql es opcional.
- Español e inglés. `config.lua` y los locales se pueden editar.
- **Panel in-game (F6 o `/staffsuite`):** cola de tickets con filtros, visor de auditoría con filtros y botón "Verificar cadena", y vista de servicio. La entrada alterada se marca en rojo.

**Requisitos:** FXServer actualizado (Lua 5.4, `fx_version cerulean`). Standalone (rangos por ACE) o ESX, QBCore o Qbox: los detecta solo.

### EN
**Staff Integrity Suite Lite (free)**

Player reports plus a record of what your staff does that can't be edited without it showing.

Every action that goes through the system (a report, a claim, a moderation action, a duty shift) is written to a SHA-256 audit chain. Each entry contains the hash of the previous one. If someone edits, deletes or reorders an entry, verification tells you the exact entry where the chain broke.

**Includes**
- `/report <category> <description>`: players open a ticket. Categories are configurable.
- Full ticket lifecycle: claim, unclaim, transfer, resolve, close and reopen. Two staff members can't claim the same ticket.
- SHA-256 hash-chained audit log, verified with `/audit` from the console or in-game.
- Off-server anchoring: every N entries the hash goes to a Discord webhook and a log file. If someone rewrites everything, the external anchor won't match.
- `/duty` to go on and off duty, with shift length recorded.
- Works without a database (JSON). oxmysql is optional.
- Spanish and English. `config.lua` and locales are editable.
- **In-game panel (F6 or `/staffsuite`):** ticket queue with filters, audit viewer with filters and a "Verify chain" button, and a duty view. The altered entry is highlighted in red.

**Requirements:** up-to-date FXServer (Lua 5.4, `fx_version cerulean`). Standalone (ACE ranks) or ESX, QBCore or Qbox, detected automatically.

---

## Edición Core — {{PRECIO_CORE}} pago único

### ES
**Staff Integrity Suite Core**

Todo el flujo de trabajo de tu staff en un solo script: reportes, moderación desde el ticket, turnos y una auditoría que se puede verificar. Se usa junto a txAdmin, no lo reemplaza. Noclip, god y spawn los sigue haciendo txAdmin.

**Todo lo del Lite, más:**
- **Moderación desde el ticket:** goto, bring, freeze, heal y kick. El kick pide razón obligatoria. Cada acción queda en la cadena con quién, a quién, cuándo y por qué.
- **Permisos por rango:** 5 rangos (helper, moderator, admin, senior admin, owner) y 20 permisos individuales. Se pueden dar o sacar permisos a una persona puntual.
- **Rangos desde tu framework:** detecta Qbox, QBCore o ESX (o lo forzás con `Config.Framework`) y mapea grupos, permisos y jobs a los rangos (`Config.RankMap`, `Config.JobRankMap`). En standalone, por ACE (`staff_suite.<rango>`). Nadie tiene permisos de staff hasta que los configures.
- **Registro de comandos de admin:** `ban`, `kick`, `warn`, `giveitem`, `givemoney` y `setjob` quedan en la auditoría (best-effort, depende de cómo los registre tu server).
- **API para tus scripts:** `exports.staff_suite:Record(...)` agrega cualquier acción de otro resource a la misma cadena.
- **Persistencia en MySQL** vía oxmysql. Si no tenés, usa JSON.
- **Ticket completo en el panel:** mensajes del staff y notas internas, prioridades, transferir a un staff de la lista y resolver con texto de resolución.
- **Dashboard:** tickets abiertos y resueltos, quién está en servicio, horas y sesiones de cada staff, y alerta si la cadena se rompe.
- **Updates de por vida** de la edición Core.
- *Próximamente:* chat con el jugador, calificación del jugador (1–5), ban/warn/spectate/revive, respuestas predefinidas, evidencia con screenshot-basic, analytics del staff (tickets resueltos, tiempo de respuesta y rating por staff).

**Requisitos:** FXServer actualizado, OneSync (para goto/bring/freeze/heal), oxmysql opcional. Standalone, ESX, QBCore o Qbox.
**Escrow:** el core va protegido con el Asset Escrow de Cfx. `config.lua`, locales y la interfaz quedan abiertos para editar.

### EN
**Staff Integrity Suite Core**

Your staff's whole workflow in one script: reports, moderation from the ticket, duty tracking and an audit log you can verify. It runs next to txAdmin and doesn't replace it. Noclip, god mode and spawning stay in txAdmin.

**Everything in Lite, plus:**
- **Moderation from the ticket:** goto, bring, freeze, heal and kick. Kicks require a reason. Every action is written to the chain with who, to whom, when and why.
- **Rank permissions:** 5 ranks (helper, moderator, admin, senior admin, owner) and 20 individual permissions. You can grant or revoke permissions for a specific person.
- **Ranks from your framework:** detects Qbox, QBCore or ESX (or force it with `Config.Framework`) and maps groups, permissions and jobs to ranks (`Config.RankMap`, `Config.JobRankMap`). Standalone uses ACE (`staff_suite.<rank>`). Nobody gets staff permissions until you configure them.
- **Admin command logging:** `ban`, `kick`, `warn`, `giveitem`, `givemoney` and `setjob` are written to the audit log (best-effort, depends on how your server registers them).
- **API for your scripts:** `exports.staff_suite:Record(...)` adds any action from another resource to the same chain.
- **MySQL storage** via oxmysql. Without it, JSON is used.
- **Full ticket view in the panel:** staff messages and internal notes, priorities, transfer to a staff member from a list, and resolve with a resolution note.
- **Dashboard:** open and resolved tickets, who's on duty, hours and sessions per staff member, and an alert if the chain breaks.
- **Lifetime updates** for the Core edition.
- *Coming soon:* chat with the player, player rating (1–5), ban/warn/spectate/revive, canned responses, screenshot-basic evidence, staff analytics (resolved tickets, response time and rating per staff member).

**Requirements:** up-to-date FXServer, OneSync (for goto/bring/freeze/heal), oxmysql optional. Standalone, ESX, QBCore or Qbox.
**Escrow:** the core is protected with Cfx Asset Escrow. `config.lua`, locales and the UI stay open for editing.

---

## Edición Integrity Pro — {{PRECIO_PRO}}/mes por server (BORRADOR: no publicar todavía)

> Ninguna feature Pro existe en código hoy (matriz en `launch/README.md`). Publicar este paquete recién cuando haya al menos una feature Pro real, y listar solo esas. Mientras tanto, este texto sirve para la sección "Roadmap" del Core.

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

## Bullets cortos (para el header de la tienda / cards)
| ES | EN |
|---|---|
| Auditoría con hash-chain SHA-256 | SHA-256 hash-chained audit log |
| Detecta entradas editadas, borradas o reordenadas | Detects edited, deleted or reordered entries |
| Ancla externa en Discord + archivo | Off-server anchor in Discord + file |
| Panel in-game: tickets, auditoría, servicio | In-game panel: tickets, audit, duty |
| Tickets con reclamo y transferencia | Tickets with claim and transfer |
| Moderación desde el ticket, con razón | Moderation from the ticket, with a reason |
| Turnos de staff registrados | Staff duty shifts recorded |
| Standalone o ESX/QBCore/Qbox, sin DB obligatoria | Standalone or ESX/QBCore/Qbox, no database required |
| Español e inglés, config abierta | Spanish and English, open config |

## Comparativa por edición (tabla para la descripción)
| | Lite | Core | Pro |
|---|---|---|---|
| Tickets + ciclo completo | ✅ | ✅ | ✅ |
| Audit hash-chain + verificación + ancla externa | ✅ | ✅ | ✅ |
| Duty on/off | ✅ | ✅ | ✅ |
| Panel in-game (F6): cola de tickets + visor de auditoría | ✅ | ✅ | ✅ |
| Mensajes/notas internas, prioridades, dashboard de horas y servicio | — | ✅ | ✅ |
| Moderación desde el ticket | — | ✅ | ✅ |
| Permisos por rango + overrides | — | ✅ | ✅ |
| Rangos desde ESX / QBCore / Qbox | — | ✅ | ✅ |
| Registro de comandos de admin + API `Record` | — | ✅ | ✅ |
| Analytics por staff (resueltos, tiempo de respuesta, rating) | — | próximamente | próximamente |
| Inventario de permisos, flags, casos, apelaciones | — | — | próximamente |
| Precio | $0 | {{PRECIO_CORE}} único | {{PRECIO_PRO}}/mes |

> Qué entra en Lite y qué en Core todavía no está separado en el código (es un solo resource, #22). Ajustar esta tabla al empaquetar.

---

## FAQ de compra
**ES**
- **¿Reemplaza a txAdmin?** No. txAdmin sigue para noclip, god, spawn y el panel web. Esto cubre el flujo del staff (tickets, moderación con razón, turnos) y registra lo que pasa en una cadena verificable.
- **¿Qué significa "verificable"?** Cada entrada guarda el hash SHA-256 de la anterior. `/audit` recalcula la cadena entera: si se editó, borró o reordenó algo, te dice en qué entrada se rompió. Con el ancla en Discord también podés detectar si se borró el final.
- **¿Impide que un admin haga abuso?** No. Lo que hace es que quede registrado y que borrarlo se note. No es un anticheat.
- **¿Captura todo lo que pasa en mi server?** No. Registra lo que pasa por el sistema, los comandos de admin listados y lo que otros scripts manden por `exports.staff_suite:Record`. Lo que otros resources hacen por su cuenta, sin pasar por ahí, no siempre se puede interceptar desde el server.
- **¿Necesito base de datos?** No. Usa JSON por defecto; oxmysql es opcional.
- **¿Funciona con ESX / QBCore / Qbox?** Sí. Detecta el framework solo (o lo elegís en `Config.Framework`) y toma los rangos de tus grupos, permisos o jobs. Sin framework, los rangos se dan por ACE.
- **¿Quién tiene permisos apenas lo instalo?** Nadie. Ningún jugador es staff hasta que mapeás los rangos en `config.lua` o por ACE.
- **¿Cómo lo recibo?** Tebex lo entrega en tu cuenta de cfx.re (portal.cfx.re → Granted Assets) apenas pagás.
- **¿Puedo editar el código?** `config.lua`, locales y la interfaz sí. El core va con escrow.
- **¿Pago por cada staff?** No. Core es pago único por server; Pro es mensual por server, sin importar cuántos staff tengas.
- **¿Hay updates?** Core: updates de por vida de la edición Core. Pro: mientras la suscripción esté activa.
- **¿Reembolsos?** {{POLITICA_REEMBOLSO}} (definir con Fausto. Recomendación: probar el Lite gratis antes de comprar).
- **¿Soporte?** En español y en inglés por {{DISCORD_URL}}.

**EN**
- **Does it replace txAdmin?** No. txAdmin stays for noclip, god mode, spawning and the web panel. This covers the staff workflow (tickets, moderation with a reason, duty) and records it in a verifiable chain.
- **What does "verifiable" mean?** Each entry stores the SHA-256 hash of the previous one. `/audit` recomputes the whole chain: if anything was edited, deleted or reordered, it tells you which entry broke. With the Discord anchor you can also detect a deleted tail.
- **Does it stop admin abuse?** No. It makes sure abuse is recorded and that deleting the record shows. It isn't an anticheat.
- **Does it capture everything on my server?** No. It records what goes through the system, the listed admin commands, and anything other scripts send via `exports.staff_suite:Record`. Actions other resources take on their own can't always be intercepted server-side.
- **Do I need a database?** No. JSON by default; oxmysql is optional.
- **ESX / QBCore / Qbox?** Yes. It detects the framework automatically (or you set `Config.Framework`) and reads ranks from your groups, permissions or jobs. Without a framework, ranks come from ACE.
- **Who has permissions right after install?** Nobody. No player is staff until you map ranks in `config.lua` or via ACE.
- **How do I get it?** Tebex delivers it to your cfx.re account (portal.cfx.re → Granted Assets) right after payment.
- **Can I edit it?** `config.lua`, locales and the UI, yes. The core is escrowed.
- **Do I pay per staff member?** No. Core is a one-time payment per server; Pro is monthly per server, whatever your team size.
- **Updates?** Core: lifetime updates for the Core edition. Pro: while the subscription is active.
- **Refunds?** {{REFUND_POLICY}} (to be defined. Recommendation: try the free Lite before buying).
- **Support?** Spanish and English via {{DISCORD_URL}}.

---

## Especificación de imágenes

Tebex: la imagen del paquete se muestra según el template; la guía de Tebex pide **PNG de ≤165 px de alto** para la imagen del paquete, y permite videos de YouTube en un carrusel junto a las imágenes ([doc](https://docs.tebex.io/creators/tebex-control-panel/how-to-create-packages/how-to-create-a-package)). Tebex recomienda un template consistente (Figma), título visible, colores con contraste y no sacar capturas de noche.

Estilo: el del panel (BUILD_PLAN: fondo claro, Manrope 800 para títulos, DM Sans para el cuerpo, verde #16A34A = íntegro, naranja #F58220 = acento, rojo #E5484D = cadena rota). Sin gradientes violetas ni emojis. Todas las capturas son reales: panel corriendo in-game en un server de QA con datos de prueba (no el modo demo de `npm run dev`), sin nombres reales de jugadores.

| # | Archivo | Tamaño | Contenido | Uso |
|---|---|---|---|---|
| 1 | `pkg-lite.png` | 330×165 (≤165 px de alto, 2:1) | Logo + "LITE · GRATIS" / "LITE · FREE" | Imagen del paquete Lite |
| 2 | `pkg-core.png` | 330×165 | Logo + "CORE" + candado verde | Imagen del paquete Core |
| 3 | `pkg-pro.png` | 330×165 | Logo + "INTEGRITY PRO" | Imagen del paquete Pro (cuando se publique) |
| 4 | `banner-store.png` | 1920×480 | Tagline + captura del visor con el badge "Cadena íntegra" | Header de la tienda (template) |
| 5 | `cover-1280x720.png` | 1280×720 (16:9) | Pantalla partida: a la izquierda, cadena verde "íntegra"; a la derecha, la misma cadena con una entrada en rojo "rota en #12". Texto: "¿Alguien borró un log?" | Miniatura de YouTube + primera imagen del post del foro (preview) |
| 6 | `shot-audit.png` | 1920×1080 | Visor de auditoría: timeline con seq, acción, actor → target, razón, hash truncado | Carrusel Tebex + foro |
| 7 | `shot-broken.png` | 1920×1080 | Resultado de verificar con una entrada manipulada a mano, resaltada en rojo | Carrusel + foro (la imagen más importante) |
| 8 | `shot-ticket.png` | 1920×1080 | Ticket abierto: estado, reclamado por, hilo con una nota interna, botones de moderación con la razón escrita. Ojo: Advertir y Banear aparecen en gris (próximamente); recortar o aclararlo | Carrusel + foro |
| 8b | `shot-dashboard.png` | 1920×1080 | Dashboard con tickets abiertos/resueltos, staff en servicio y la tabla del equipo. Tiempo de respuesta y rating todavía salen "—": no destacarlos | Carrusel |
| 9 | `shot-discord.png` | 1280×720 | Mensaje del webhook "Ancla de auditoría · seq N · hash" (EN: "Audit anchor · seq N · hash") en un canal de Discord | Carrusel + foro |
| 10 | `shot-console.png` | 1280×720 | Consola del server: `[StaffSuite] auditoría OK: N entradas` y después `auditoría ROTA en la entrada N` (o en inglés: `audit OK: N entries` / `audit BROKEN at entry N`) | Foro (prueba técnica) |
| 11 | `shot-resmon.png` | recorte real | resmon con `staff_suite` (#19) | Foro (exigido por las reglas) |
| 12 | `gif-verify.gif` | 600×338, ≤5 MB | Loop de 5–8 s: clic en "Verificar cadena" → verde; editar → rojo | Post del foro (como hacen los releases top) |

Para las imágenes 5, 7 y 12: frenar el resource, editar a mano una entrada en `staff_suite_data.json`, volver a iniciar y tocar "Verificar cadena" en el panel. La 10 sale de la consola con `/audit`.
