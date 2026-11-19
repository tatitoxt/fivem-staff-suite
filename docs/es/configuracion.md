# Referencia de configuración

Versión documentada: **0.1.0**. Hay dos archivos:

| Archivo | Se carga en | Para qué |
|---|---|---|
| `config.lua` | cliente **y** server (`shared_script`) | Opciones públicas: idioma, comandos, categorías, framework, rangos, persistencia. |
| `server/config.lua` | solo server | Opciones privadas: webhook y anclas (`Config.Export`) y rangos por identificador (`Config.StandaloneRanks`). |

No pongas secretos en `config.lua`: lo descarga cada jugador.

## `config.lua`

### General

| Clave | Default | Descripción |
|---|---|---|
| `Config.Locale` | `'es'` | Idioma de los mensajes: `'es'` o `'en'`. Si ponés un idioma que no existe, o falta una clave, se usa el texto en inglés. |
| `Config.PanelKey` | `'F6'` | Tecla por defecto para abrir el panel. Cada jugador la puede cambiar en *Configuración → Asignación de teclas → FiveM*. |

### `Config.Commands`

| Clave | Default | Descripción |
|---|---|---|
| `report` | `'report'` | Comando del jugador para crear un reporte. |
| `duty` | `'duty'` | Comando de staff para entrar/salir de servicio. |
| `audit` | `'audit'` | Comando para verificar la cadena (consola o juego). |
| `reports` | `'reports'` | Cola de tickets por comando **(próximamente)**: todavía no se registra. |

### Reportes

| Clave | Default | Descripción |
|---|---|---|
| `Config.Categories` | `{ 'bug', 'player', 'staff', 'question', 'other' }` | Categorías válidas. Una categoría que no está en la lista se guarda como `other`. Cada una necesita su etiqueta `cat_<nombre>` en `locales/`. |
| `Config.Priorities` | `{ 'low', 'normal', 'high', 'urgent' }` | Prioridades válidas (desde el panel). Una prioridad desconocida, o un reporte por `/report`, entra como `normal`. Cada una necesita `pri_<nombre>` en `locales/`. |

### Framework y rangos

| Clave | Default | Descripción |
|---|---|---|
| `Config.Framework` | `'auto'` | `'auto'` detecta Qbox → QBCore → ESX → standalone. Forzá `'qbox'`, `'qbcore'`, `'esx'` o `'standalone'` si tenés más de uno. Otro valor corta el arranque con `Config.Framework inválido`. |
| `Config.RankMap` | ver abajo | Grupo ESX, permiso QBCore u objeto ACE de Qbox → rango de Staff Suite. |
| `Config.JobRankMap` | `{ esx = {}, qbcore = {}, qbox = {} }` | Job activo → rango, por framework. Ej.: `esx = { staff = 'helper' }`. |

Default de `Config.RankMap`:

```lua
Config.RankMap = {
  helper = 'helper', support = 'helper',
  mod = 'moderator', moderator = 'moderator',
  admin = 'admin',
  superadmin = 'senior_admin',
  owner = 'owner', god = 'owner',
}
```

Si un jugador coincide con varios grupos, permisos o jobs, gana el rango más alto. Rangos válidos: `helper`, `moderator`, `admin`, `senior_admin`, `owner`. Ver [Rangos y permisos](permisos.md).

### Persistencia

| Clave | Default | Descripción |
|---|---|---|
| `Config.Persistence` | `'json'` | `'json'` (archivo) u `'oxmysql'` (MySQL/MariaDB). Con `'oxmysql'` y oxmysql apagado, cae a JSON. |
| `Config.JsonFile` | `'staff_suite_data.json'` | Archivo dentro de la carpeta del resource. |

Los datos se guardan después de cada entrada de auditoría, cada 60 segundos y al parar el resource. Con oxmysql se guarda todo el estado en una fila de la tabla `staff_state`.

### `Config.Audit`

| Clave | Default | Descripción |
|---|---|---|
| `capture_commands` | `true` | Registra comandos restringidos `ban`, `kick`, `warn`, `giveitem`, `givemoney`, `setjob` y anota cada uso en la auditoría como `cmd_<comando>`. Si choca con comandos con el mismo nombre de otro resource, ponelo en `false`. |
| `capture_framework` | `true` | Captura de eventos del framework (grants, bans) **(próximamente)**: todavía no tiene efecto. |

### `Config.Moderation`

| Clave | Default | Descripción |
|---|---|---|
| `require_reason` | `true` | Exige razón para `kick`. |

## `server/config.lua`

### `Config.Export` (anclaje off-box)

| Clave | Default | Descripción |
|---|---|---|
| `webhook` | `GetConvar('staff_suite_webhook', '')` | URL de un webhook de Discord. Se configura en `server.cfg` con `set staff_suite_webhook "URL"`. Vacío = desactivado. |
| `file` | `true` | Escribe cada ancla en `audit_export.log` (carpeta del resource). |
| `anchor_every` | `20` | Cada cuántas entradas se ancla el hash actual. |

Usá `set`, **no** `setr`: `setr` replica el convar a los clientes y cualquiera podría leer la URL. Detalle completo en [Auditoría: export y verificación](auditoria.md).

### `Config.StandaloneRanks`

Rangos por identificador estable, solo en modo standalone:

```lua
Config.StandaloneRanks = {
  ['license:1234abcd...'] = 'admin',
}
```

Se combina con los ACE `staff_suite.<rango>`: gana el más alto. Con un framework activo no se usa.

## Locales

Los textos están en `locales/es.lua` y `locales/en.lua`. Si agregás o cambiás una clave, ponela en los **dos** archivos y corré los tests:

```
lua5.4 tests/run_all.lua
```

El test `test_locales` falla si falta una clave en algún idioma, si queda un texto vacío o si los placeholders (`%{id}`, `%{name}`…) no coinciden.
