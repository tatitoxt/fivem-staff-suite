# Post del foro — versión en español

> El foro de Releases no tiene categoría en español: este texto va en el bloque `[details="En español"]` de cada post en inglés, en los Discords ES/LATAM y en el README del GitHub de Lite.
> Mismas reglas que `forum-post-en.md`: no publicar hasta reemplazar `[RESMON PENDIENTE]`, pasarlo por tu voz y revisar la matriz de `launch/README.md`.

---

## (A) Lite

```markdown
Staff Integrity Suite Lite es un sistema de reportes gratis con una vuelta: **cada acción del panel queda en una cadena SHA-256, así que nadie puede editar el historial sin que se note.**

Los jugadores reportan con `/report`. Tu staff abre el panel con F6, reclama el ticket, lo resuelve y lo cierra. Cada paso queda como una entrada que incluye el hash de la anterior. Tocás "Verificar cadena" (o `/audit` en la consola) y sabés si alguien editó, borró o reordenó algo, y en qué entrada.

## Preview
{{YOUTUBE_ES}}

## Qué hace
* `/report <categoría> <descripción>`, hasta 3 reportes abiertos por jugador.
* Cola de tickets en el panel (F6 o `/reports`): reclamar (sin doble reclamo), responderle al jugador, resolver con texto, cerrar, reabrir.
* El jugador ve sus reportes abiertos en "Mis reportes", responde ahí y le llega un aviso cuando le contesta el staff.
* Visor de auditoría con filtros y botón "Verificar cadena". La entrada rota se marca en rojo.
* Standalone: un permiso ACE, guarda en JSON, sin base de datos.
* Límites de acciones y de texto para que nadie te llene la cola.
* Español e inglés.
* Licencia MIT: el Lua es tuyo para leerlo y cambiarlo.

## Rendimiento
* resmon de cliente: [RESMON PENDIENTE]
* Probado en un FXServer real: 32 de 32 checks E2E.
* Sin loops por tick en el server.

## Instalación
1. Bajalo de {{GITHUB_URL}} y poné la carpeta en `resources/` como `staff_suite`.
2. Sumá `add_ace group.admin staff_suite.lite allow` y `ensure staff_suite` a `server.cfg`.

## ¿Querés más?
Core suma moderación desde el ticket (ban, warn, spectate, revive y más), turnos y estadísticas por staff, calificación del jugador, evidencia con capturas, registro de eventos de framework y txAdmin, oxmysql y el ancla del hash en Discord. Conserva tus tickets y tu cadena de Lite. → {{CORE_TOPIC_URL}}

## Links
* **Descarga:** {{GITHUB_URL}}
* **Docs:** {{DOCS_URL}}
* **Soporte (ES/EN):** {{DISCORD_URL}}
```

---

## (B) Core

```markdown
Staff Integrity Suite Core se ocupa del trabajo de tu staff (reportes, moderación, turnos) y guarda **un registro de lo que hace tu staff que no se puede editar sin que se note.**

Cada reporte, reclamo, ban, warn, turno y verificación queda en una cadena SHA-256. Cada entrada incluye el hash de la anterior. La verificás desde el panel o con `/audit`: si alguien editó, borró o reordenó una entrada, ves cuál. Cada 20 entradas el hash actual también va a un webhook de Discord y a un archivo aparte, así que ni reescribir todo pasa desapercibido.

Se usa junto a txAdmin, no lo reemplaza. Noclip, god y spawn siguen en txAdmin.

## Preview
{{YOUTUBE_ES}}
Si el video no carga, [click acá]({{YOUTUBE_ES}}).

## Qué hace

**Auditoría**
* Quién, qué, a quién, cuándo y por qué, cada entrada encadenada a la anterior.
* Visor con filtros por staff, acción y fecha. La entrada alterada se marca en rojo y las siguientes quedan señaladas.
* Ancla fuera del server: webhook de Discord + archivo que solo crece.
* Registra eventos de ESX (job, grupo, items, dinero), QBCore/Qbox (job, dinero, grupos) y txAdmin (ban, kick, warn, heal).
* `exports.staff_suite:Record(...)` para que tus scripts escriban en la misma cadena.

**Tickets**
* Reclamar, liberar, transferir a otro staff conectado, prioridades y notas internas.
* Chat con el jugador: lee y responde en "Mis reportes" y le llega un aviso cuando le escribe el staff. Las notas internas no las ve.
* Respuestas predefinidas que armás en `config.lua`.
* El jugador califica la atención de 1 a 5 cuando se resuelve el ticket.
* Evidencia con screenshot-basic: el hash de la captura va a la cadena y el panel lo vuelve a chequear cuando la abrís.

**Moderación desde el ticket**
* Goto, bring, freeze, unfreeze, heal, kick, warn, ban, spectate y revive, cada una con su permiso. El panel muestra a quién congelaste.
* Ban temporal o permanente por license, license2, FiveM, Steam, Discord, Xbox y tokens de hardware. Si el jugador vuelve con una cuenta nueva que comparte alguno, el ban la alcanza. Sin bans por IP.
* Ban y warn piden razón. Kick también, salvo que lo desactives.
* Nadie puede traer, congelar, expulsar, advertir ni banear a un rango superior. Lo controla el server.
* Revive usa el sistema médico de tu framework o uno standalone.

**Turnos y estadísticas**
* `/duty` o el botón del panel. Horas y sesiones por staff.
* Dashboard y ranking: resueltos, tiempo de primera respuesta y calificación promedio.

**Instalación**
* Standalone (ACE), ESX, QBCore o Qbox, detectados solos. Nadie es staff por defecto: 5 rangos, 20 permisos y excepciones por persona.
* JSON, u oxmysql con migraciones automáticas al iniciar.
* Límites de acciones por jugador y de texto.
* Español e inglés.

## Lo que NO hace
* No es un anticheat ni frena todos los abusos. Los hace visibles y difíciles de borrar.
* Solo ve lo que pasa por él, los eventos compatibles de framework/txAdmin y lo que mandes por `Record`.
* No es un menú de admin. Seguí usando txAdmin.

## Rendimiento
* resmon de cliente: [RESMON PENDIENTE]
* Server, por llamada (medido en el E2E en un FXServer real): `Record` 0.09 ms, `GetState` 0.30 ms. Sin loops por tick en el server.
* E2E en FXServer real: 30 de 30 checks.

## Instalación
1. Compralo en {{TEBEX_URL}}. Te aparece en tu cuenta de cfx.re (Granted Assets).
2. Poné `staff_suite` en `resources/` y sumá `ensure staff_suite` a `server.cfg`.
3. En `config.lua`: idioma, framework (`auto`) y mapeo de rangos. Standalone: `add_ace group.admin staff_suite.admin allow`.
4. Ancla en Discord (opcional): `set staff_suite_webhook "URL"` en `server.cfg` (queda solo en el server, no uses `setr`).
5. Opcional: `ensure oxmysql` antes del recurso y las tablas se crean solas. `ensure screenshot-basic` para la evidencia.
¿Venís de Lite? Reemplazá los archivos y mantené el nombre `staff_suite`: tus tickets y tu cadena quedan.
Docs completas: {{DOCS_URL}}

## Links
* **Core:** {{TEBEX_URL}}
* **Lite (gratis):** {{LITE_TOPIC_URL}}
* **Docs:** {{DOCS_URL}}
* **Soporte (ES/EN):** {{DISCORD_URL}}
```

> La tabla obligatoria va en inglés al final del post (`forum-post-en.md`); no hace falta repetirla acá.
