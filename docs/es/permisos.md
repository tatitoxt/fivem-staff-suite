# Rangos y permisos

Staff Suite usa **capabilities** (permisos atómicos) agrupadas en **rangos**, con criterio de mínimo privilegio. Todo se valida en el server; el cliente nunca decide.

## Estado en 0.1.0

> **Leé esto antes de usarlo en producción.** En 0.1.0 todos los jugadores reciben el rango definido en `Config.StandaloneRank` (default `'owner'` = todas las capabilities). El mapeo de rangos por framework o ACE todavía no está conectado **(próximamente)**. Hasta entonces, usalo en un server de pruebas o con jugadores de confianza.

Bajar `Config.StandaloneRank` (por ejemplo a `'helper'`) limita a **todos** por igual, incluido vos.

## Rangos

| Rango | Resumen |
|---|---|
| `helper` | Ve y atiende reportes, chat, duty. |
| `moderator` | + resolver reportes, moderación básica (goto/bring/spectate/freeze/heal/kick/warn), ver auditoría. |
| `admin` | + revive, ban, verificar la cadena, analytics de staff. |
| `senior_admin` | + exportar auditoría, configuración. |
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

## Qué controla cada capability hoy

| Capability | Se usa en 0.1.0 para |
|---|---|
| `staff.duty` | `/duty` |
| `audit.view` | `/audit` en juego |
| `audit.verify` | botón "Verificar cadena" del panel (deja una entrada `audit_verify`) |
| `report.claim` | todas las acciones sobre tickets desde el panel (reclamar, transferir, resolver, cerrar, reabrir) |
| `mod.<acción>` | acciones de moderación desde el panel |
| `report.view`, `report.resolve`, `report.message`, `audit.export`, `staff.analytics`, `admin.config`, `admin.permissions` | definidas en el modelo; su control fino llega con el panel **(próximamente)** |

`/report` no pide capability: cualquier jugador puede reportar.

## Moderación

Cada acción de moderación pasa por: chequeo de capability → razón obligatoria (si `Config.Moderation.require_reason` y la acción es `kick`, `ban` o `warn`) → ejecución → entrada en la auditoría (`mod_<acción>`).

| Acción | Estado en 0.1.0 |
|---|---|
| `goto`, `bring`, `freeze`, `heal`, `kick` | Funcionan. |
| `ban`, `warn`, `spectate`, `revive` | Se validan y quedan en la auditoría, pero todavía no ejecutan nada en el juego **(próximamente)**. |
| Descongelar (`unfreeze`) | **(próximamente)** |

Staff Suite **no** reemplaza a txAdmin: noclip, god mode, spawn, etc. siguen en txAdmin.

## Overrides por persona (próximamente)

El core ya soporta dar o quitar una capability puntual a un identificador (`license:...`) por encima de su rango (`revoke` gana sobre `grant`, y `grant` sobre el rango). Todavía no hay comando ni pantalla para administrarlos **(próximamente)**.

## Mapeo por framework / ACE (próximamente)

Los bridges ya escritos van a mapear así cuando se conecten:

| Fuente | Mapeo |
|---|---|
| ESX | grupo del jugador → `Config.RankMap` |
| QBCore / Qbox | permiso `god` → `owner`, `admin` → `admin`, `mod` → `moderator` |
| Standalone (ACE) | `staff_suite.owner`, `staff_suite.senior_admin`, `staff_suite.admin`, `staff_suite.moderator`, `staff_suite.helper` |
