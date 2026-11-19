# Post de lanzamiento (ES)

> **Dónde va:** forum.cfx.re no tiene categoría en español (verificado en la lista de categorías el 19/11/2026); el topic de Releases va en inglés (`forum-post-en.md`). Este texto se usa:
> 1. dentro del bloque `[details="En español"]` del post EN,
> 2. en los canales de releases de Discords ES/LATAM (aportá valor primero, sin spam: `DISTRIBUTION.md` §10),
> 3. en el README del repo público del Lite.
>
> Mismas reglas que el post EN: re-verificá las features con la matriz de `launch/README.md`, escribilo con tu voz, y no pidas reviews.

---

## Título
`[GRATIS] Staff Integrity Suite Lite — Reportes + auditoría del staff a prueba de manipulación (SHA-256) | Standalone | ES/EN`

(Versión paga: `Staff Integrity Suite — Reportes, moderación en el ticket y auditoría verificable del staff | Standalone | ES/EN`)

## Cuerpo

```markdown
![portada](upload://...)

Staff Integrity Suite es un sistema de reportes y de flujo de staff con un foco puntual: **un registro de lo que hace tu staff que no se puede editar sin que se note.**

Cada reporte, reclamo, acción de moderación y turno queda en una cadena SHA-256. Cada entrada incluye el hash de la anterior. Con `/audit` el server recalcula la cadena entera: si alguien editó, borró o reordenó una entrada, te dice cuál.

Se usa junto a txAdmin, no lo reemplaza. Noclip, god y spawn los sigue haciendo txAdmin.

## Preview
{{YOUTUBE_ES}}
Si no carga el video, [hacé clic acá]({{YOUTUBE_ES}}).

## Features

**Auditoría (el motivo de todo esto)**
* **Entradas encadenadas:** quién, qué, a quién, cuándo y por qué, cada una ligada a la anterior con SHA-256.
* **Detección de manipulación:** detecta entradas editadas, borradas o reordenadas, y te dice cuál se rompió.
* **Ancla fuera del server:** cada N entradas (20 por defecto) el hash actual va a un webhook de Discord y a un archivo de log. Si alguien reescribe toda la cadena, no coincide con el ancla.
* **Verificación cuando quieras:** `/audit` desde la consola o in-game. La verificación también queda registrada.
* **API:** con `exports.staff_suite:Record(action, actor, target, reason, payload)` tus otros scripts escriben en la misma cadena.

**Reportes**
* `/report <categoría> <descripción>`, con categorías configurables.
* Reclamar, liberar, transferir, resolver, cerrar y reabrir. No se puede reclamar dos veces el mismo ticket.
* Cada paso del ticket queda en la cadena.

**Lo que suma Core (pago)**
* **Moderación desde el ticket:** goto, bring, freeze, heal y kick. kick/warn/ban piden razón obligatoria. Todo queda en la cadena.
* **Permisos por rango:** 5 rangos, 20 permisos, altas y bajas por persona.
* **Registro de comandos de admin (best-effort):** `ban`, `kick`, `warn`, `giveitem`, `givemoney`, `setjob`.
* **Turnos:** `/duty` on/off con la duración registrada.
* **Persistencia:** JSON sin base de datos, u oxmysql.

**Próximamente** (sin fechas; lo anuncio cuando esté probado)
* Panel in-game (F6): cola de tickets, timeline de auditoría y equipo
* Chat del ticket con notas internas, calificación del jugador, prioridades
* ban / warn / spectate / revive
* Analytics del staff: horas, tickets resueltos, tiempo de respuesta, ranking
* Rangos desde ESX / QBCore / Qbox

## Lo que NO hace
* No es un anticheat y no frena el abuso: hace que quede a la vista y que borrarlo se note.
* No intercepta todo lo que otros resources hacen por su cuenta. Registra lo que pasa por el sistema, los comandos listados y lo que mandes por `Record`.
* No es un menú de admin. Seguí usando txAdmin.

## Rendimiento
* Idle: {{RESMON_IDLE}} ms · Activo (panel abierto): {{RESMON_ACTIVO}} ms (resmon, server con {{N}} jugadores)
* Sin loops por tick en el server. Guarda cada 60 s y al apagar el resource.

## Instalación
1. Descargalo de {{GITHUB_URL}} (Lite) o {{TEBEX_URL}} (Core).
2. Copiá `staff_suite` a `resources/` y agregá `ensure staff_suite` en `server.cfg`.
3. En `config.lua` elegí idioma, comandos y rangos. Opcional: webhook de Discord en `Config.Export.webhook`.
Docs completas: {{DOCS_URL}}

## Links
* **Lite (gratis):** {{GITHUB_URL}}
* **Core:** {{TEBEX_URL}}
* **Docs:** {{DOCS_URL}}
* **Soporte (ES/EN):** {{DISCORD_URL}}

|                             |                                          |
|-----------------------------|------------------------------------------|
| Código accesible            | Parcial (config, locales y UI abiertos; core con escrow) |
| Por suscripción             | No                                       |
| Líneas (aprox.)             | ~{{LINEAS}}                              |
| Requisitos y dependencias   | FXServer actualizado, OneSync (acciones de moderación); oxmysql opcional |
| Soporte                     | Sí                                       |
```

## Versión corta para Discord (≤ 1.000 caracteres)
```
**Staff Integrity Suite Lite — gratis**
Reportes + un registro de lo que hace tu staff que no se puede editar sin que se note.

• /report con reclamo, transferencia y cierre
• Cada acción queda en una cadena SHA-256: si alguien edita o borra un log, /audit te dice cuál
• Ancla del hash en tu Discord (webhook) por si reescriben todo
• Standalone, sin base de datos obligatoria, ES/EN

Lo armé porque en casi todos los servers el log del staff es un .txt que cualquier admin con acceso puede tocar.
Video: {{YOUTUBE_ES}} · Descarga: {{GITHUB_URL}}
Si lo probás, me sirve mucho saber qué le falta.
```
