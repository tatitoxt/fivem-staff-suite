# Referencia de `config.lua`

`config.lua` queda abierto (fuera del escrow) para que lo edites. Versión documentada: **0.1.0**.

> **Seguridad:** `config.lua` se carga como `shared_script`, o sea que también llega a los clientes. No pongas ahí nada que un jugador no deba ver. Ver la nota sobre `Config.Export.webhook` más abajo.

## General

| Clave | Default | Descripción |
|---|---|---|
| `Config.Locale` | `'es'` | Idioma de los mensajes del server: `'es'` o `'en'`. Si ponés un idioma que no existe, se usa `'en'`. |
| `Config.PanelKey` | `'F6'` | Tecla por defecto para abrir el panel. Cada jugador la puede cambiar en *Configuración → Asignación de teclas → FiveM*. |

## `Config.Commands`

| Clave | Default | Descripción |
|---|---|---|
| `report` | `'report'` | Comando del jugador para crear un reporte. |
| `duty` | `'duty'` | Comando de staff para entrar/salir de servicio. |
| `audit` | `'audit'` | Comando para verificar la cadena (consola o juego). |
| `reports` | `'reports'` | Cola de tickets por comando **(próximamente)**: todavía no se registra. |

## Reportes

| Clave | Default | Descripción |
|---|---|---|
| `Config.Categories` | `{ 'bug', 'player', 'staff', 'question', 'other' }` | Categorías de reporte. Cada una necesita su etiqueta `cat_<nombre>` en `locales/`. En 0.1.0, `/report` acepta cualquier palabra como categoría; el filtro por esta lista llega con el panel **(próximamente)**. |
| `Config.Priorities` | `{ 'low', 'normal', 'high', 'urgent' }` | Prioridades. Cada una necesita `pri_<nombre>` en `locales/`. Los reportes por comando entran con `normal`. |

## Rangos

| Clave | Default | Descripción |
|---|---|---|
| `Config.StandaloneRank` | `'owner'` | Rango que reciben **todos** los jugadores en 0.1.0. Ver [Rangos y permisos](permisos.md). |
| `Config.RankMap` | `helper/mod/moderator/admin/superadmin/owner` | Mapea grupos del framework a rangos de Staff Suite. Se aplica cuando se conecten los bridges **(próximamente)**. |

## Persistencia

| Clave | Default | Descripción |
|---|---|---|
| `Config.Persistence` | `'json'` | `'json'` (archivo) u `'oxmysql'` (MySQL/MariaDB). Con `'oxmysql'` y oxmysql apagado, cae a JSON. |
| `Config.JsonFile` | `'staff_suite_data.json'` | Archivo dentro de la carpeta del resource. |

Los datos se guardan después de cada entrada de auditoría, cada 60 segundos y al parar el resource. Con oxmysql se guarda todo el estado en una fila de la tabla `staff_state`.

## `Config.Export` (anclaje off-box)

| Clave | Default | Descripción |
|---|---|---|
| `webhook` | `''` | URL de un webhook de Discord. Vacío = desactivado. |
| `file` | `true` | Escribe cada ancla en `audit_export.log` (carpeta del resource). |
| `anchor_every` | `20` | Cada cuántas entradas se ancla el hash actual. |

> **Webhook en 0.1.0:** como `config.lua` llega al cliente, un jugador con conocimientos podría leer la URL. Usá un webhook dedicado, en un canal que solo sirva para esto, y regeneralo si se filtra. Mover la URL a un convar solo del server está **(próximamente)**.

Detalle completo en [Auditoría: export y verificación](auditoria.md).

## `Config.Audit`

| Clave | Default | Descripción |
|---|---|---|
| `capture_commands` | `true` | Registra comandos restringidos `ban`, `kick`, `warn`, `giveitem`, `givemoney`, `setjob` y anota cada uso en la auditoría como `cmd_<comando>`. Si choca con comandos con el mismo nombre de otro resource, ponelo en `false`. |
| `capture_framework` | `true` | Captura de eventos del framework (grants, bans) **(próximamente)**: todavía no tiene efecto. |

## `Config.Moderation`

| Clave | Default | Descripción |
|---|---|---|
| `require_reason` | `true` | Exige razón para `kick`, `ban` y `warn`. |

## Locales

Los textos están en `locales/es.lua` y `locales/en.lua` (abiertos). Si agregás o cambiás una clave, ponela en los **dos** archivos y corré los tests:

```
lua5.4 tests/run_all.lua
```

El test `test_locales` falla si falta una clave en algún idioma, si queda un texto vacío o si los placeholders (`%{id}`, `%{name}`…) no coinciden.
