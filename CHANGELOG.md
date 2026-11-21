# Changelog

[Español](#030--español) · [English](#030--english)

## 0.3.0 · Español

### Cambios desde 0.2.0

- **Moderación completa desde el panel.** Lista de jugadores conectados con acciones, goto/bring/spectate/freeze/heal/revive, noclip e invisibilidad auditados con atajos, plantillas de sanción y auto-escalado de warns a kick/ban. La revocación de bans respeta la jerarquía del rango que baneó. [#31](https://github.com/tatitoxt/fivem-staff-suite/pull/31) · [#33](https://github.com/tatitoxt/fivem-staff-suite/pull/33) · [#34](https://github.com/tatitoxt/fivem-staff-suite/pull/34)
- **Mundo y emergencias.** Reparar o borrar el vehículo del jugador, limpieza global de vehículos vacíos con cuenta regresiva y cancelación (los trenes se saltean), y congelamiento de emergencia con restauración por snapshot. [#43](https://github.com/tatitoxt/fivem-staff-suite/pull/43)
- **Servicio y permisos.** El turno se cierra al revocar `staff.duty`, los modos de staff se apagan al quitar su capability, y los rangos/overrides ACE se editan desde el panel con auditoría en dos fases (`admin_permissions_change`).
- **Tickets avanzados.** Cancelación por el reportante, aviso de "sin staff conectado", etiquetas de triaje con filtro, historial/timeline por ticket, invitación de staff al ticket, evidencia con captura validada (tope y JPEG real) y export del hilo a Discord. [#55](https://github.com/tatitoxt/fivem-staff-suite/pull/55) · [#58](https://github.com/tatitoxt/fivem-staff-suite/pull/58) · [#60](https://github.com/tatitoxt/fivem-staff-suite/pull/60) · [#61](https://github.com/tatitoxt/fivem-staff-suite/pull/61)
- **Bans.** Apelaciones con estado y nota de revisión que sobreviven revocación y reinicio (migración `005_ban_appeal.sql`). [#59](https://github.com/tatitoxt/fivem-staff-suite/pull/59)
- **Staff tools.** TP a waypoint y a coordenadas (`staff.coords`, admin+), staff chat, anuncios, actividad semanal por staff con export CSV, Ctrl+K con acciones contextuales y tema oscuro opcional con `Config.Brand`. [#36](https://github.com/tatitoxt/fivem-staff-suite/pull/36) · [#57](https://github.com/tatitoxt/fivem-staff-suite/pull/57)
- **Idiomas.** El panel y el recurso corren en ES, EN, PT, FR y DE (556 claves por idioma).
- **Auditoría y robustez.** Tercera ronda de la auditoría de seguridad documentada en `plan/SECURITY_AUDIT.md` (R3). Migraciones nuevas: `003_ban_review.sql`, `004_ticket_labels.sql`, `005_ban_appeal.sql`. 148 tests Lua + 68 vitest + E2E en FXServer (Core 34/34, Lite 32/32).

### Actualizar de 0.2.0 a 0.3.0

1. Detené `staff_suite` y respaldá datos + config como en la migración a 0.2.0 (incluí la base si usás oxmysql).
2. Reemplazá la carpeta con el ZIP 0.3.0 de tu edición y conservá el nombre `staff_suite`. Pasá tus ajustes al `config.lua` nuevo — hay opciones nuevas (`Config.TicketLabels`, `Config.VehicleCleanup`, `Config.Brand`, theme).
3. **oxmysql (Core).** Al arrancar se aplican automáticamente las migraciones 003–005; el usuario de oxmysql necesita `CREATE`/`ALTER`. Si falla, Core avisa en consola y usa el JSON.
4. Iniciá el recurso, verificá el backend en consola y corré `audit` para confirmar la cadena.

## 0.3.0 · English

### Changes since 0.2.0

- **Full moderation from the panel.** Connected-players list with actions, goto/bring/spectate/freeze/heal/revive, audited noclip and invisibility with hotkeys, sanction templates and warn auto-escalation to kick/ban. Ban revocation respects the banning rank's hierarchy.
- **World and emergencies.** Repair or delete a player's vehicle, global cleanup of empty vehicles with countdown and cancel (trains are skipped), and emergency freeze with snapshot restore.
- **Duty and permissions.** Duty closes when `staff.duty` is revoked, staff modes shut off when their capability is removed, and ACE ranks/overrides are editable from the panel with a two-phase audited apply (`admin_permissions_change`).
- **Advanced tickets.** Reporter cancellation, "no staff online" notice, triage labels with filter, per-ticket history/timeline, staff invites to tickets, validated screenshot evidence (size cap and real JPEG) and ticket-thread export to Discord.
- **Bans.** Appeals with state and review note that survive revocation and restart (migration `005_ban_appeal.sql`).
- **Staff tools.** Teleport to waypoint and to explicit coordinates (`staff.coords`, admin+), staff chat, announcements, weekly staff activity with CSV export, Ctrl+K with contextual actions and an optional dark theme via `Config.Brand`.
- **Languages.** Panel and resource run in ES, EN, PT, FR and DE (556 keys each).
- **Audit and robustness.** Third security-audit round documented in `plan/SECURITY_AUDIT.md` (R3). New migrations: `003_ban_review.sql`, `004_ticket_labels.sql`, `005_ban_appeal.sql`. 148 Lua tests + 68 vitest + FXServer E2E (Core 34/34, Lite 32/32).

### Upgrading from 0.2.0 to 0.3.0

1. Stop `staff_suite` and back up data + config as in the 0.2.0 migration (include the database if you use oxmysql).
2. Replace the folder with your edition's 0.3.0 ZIP and keep the `staff_suite` name. Move your settings to the new `config.lua` — new options exist (`Config.TicketLabels`, `Config.VehicleCleanup`, `Config.Brand`, theme).
3. **oxmysql (Core).** Migrations 003–005 apply automatically on start; the oxmysql user needs `CREATE`/`ALTER`. If it fails, Core logs it and falls back to JSON.
4. Start the resource, check the backend in console and run `audit` to confirm the chain.

## 0.2.0 · Español

### Cambios desde 0.1.0

- **Ediciones.** Free Lite (MIT) incluye reportes básicos, visor de auditoría SHA-256 y persistencia JSON. Core conserva la moderación, servicio, estadísticas, integraciones y API, y se empaqueta para Cfx Asset Escrow. CI publica ambos ZIP. [#12](https://github.com/tatitoxt/fivem-staff-suite/pull/12)
- **Tickets avanzados de Core.** Respuestas predefinidas, calificación de 1 a 5, métricas de atención por staff y capturas con `screenshot-basic` verificadas contra la auditoría. Ajustes muestra el intervalo de anclaje y Core aplica las migraciones SQL al arrancar. [#8](https://github.com/tatitoxt/fivem-staff-suite/pull/8)
- **Moderación, captura y persistencia de Core.** Ban persistente con expiración, warn notificado al jugador, spectate y revive. Captura de eventos compatibles de ESX, QBCore, Qbox y txAdmin. Persistencia transaccional con oxmysql y respaldo JSON. [#10](https://github.com/tatitoxt/fivem-staff-suite/pull/10)
- **Chat del jugador.** Mis reportes muestra los tickets activos y el hilo público en Core y Lite. El reportante puede responder y recibe un aviso cuando contesta el staff. Core también suma Descongelar con `mod.freeze` y auditoría. [#21](https://github.com/tatitoxt/fivem-staff-suite/pull/21)
- **Validaciones y auditoría.** Límites de texto, frecuencia y tickets abiertos. Las acciones protegidas respetan la jerarquía del staff y los bans se comprueban por varios identificadores. Se reforzó la verificación de la cadena y se mantuvo la compatibilidad con las entradas previas. [#13](https://github.com/tatitoxt/fivem-staff-suite/pull/13)
- **Export y NUI.** Las anclas se agregan al final de `audit_export.log`. El webhook reintenta fallos transitorios con espera creciente. La NUI valida el origen de los mensajes. [#19](https://github.com/tatitoxt/fivem-staff-suite/pull/19)
- **Panel.** Lite abre la vista pedida desde el primer uso de `/reports` o `/audit`. El panel mejora la navegación con teclado, la carga, los errores, el foco y el escalado. Se redujo el peso de las fuentes y se corrigió el recorte del chat en 720p. [#14](https://github.com/tatitoxt/fivem-staff-suite/pull/14) · [#16](https://github.com/tatitoxt/fivem-staff-suite/pull/16) · [#20](https://github.com/tatitoxt/fivem-staff-suite/pull/20)
- **Envío de reportes.** El formulario espera confirmación del servidor. Si el envío falla, conserva el borrador y muestra el error. [#17](https://github.com/tatitoxt/fivem-staff-suite/pull/17)
- **API de Core.** `TicketAction` y `SetDuty` devuelven `false, código` ante errores de operación para que el código llegue al recurso que llama. `Flush()` y `GetPersistence()` permiten confirmar el guardado. Se corrigió el manejo del retorno de `SaveResourceFile`. [#11](https://github.com/tatitoxt/fivem-staff-suite/pull/11)
- **E2E.** Runner headless para FXServer con CI opcional y métricas separadas del costo del scheduler. Cubre Core y Lite, incluido el chat público de Lite. [#9](https://github.com/tatitoxt/fivem-staff-suite/pull/9) · [#11](https://github.com/tatitoxt/fivem-staff-suite/pull/11) · [#15](https://github.com/tatitoxt/fivem-staff-suite/pull/15) · [#21](https://github.com/tatitoxt/fivem-staff-suite/pull/21)
- **Materiales de lanzamiento.** Se actualizaron la comparativa de ediciones, el listing de Tebex, las publicaciones del foro y los guiones. [#18](https://github.com/tatitoxt/fivem-staff-suite/pull/18)

### Actualizar de 0.1.0 a 0.2.0

1. Detené `staff_suite`. Guardá una copia fuera del recurso de `staff_suite_data.json` (o el archivo indicado en `Config.JsonFile`), de la carpeta anterior y de `server.cfg`. Conservá también `audit_export.log` y `staff_suite_evidence_*.txt` si existen. Si usás oxmysql, respaldá la base de datos antes de migrar.
2. Reemplazá la carpeta con el ZIP de tu edición (`staff_suite-0.2.0.zip` para Core o `staff_suite_lite-0.2.0.zip` para Lite) y conservá el nombre `staff_suite`. Restaurá los archivos de datos con sus nombres originales. Pasá tus ajustes al `config.lua` nuevo y, en Core, a `server/config.lua`, así conservás las opciones nuevas. Si cambiaste `Config.JsonFile`, mantené ese valor.
3. **JSON (Core y Lite).** El recurso lee el respaldo restaurado al arrancar y conserva los tickets y la cadena. **oxmysql (Core).** Mantené `Config.Persistence = 'oxmysql'` y poné `ensure oxmysql` antes de `ensure staff_suite`. Al arrancar se aplican `sql/001_staff_suite.sql` y `sql/002_tickets_f2.sql` según corresponda, se registran en `staff_schema` y se importa el snapshot legado de `staff_state` si todavía no hay estado en el esquema nuevo. Con una base vacía, Core puede importar el JSON en su lugar.
4. **MySQL con permisos restringidos.** Para migrar automáticamente, el usuario de oxmysql necesita `CREATE` y `ALTER` además de permisos de lectura y escritura. Si el usuario de la app carece de permisos de migración, un administrador puede aplicar primero la 001 y luego la 002, omitiendo los `ALTER` de columnas que ya existan. Si falta esquema o falla la migración, Core lo avisa en consola y usa el JSON. Corregí el problema y reiniciá el recurso para reintentar.
5. Iniciá el recurso y verificá en consola el backend efectivo y la cantidad de entradas. Ejecutá `audit` (o tu nombre configurado) y comprobá que se conserven los tickets y la cadena. Si volvés a 0.1.0, detené el recurso y restaurá los binarios, la configuración y los datos del mismo respaldo previo al upgrade.

#### Convars y configuración

- El recurso conserva su convar de producción `staff_suite_webhook` (solo Core y opcional). Poné `set staff_suite_webhook "URL"` antes de `ensure staff_suite`. Usá `set` para mantener la URL en el servidor. Si usás oxmysql, conservá también su `mysql_connection_string`. Los convars nuevos `staff_suite_e2e_anchor_every`, `staff_suite_e2e_autoquit`, `staff_suite_e2e_profile_file` y `staff_suite_e2e_edition` son exclusivos del recurso de pruebas.
- **`Config.Limits`.** En ambas ediciones, `ticket_body` y `message_body` tienen un máximo de 1000 bytes por defecto y `open_tickets_per_player` es 3. Core también limita `reason` a 300 bytes y usa `message_body` para las resoluciones. Lite tiene una clave separada `resolution` de 1000 bytes.
- **`Config.RateLimit`.** Se aplica por jugador y evento. `burst` es la cantidad de acciones seguidas y `per_second` la tasa de recarga. Ambas ediciones traen reglas para `staff_suite:ticketCreate` (5 acciones, 1 cada 60 s), `staff_suite:ticketMessage` (10, 1 por segundo) y `staff_suite:verify` (3, 1 cada 10 s). `/report` comparte cuota con la creación y el chat del jugador comparte la del evento de mensajes. Core añade cuotas para servicio y evidencia. La regla `default` es 10 acciones y 2 por segundo.
- **Ajustes de Core.** Revisá `Config.CannedResponses`, `Config.Moderation.ban_duration`, `Config.Moderation.ban_tokens` y `Config.Audit.capture_framework`. Los reintentos del webhook se ajustan en `server/config.lua` mediante `Config.Export.webhook_retries`, `webhook_backoff_ms` y `webhook_backoff_max_ms`. Para integrar otros recursos, revisá el retorno `false, código` de los exports y usá el ZIP Core.

## 0.2.0 · English

### Changes since 0.1.0

- **Editions.** Free Lite (MIT) includes basic reports, the SHA-256 audit viewer and JSON storage. Core retains moderation, duty, analytics, integrations and the API, and is packaged for Cfx Asset Escrow. CI publishes both ZIPs. [#12](https://github.com/tatitoxt/fivem-staff-suite/pull/12)
- **Advanced Core tickets.** Canned replies, 1–5 ratings, per-staff support metrics and `screenshot-basic` captures verified against the audit log. Settings shows the anchor interval, and Core applies SQL migrations on startup. [#8](https://github.com/tatitoxt/fivem-staff-suite/pull/8)
- **Core moderation, capture and persistence.** Persistent bans with expiry, player-facing warnings, spectate and revive. Captures supported ESX, QBCore, Qbox and txAdmin events. Transactional oxmysql storage with JSON fallback. [#10](https://github.com/tatitoxt/fivem-staff-suite/pull/10)
- **Player ticket chat.** My reports shows active tickets and their public threads in Core and Lite. Players can reply and receive a notification when staff responds. Core also adds an audited Unfreeze action using `mod.freeze`. [#21](https://github.com/tatitoxt/fivem-staff-suite/pull/21)
- **Validation and auditing.** Limits on text, request rates and open tickets. Protected moderation actions respect staff hierarchy and bans are checked against multiple identifiers. Chain verification was hardened and remains compatible with older entries. [#13](https://github.com/tatitoxt/fivem-staff-suite/pull/13)
- **Exports and NUI.** Anchors are appended to `audit_export.log`. Webhooks retry transient failures with backoff. The NUI validates message origins. [#19](https://github.com/tatitoxt/fivem-staff-suite/pull/19)
- **Panel.** Lite opens the requested view on the first `/reports` or `/audit` call. The panel improves keyboard navigation, loading, errors, focus and scaling. Font assets are smaller and ticket chat stays visible at 720p. [#14](https://github.com/tatitoxt/fivem-staff-suite/pull/14) · [#16](https://github.com/tatitoxt/fivem-staff-suite/pull/16) · [#20](https://github.com/tatitoxt/fivem-staff-suite/pull/20)
- **Report submission.** The form waits for server confirmation. If submission fails, it keeps the draft and shows the error. [#17](https://github.com/tatitoxt/fivem-staff-suite/pull/17)
- **Core API.** `TicketAction` and `SetDuty` return `false, code` on operation errors so the calling resource receives the code. `Flush()` and `GetPersistence()` let callers confirm a save. Handling of the `SaveResourceFile` return value was fixed. [#11](https://github.com/tatitoxt/fivem-staff-suite/pull/11)
- **E2E.** Headless FXServer runner with optional CI and metrics that separate Staff Suite work from the scheduler. It covers Core and Lite, including Lite's public ticket chat. [#9](https://github.com/tatitoxt/fivem-staff-suite/pull/9) · [#11](https://github.com/tatitoxt/fivem-staff-suite/pull/11) · [#15](https://github.com/tatitoxt/fivem-staff-suite/pull/15) · [#21](https://github.com/tatitoxt/fivem-staff-suite/pull/21)
- **Launch materials.** Updated the edition comparison, Tebex listing, forum posts and scripts. [#18](https://github.com/tatitoxt/fivem-staff-suite/pull/18)

### Upgrade from 0.1.0 to 0.2.0

1. Stop `staff_suite`. Back up `staff_suite_data.json` (or the file specified by `Config.JsonFile`), the old resource folder and `server.cfg` outside the resource. Keep `audit_export.log` and `staff_suite_evidence_*.txt` if present. If you use oxmysql, back up the database before migrating.
2. Replace the folder with the ZIP for your edition (`staff_suite-0.2.0.zip` for Core or `staff_suite_lite-0.2.0.zip` for Lite) and keep the folder name `staff_suite`. Restore the data files under their original names. Copy your custom settings into the new `config.lua` and, for Core, `server/config.lua` to keep the new options. If you changed `Config.JsonFile`, retain that value.
3. **JSON (Core and Lite).** The resource reads the restored file on startup and retains tickets and the chain. **oxmysql (Core).** Keep `Config.Persistence = 'oxmysql'` and put `ensure oxmysql` before `ensure staff_suite`. On startup, the resource applies `sql/001_staff_suite.sql` and `sql/002_tickets_f2.sql` as needed, records them in `staff_schema` and imports the legacy `staff_state` snapshot if the new schema has no saved state. With an empty database, Core can import the JSON instead.
4. **MySQL with restricted privileges.** The oxmysql user needs `CREATE` and `ALTER` for automatic migration, in addition to read and write privileges. If the application user lacks migration privileges, a database administrator can apply 001 followed by 002, skipping `ALTER` statements for existing columns. If the schema is incomplete or migration fails, Core logs the problem and uses the JSON backup. Fix the issue and restart the resource to retry.
5. Start the resource and check the active backend and audit entry count in the console. Run `audit` (or your configured command name) and confirm that the tickets and chain are intact. To roll back to 0.1.0, stop the resource and restore the resource files, configuration and data from the same pre-upgrade backup.

#### Convars and configuration

- The resource keeps its production convar `staff_suite_webhook` (optional, Core only). Put `set staff_suite_webhook "URL"` before `ensure staff_suite`. Use `set` to keep the URL server-side. If you use oxmysql, retain its `mysql_connection_string`. The new `staff_suite_e2e_anchor_every`, `staff_suite_e2e_autoquit`, `staff_suite_e2e_profile_file` and `staff_suite_e2e_edition` convars belong to the test resource.
- **`Config.Limits`.** Both editions default to 1000 bytes for `ticket_body` and `message_body`, and 3 for `open_tickets_per_player`. Core also limits `reason` to 300 bytes and uses `message_body` for resolutions. Lite has a separate `resolution` limit of 1000 bytes.
- **`Config.RateLimit`.** Limits apply per player and event. `burst` is the number of consecutive actions and `per_second` is the refill rate. Both editions have rules for `staff_suite:ticketCreate` (5 actions, 1 every 60 s), `staff_suite:ticketMessage` (10, 1 per second) and `staff_suite:verify` (3, 1 every 10 s). `/report` shares the creation limit and player chat shares the message limit. Core adds limits for duty and evidence. The `default` rule allows 10 actions and refills 2 per second.
- **Core settings.** Review `Config.CannedResponses`, `Config.Moderation.ban_duration`, `Config.Moderation.ban_tokens` and `Config.Audit.capture_framework`. Configure webhook retries in `server/config.lua` via `Config.Export.webhook_retries`, `webhook_backoff_ms` and `webhook_backoff_max_ms`. For integrations with other resources, review the `false, code` return convention for exports and use the Core ZIP.
