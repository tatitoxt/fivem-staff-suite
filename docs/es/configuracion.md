# Referencia de configuración

Versión documentada: **0.2.0**. Hay dos archivos:

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
| `reports` | `'reports'` | Comando para abrir la cola de tickets en Lite. En Core, abrila desde el panel. |

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

Los cambios se guardan en lotes y el guardado pendiente se respalda al parar el recurso. Con oxmysql, cada lote usa una transacción y mantiene un respaldo JSON. Ban y warn esperan confirmación de guardado para expulsar o notificar al jugador.

### `Config.Audit`

| Clave | Default | Descripción |
|---|---|---|
| `capture_framework` | `true` | Habilita la captura de eventos del framework activo y de txAdmin. |

### `Config.Moderation`

| Clave | Default | Descripción |
|---|---|---|
| `require_reason` | `true` | Exige razón para `kick`. Ban y warn siempre requieren razón. |
| `ban_duration` | `86400` | Duración por defecto en segundos. Usá `0` para un ban permanente. |
| `ban_tokens` | `true` | Banea también los tokens de hardware del cliente (`token:*`). Además del `license`, el ban cubre `license2`, `fivem`, `steam`, `discord`, `xbl` y `live`; si un baneado vuelve con una cuenta nueva que comparte alguno, el ban se extiende a las nuevas (`mod_ban_extended`). Las IP no se usan. |

### `Config.Limits` y `Config.RateLimit`

| Clave | Default | Descripción |
|---|---|---|
| `Limits.ticket_body` / `message_body` / `reason` | `1000` / `1000` / `300` | Máximo en bytes que acepta el servidor; se quitan caracteres de control. |
| `Limits.open_tickets_per_player` | `3` | Reportes abiertos simultáneos por jugador. `nil` desactiva el tope. |
| `Limits.evidence_bytes` | `3 MiB` | Tamaño máximo de una captura de `screenshot-basic`. Se rechazan las que no sean un data URI JPEG (base64 válido con bytes mágicos de JPEG). |
| `RateLimit[evento]` | ver `config.lua` | Token bucket por jugador: `burst` acciones seguidas y `per_second` después. `default` aplica a los eventos sin regla propia y a los comandos. |

## `server/config.lua`

### `Config.Export` (anclaje off-box)

| Clave | Default | Descripción |
|---|---|---|
| `webhook` | `GetConvar('staff_suite_webhook', '')` | URL de un webhook de Discord. Se configura en `server.cfg` con `set staff_suite_webhook "URL"`. Vacío = desactivado. |
| `ticket_webhook` | `GetConvar('staff_suite_ticket_webhook', '')` | URL de un webhook de canal de texto en `https://discord.com/api/webhooks/…`. Configurá `set staff_suite_ticket_webhook "URL"` en `server.cfg`. Habilita **Exportar hilo a Discord** para quienes tengan `report.export`. El archivo de hasta 64 KiB contiene la descripción y los mensajes públicos del ticket. |
| `file` | `true` | Escribe cada ancla en `audit_export.log` (carpeta del resource). |
| `anchor_every` | `20` | Cada cuántas entradas se ancla el hash actual. |
| `webhook_retries` | `5` | Intentos del webhook por ancla ante 429, 5xx o sin respuesta. |
| `webhook_backoff_ms` / `webhook_backoff_max_ms` | `2000` / `60000` | Espera antes del primer reintento; se duplica en cada intento hasta el tope (respeta `Retry-After`). |

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

## Tema y marca

```lua
Config.Theme = 'light'   -- 'light' | 'dark' | 'auto'
Config.Brand = {
  name = 'Los Santos RP',            -- reemplaza "Staff Suite" en el panel (máx. 40)
  logo = 'brand/logo.png',           -- URL https:// o archivo en ui/public/brand/ (se copia a ui/dist/brand/ al compilar)
  accent = '#1d4ed8',                -- '#RRGGBB'; se ignora si no cumple contraste AA en el tema activo
}
```

`Config.Theme` es el tema por defecto. Cada staff puede elegir Claro, Oscuro o Automático en Ajustes, o cambiarlo con Ctrl+K; la preferencia queda en su cliente (KVP). Con el paquete de Tebex ya compilado, el logo local va directo en `ui/dist/brand/`.
