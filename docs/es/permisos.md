# Rangos y permisos

Staff Suite usa **capabilities** (permisos atómicos) agrupadas en **rangos**, con criterio de mínimo privilegio. Todo se valida en el server; el cliente nunca decide.

## Cómo se asigna el rango

Cada vez que un jugador hace algo, el server resuelve su rango con el bridge elegido por `Config.Framework` (ver [Instalación](instalacion.md#frameworks)). Un jugador **sin rango** no tiene capabilities: puede usar `/report` y nada más.

### Con framework (Qbox / QBCore / ESX)

Se recorre `Config.RankMap` y se pregunta al framework por cada clave:

| Framework | Pregunta |
|---|---|
| Qbox | `IsPlayerAceAllowed(src, clave)`. Ej.: `add_ace group.admin admin allow` → `admin`. |
| QBCore | `QBCore.Functions.HasPermission(src, clave)`. |
| ESX | `xPlayer.getGroup() == clave`. |

Además, si el job activo del jugador está en `Config.JobRankMap.<framework>`, ese rango también cuenta. Si coinciden varios, **gana el más alto**. Con framework activo, los ACE `staff_suite.<rango>` y `Config.StandaloneRanks` **no** se usan.

### Standalone

Dos fuentes, gana la más alta:

1. ACE `staff_suite.<rango>` en `server.cfg`:
   ```cfg
   add_ace group.admin staff_suite.admin allow
   add_principal identifier.license:1234abcd... group.admin
   ```
2. `Config.StandaloneRanks` en `server/config.lua`, por identificador `license:...`.

Rangos válidos: `helper`, `moderator`, `admin`, `senior_admin`, `owner`. Un rango con otro nombre se ignora.

## Rangos

| Rango | Resumen |
|---|---|
| `helper` | Ve y atiende reportes, chat, duty. |
| `moderator` | + resolver/transferir reportes, moderación básica, ver auditoría. |
| `admin` | + verificar la cadena, analytics de staff. |
| `senior_admin` | + capabilities reservadas para export y configuración. |
| `owner` | Todas las capabilities. |

## Matriz de capabilities

| Capability | helper | moderator | admin | senior_admin | owner |
|---|:-:|:-:|:-:|:-:|:-:|
| `report.view` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `report.claim` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `report.message` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `report.resolve` | | ✓ | ✓ | ✓ | ✓ |
| `mod.goto` / `mod.bring` / `mod.spectate` | | ✓ | ✓ | ✓ | ✓ |
| `mod.freeze` / `mod.heal` | | ✓ | ✓ | ✓ | ✓ |
| `mod.kick` / `mod.warn` | | ✓ | ✓ | ✓ | ✓ |
| `mod.revive` / `mod.ban` | | | ✓ | ✓ | ✓ |
| `audit.view` | | ✓ | ✓ | ✓ | ✓ |
| `audit.verify` | | | ✓ | ✓ | ✓ |
| `audit.export` | | | | ✓ | ✓ |
| `staff.duty` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `staff.analytics` | | | ✓ | ✓ | ✓ |
| `admin.config` | | | | ✓ | ✓ |
| `admin.permissions` | | | | | ✓ |

Fuente: `core/permissions.lua`.

## Qué controla cada capability

| Capability | Controla |
|---|---|
| `report.view` | recibir la cola de tickets en el panel |
| `report.claim` | reclamar, empezar y soltar un ticket; poder recibir una transferencia |
| `report.resolve` | transferir, resolver, cerrar y reabrir |
| `report.message` | escribir en el ticket (junto con `report.view`), incluidas notas internas |
| `mod.<acción>` | acciones de moderación desde el panel |
| `audit.view` | ver las entradas de auditoría en el panel y `/audit` en juego |
| `audit.verify` | botón "Verificar cadena" del panel (deja una entrada `audit_verify`) |
| `staff.duty` | `/duty` |
| `staff.analytics` | estadísticas de duty del staff y alertas (ej. cadena rota) |
| `audit.export`, `admin.config`, `admin.permissions` | definidas en el modelo, sin uso todavía **(próximamente)** |

El panel recibe solo los datos que permiten las capabilities del jugador. `/report` no pide capability.

Una transferencia solo se acepta si el destinatario está conectado y tiene `report.claim` y `report.view`.

## Moderación

Cada acción pasa por: chequeo de capability → jugador objetivo conectado (por server id o identificador) → razón obligatoria para `kick` (si `Config.Moderation.require_reason`) → ejecución → entrada en la auditoría (`mod_<acción>`).

| Acción | Estado en 0.1.0 |
|---|---|
| `goto`, `bring`, `freeze`, `heal`, `kick` | Funcionan. |
| `ban`, `warn`, `spectate`, `revive` | Deshabilitadas: responden "Esta acción de moderación no está disponible.", no se auditan y el panel no las ofrece **(próximamente)**. |
| Descongelar (`unfreeze`) | **(próximamente)** |

Staff Suite **no** reemplaza a txAdmin: noclip, god mode, spawn, ban, etc. siguen en txAdmin o tu framework.

## Overrides por persona (próximamente)

El core ya soporta dar o quitar una capability puntual a un identificador por encima de su rango (`revoke` gana sobre `grant`, y `grant` sobre el rango). Todavía no hay comando ni pantalla para administrarlos **(próximamente)**.
