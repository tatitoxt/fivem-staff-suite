# Auditoría de seguridad

Criterio: un jugador con un cliente modificado que dispara eventos de red y callbacks NUI arbitrarios, y un dueño de server que necesita que la cadena de auditoría y la persistencia sean confiables. Severidad: crítico (compromete el server o la cadena), alto (escalada o abuso sin privilegios), medio (abuso acotado o con privilegios), bajo (defensa en profundidad).

## Ronda 3 (main en 4a659a0)

Superficies revisadas: limpieza de vehículos con cuenta regresiva (#43-#51), reparar/borrar vehículo del jugador, congelamiento de emergencia, noclip/invisible, edición de rangos/permisos desde el panel (defa3c9), actividad semanal + export CSV (2d7016e), TP a coordenadas (eafb2a4), cancelación por el reportante (f1fbe36), aviso sin staff (72a117b), etiquetas de triaje (d63f1eb), apelaciones de baneo (6863727), timeline del ticket (7ef71a8), invitación de staff (b727742), locales PT/FR/DE (0247bc2).

| # | Severidad | Hallazgo | Estado |
|---|---|---|---|
| R3-1 | Bajo | Mutaciones en memoria antes de confirmar el append de la cadena (`ticketLabel`, `ticketCancel`, `banAppeal`): si el `record()` falla, la UI ya reflejó un cambio que no quedó persistido y revierte al reiniciar. | Aceptado: convención del codebase (claim/transfer/resolve hacen lo mismo); la escritura falla solo si el backend de persistencia está caído, y el estado en memoria sigue siendo consistente para todos los clientes. Degradación controlada, no explotable. |
| R3-2 | Bajo | `staff_suite:coords` TP a coordenadas arbitrarias con resultado informado por el cliente — misma postura que el waypoint (R2-4). | Aceptado: acción local del staff con `staff.coords` (admin+); la solicitud queda auditada antes de despachar y el resultado se registra con `request_seq`. |
| R3-3 | Bajo | `staff_suite:ticketInvite` consulta el roster por identifier y luego notifica — el invitado puede desconectar o perder `report.claim` entre la validación y la notificación. | Mitigado: la notificación re-verifica identifier + `canReceiveTransfer` dentro del callback del `record()` antes de disparar el evento (fix en dcf7b7c). |

Revisado sin hallazgos:

- **Edición de rangos/permisos** (`staff_suite:ownerPermissions`): exige `admin.permissions`, aplica en dos fases (el modelo nuevo solo se activa si `record()` confirma), protege `baseRank == 'owner'`, whitelist `EDITABLE_RANKS`/`editableCaps`, re-verifica `expected` identifier contra reconexión, lock `pendingPermissions` anti-carreras, revoca duty/espectáculo/modos al quitar `staff.duty`, y registra `admin_permissions_failed` si falla el guardado.
- **Limpieza de vehículos**: segundos restringidos al conjunto configurado (`cleanupCountdowns`), `world.cleanup`, rate limit, lock `cleanupRequest` (un solo countdown activo con `ends_at` informado), `request_seq` enlazando solicitud/resultado/cancelación, y el borrado saltea vehículos ocupados, con conductor y trenes.
- **Emergencia (`mod.emergency_freeze`)**: lock `emergencyChange`, dos fases audit-gated, cierra espectáculos antes de congelar y restaura entidades por snapshot al liberar.
- **Reparar/borrar vehículo**: `protected` por jerarquía, re-check de ped+vehículo+netId dentro del callback, protección del staff que ocupa el vehículo (`protectsOccupant`), motivo obligatorio en delete.
- **Actividad semanal + CSV**: `staff.analytics`/`staff.analytics.export`, cadena verificada antes de computar (`verifyCached`), acción auditada con rango y cantidad de filas; el CSV se genera client-side de los mismos datos.
- **Cancelación del reportante**: identidad `ticket.reporter`, estado open/reopened sin claim, transición vía máquina de estados, broadcast a toda la cola. Idéntica en Lite.
- **Etiquetas**: solo el conjunto `Config.TicketLabels` (`labelSet`), `report.view`, audit `ticket_label`. Persistidas en SQL (004) y JSON.
- **Apelaciones**: `ban.revoke`, whitelist `APPEAL_STATES`, nota `cleanText` con límite, se aplica a todos los aliases del ban y sobrevive revocación/restart (fix b458f7c).
- **Coords**: rango validado server-side, NaN/inf rechazados (`coordInRange`), un request pendiente por staff, re-verificación al despachar, timeout 12 s con resultado 'unavailable' auditado, limpieza en `playerDropped`.
- **Timeline**: `ticketHistory` solo para `report.view`/isStaff; expone seq/ts/actor/action/reason de la cadena, nada interno nuevo.
- **Lite**: los handlers nuevos replican las guardas (isStaff, reporter ownership, rate limit, `cleanText`); sin superficies exclusivas de Core.
- **NUI**: sin `dangerouslySetInnerHTML`/innerHTML/eval; fetch solo a `GetParentResourceName()`; origins confiables `nui://game`/`nui-game-internal`.

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
