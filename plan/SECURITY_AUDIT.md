# Auditoría de seguridad

Criterio: un jugador con un cliente modificado que dispara eventos de red y callbacks NUI arbitrarios, y un dueño de server que necesita que la cadena de auditoría y la persistencia sean confiables. Severidad: crítico (compromete el server o la cadena), alto (escalada o abuso sin privilegios), medio (abuso acotado o con privilegios), bajo (defensa en profundidad).

## Ronda 2 (main en 59290d0)

Superficies revisadas: anuncios (#26), evidencia al crear reporte (#27), bans/unban (#28), export a Discord (#29), staff chat (#30), perfil + notas + tiempo conectado (#31, #35), plantillas de sanción (#33), auto-escalado de warns (#34), TP al waypoint (#36), notificaciones in-game (#39, #40, #42).

| # | Severidad | Hallazgo | Estado |
|---|---|---|---|
| R2-1 | Alto | `staff_suite:banRevoke` no respetaba la jerarquía: un rango con `ban.revoke` (p. ej. senior_admin) podía revocar un ban puesto por un rango superior (owner). | Corregido: el ban guarda `actor_rank` (en el ban y en el payload auditado de `mod_ban`) y la revocación exige no estar por debajo de ese rango. Los bans anteriores a este cambio no tienen rango y se pueden revocar como antes. |
| R2-2 | Medio | La captura de `screenshot-basic` llega como data URI armado por el cliente. Un cliente modificado que crea reportes con evidencia adjunta podía subir datos de tamaño arbitrario o que no son imágenes, que se guardaban en disco y se servían a staff. | Corregido: tope `Config.Limits.evidence_bytes` (3 MiB) y data URI JPEG obligatorio antes de guardar: prefijo `data:image/jpeg;base64,`, base64 válido y bytes mágicos de JPEG (`/9j/`). El rate limit y el tope de reportes abiertos ya acotaban la cantidad. |
| R2-3 | Bajo | Los payloads a Discord (export de ticket y anclas) no fijaban `allowed_mentions`. Hoy el `content` no lleva texto de jugadores (la transcripción va como adjunto `.txt`), así que no había inyección de `@everyone` ni de roles explotable. | Corregido como defensa en profundidad: `allowed_mentions = { parse = {} }` en ambos webhooks. |
| R2-4 | Bajo | El resultado del TP al waypoint (`waypointResult`) lo informa el cliente; un staff con cliente modificado puede auditar `ok` sin moverse, o teletransportarse sin pasar por el evento. | Aceptado: el TP es local al propio staff con `staff.waypoint` y no afecta a otros jugadores; la solicitud queda auditada server-side antes de despachar. |
| R2-5 | Bajo | El staff chat se reenvía al recurso `chat` con el nombre del jugador; los códigos de color `^0`–`^9` del nombre o del cuerpo se interpretan. | Aceptado: solo lo ven y lo envían miembros con `staff.chat`; el recurso `chat` escapa HTML. |

Revisado sin hallazgos:

- Permisos server-side: todos los eventos nuevos validan `source`, identifier y capability (`staff.announce`, `staff.chat`, `ban.view`/`ban.revoke`, `report.export`, `player.profile.*`, `staff.waypoint`, `mod.template`, `mod.warn_escalate`) y tienen rate limit propio.
- Jerarquía en sanciones: `warn`, `kick`, `ban`, `freeze` y `bring` siguen protegidos por `perms.outranks`; el auto-escalado revalida actor, objetivo y rango al disparar el kick.
- Plantillas: el cliente solo elige un ID (`^[%w_%-]+$`, ≤ 32); acción, motivo y duración salen de `Config.SanctionTemplates`.
- Límites y sanitización: anuncios, staff chat, notas y motivo de unban pasan por `cleanText` con límite en bytes. React renderiza texto, sin `dangerouslySetInnerHTML`.
- Perfil del jugador: solo staff con `report.view` + `player.profile.view`; `myTickets` (vista del reporter) no incluye mensajes internos, evidencia ni notas. El contenido del staff chat no entra en `audit.view` (solo bytes).
- Cadena: todas las acciones nuevas se registran server-side; el cliente no aporta hash, seq ni timestamp. La evidencia se verifica contra la entrada auditada, no contra el ticket.
- Free Lite no expone ninguna de las superficies nuevas.

## Ronda 1 (PR #13, #17, #19)

| Severidad | Hallazgo | Estado |
|---|---|---|
| Alto | Sin rate limiting en eventos de tickets, mensajes, evidencia y verificación. | Corregido (#13) |
| Alto | Sin límite de tamaño de inputs de texto. | Corregido (#13) |
| Alto | Evasión de bans con identifiers alternativos. | Corregido (#13) |
| Medio | Moderación sin jerarquía de rangos, ownership de tickets, exports sin validación, entradas corruptas en disco, canonicalización de la cadena. | Corregido (#13) |
| Medio | Borrador perdido al rechazar `ticket_create`. | Corregido (#17) |
| Bajo | `export.anchor` reescribía el log completo y el webhook no reintentaba. | Corregido (#19) |
| Bajo | El listener `message` de la NUI no validaba el origin. | Corregido (#19) |
