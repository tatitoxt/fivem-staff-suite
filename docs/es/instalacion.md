# Instalación

> Versión documentada: **0.1.0**. Lo marcado como **(próximamente)** está planeado pero todavía no está implementado.

## Requisitos

| Requisito | ¿Obligatorio? | Notas |
|---|---|---|
| FXServer reciente con Lua 5.4 | Sí | El resource usa `fx_version 'cerulean'` y `lua54 'yes'`. |
| [oxmysql](https://github.com/overextended/oxmysql) + MySQL/MariaDB | No | Solo si querés guardar los datos en base de datos. Sin oxmysql se usa un archivo JSON. |
| Framework (ESX / QBCore / Qbox) | No | El resource corre standalone. Ver [Frameworks](#frameworks). |
| ox_lib | No | No se usa en 0.1.0. |

## 1. Copiar el resource

Copiá la carpeta a tu directorio de resources **con el nombre exacto `staff_suite`**:

```
resources/
└── [staff]/
    └── staff_suite/
        ├── fxmanifest.lua
        ├── config.lua
        ├── core/  locales/  server/  client/  shared/
        └── ui/dist/        ← panel NUI compilado
```

El nombre importa: los callbacks del panel (`https://staff_suite/...`) y los exports (`exports.staff_suite`) usan ese nombre.

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

ensure staff_suite
```

Orden: oxmysql → framework → `staff_suite`.

## 4. Primer arranque

En la consola del server tenés que ver:

```
[StaffSuite] iniciado · 0 entradas de auditoría · persistencia=json
```

(o `persistencia=oxmysql`). Probá la cadena desde la consola:

```
audit
```

→ `[StaffSuite] audit OK: N entries`.

## Frameworks

| Framework | Estado en 0.1.0 |
|---|---|
| Standalone | Funciona. Es el modo actual para todos los servers. |
| ESX Legacy | Bridge escrito (`server/bridges/esx.lua`), **todavía no conectado** al resource **(próximamente)**. |
| QBCore | Bridge escrito (`server/bridges/qbcore.lua`), **todavía no conectado** **(próximamente)**. |
| Qbox (`qbx_core`) | Bridge escrito (`server/bridges/qbox.lua`), **todavía no conectado** **(próximamente)**. |

Podés tener cualquiera de esos frameworks corriendo: Staff Suite no choca con ellos, pero en 0.1.0 todavía no lee sus grupos ni usa sus funciones de kick/ban.

> **Importante (0.1.0):** hoy todos los jugadores reciben el rango de `Config.StandaloneRank`, que viene en `'owner'` (todas las capabilities). Usá esta versión en un server de pruebas hasta que llegue el mapeo de rangos por framework/ACE. Más detalles en [Rangos y permisos](permisos.md).

## Comandos

| Comando | Quién | Qué hace |
|---|---|---|
| `/report <categoría> <descripción>` | Cualquier jugador | Crea un reporte. Ej.: `/report bug me caí del mapa`. |
| `/duty` | Capability `staff.duty` | Entra/sale de servicio y registra el turno. |
| `/audit` | Capability `audit.view` (o consola) | Verifica la cadena. En consola imprime el resultado; en juego lo manda al panel. |
| `/staffsuite` o tecla `F6` | Staff | Abre el panel NUI. |

Los nombres de `/report`, `/duty` y `/audit` se cambian en `Config.Commands`. Ver [Configuración](configuracion.md).

## Siguiente paso

- [Configuración](configuracion.md)
- [Rangos y permisos](permisos.md)
- [Auditoría: export y verificación](auditoria.md)
- [FAQ y solución de problemas](faq.md)
