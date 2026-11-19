# Instalación

> Versión documentada: **0.1.0**. Lo marcado como **(próximamente)** está planeado pero todavía no está implementado.

## Requisitos

| Requisito | ¿Obligatorio? | Notas |
|---|---|---|
| FXServer reciente con Lua 5.4 | Sí | El resource usa `fx_version 'cerulean'` y `lua54 'yes'`. |
| [oxmysql](https://github.com/overextended/oxmysql) + MySQL/MariaDB | No | Solo si querés guardar los datos en base de datos. Sin oxmysql se usa un archivo JSON. |
| Framework (ESX / QBCore / Qbox) | No | Se detecta solo. Sin framework funciona en modo standalone con ACE. Ver [Frameworks](#frameworks). |
| Node.js 18+ | Solo desde el código fuente | Para compilar el panel (`ui/dist/`). Los paquetes de release ya lo traen compilado. |
| ox_lib | No | No se usa en 0.1.0. |

## 1. Copiar el resource

Copiá la carpeta a tu directorio de resources **con el nombre exacto `staff_suite`**:

```
resources/
└── [staff]/
    └── staff_suite/
        ├── fxmanifest.lua
        ├── config.lua          ← config pública (cliente + server)
        ├── server/config.lua   ← config privada (solo server)
        ├── core/  locales/  server/  client/  shared/
        └── ui/dist/            ← panel NUI compilado
```

El nombre importa: los callbacks del panel (`https://staff_suite/...`) y los exports (`exports.staff_suite`) usan ese nombre.

Si bajaste el código fuente y no un paquete de release, `ui/dist/` no viene incluido: compilalo con Node.js 18+ (`cd ui && npm ci && npm run build`). Ver [Panel](panel.md#compilar-el-panel).

## 2. Elegir la persistencia

### Opción A — Archivo JSON (sin base de datos)

Es el default (`Config.Persistence = 'json'`). No necesitás nada más. Los datos se guardan en `staff_suite_data.json` dentro de la carpeta del resource.

### Opción B — oxmysql + MySQL/MariaDB

1. Instalá y configurá oxmysql según su documentación (convar `mysql_connection_string` en tu `server.cfg`).
2. En `config.lua`:
   ```lua
   Config.Persistence = 'oxmysql'
   ```
3. Al arrancar, Staff Suite crea sola la tabla `staff_state` (no hay que importar SQL a mano).

**Fallback automático:** si `Config.Persistence = 'oxmysql'` pero oxmysql no está iniciado cuando arranca Staff Suite, se usa el archivo JSON. Por eso oxmysql tiene que estar en `ensure` **antes** que `staff_suite`.

## 3. server.cfg

```cfg
# base de datos (opcional)
set mysql_connection_string "mysql://usuario:clave@localhost/mi_server?charset=utf8mb4"
ensure oxmysql

# tu framework (opcional): es_extended / qb-core / qbx_core
ensure qb-core

# webhook de Discord para las anclas de auditoría (opcional). Usá set, no setr.
set staff_suite_webhook "https://discord.com/api/webhooks/..."

# standalone: rangos por ACE (ver Rangos y permisos)
add_ace group.admin staff_suite.admin allow

ensure staff_suite
```

Orden: oxmysql → framework → convars de Staff Suite → `staff_suite`. El webhook se lee al cargar el resource, así que el `set` tiene que ir antes del `ensure`.

## 4. Primer arranque

En la consola del server tenés que ver:

```
[StaffSuite] iniciado · 0 entradas de auditoría · persistencia=json · framework=standalone
```

`persistencia` muestra lo configurado (`json` u `oxmysql`) y `framework` el bridge elegido. Probá la cadena desde la consola:

```
audit
```

→ `[StaffSuite] auditoría OK: N entradas`.

## Frameworks

`Config.Framework = 'auto'` (default) elige el primero que esté iniciado, en este orden: **Qbox → QBCore → ESX → standalone**. Si tenés más de uno (por ejemplo Qbox con la capa de compatibilidad de qb-core), forzalo con `'qbox'`, `'qbcore'`, `'esx'` o `'standalone'`.

| Framework | Resource | De dónde sale el rango | Nombre mostrado |
|---|---|---|---|
| Qbox | `qbx_core` | ACE con el nombre de cada clave de `Config.RankMap` (`IsPlayerAceAllowed(src, 'admin')`), más `Config.JobRankMap.qbox` | nombre y apellido del personaje |
| QBCore | `qb-core` | `QBCore.Functions.HasPermission(src, <clave de RankMap>)`, más `Config.JobRankMap.qbcore` | nombre y apellido del personaje |
| ESX Legacy | `es_extended` | grupo del xPlayer (`getGroup()`) comparado con las claves de `Config.RankMap`, más `Config.JobRankMap.esx` | `getName()` |
| Standalone | — | ACE `staff_suite.<rango>` y `Config.StandaloneRanks` (en `server/config.lua`) | nombre de FiveM |

El detalle de cómo se arma el rango está en [Rangos y permisos](permisos.md).

Con un framework activo, si el jugador todavía no cargó personaje, queda sin rango (solo puede usar `/report`) hasta que cargue.

## Comandos

| Comando | Quién | Qué hace |
|---|---|---|
| `/report <categoría> <descripción>` | Cualquier jugador | Crea un reporte. La primera palabra es la categoría; si no está en `Config.Categories`, queda como `other`. Ej.: `/report bug me caí del mapa`. |
| `/duty` | Capability `staff.duty` | Entra/sale de servicio y registra el turno. |
| `/audit` | Capability `audit.view` (o consola) | Verifica la cadena. En consola imprime el resultado; en juego lo manda al panel. |
| `/staffsuite` o tecla `F6` | Cualquiera | Abre el panel NUI. Cada jugador ve solo lo que sus capabilities permiten. |

Los nombres de `/report`, `/duty` y `/audit` se cambian en `Config.Commands`. Ver [Configuración](configuracion.md).

## Siguiente paso

- [Configuración](configuracion.md)
- [Rangos y permisos](permisos.md)
- [Panel (NUI)](panel.md)
- [Auditoría: export y verificación](auditoria.md)
- [FAQ y solución de problemas](faq.md)
