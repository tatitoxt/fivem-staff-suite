# FAQ y solución de problemas

## Preguntas frecuentes

**¿Reemplaza a txAdmin?**
No. Se monta encima: txAdmin sigue para noclip, god, spawn, bans, etc. Staff Suite cubre el flujo de trabajo del staff (reportes, moderación dentro del ticket, duty) y audita todo eso.

**¿Mi staff puede borrar o editar los logs?**
Quien tenga acceso a la base de datos o al archivo JSON puede modificarlos, pero la verificación lo detecta (la cadena se rompe en la primera entrada tocada). Para detectar también una reescritura completa o un borrado al final, activá el export off-box. Ver [Auditoría](auditoria.md).

**¿Captura todo lo que pasa en el server?**
Captura las acciones de Staff Suite, los eventos compatibles de ESX, QBCore, Qbox y txAdmin, y lo que otros recursos manden con el export `Record`.

**¿Necesito base de datos?**
Por defecto usa un archivo JSON. Para usar oxmysql con MySQL o MariaDB, aplicá la [migración de instalación](instalacion.md).

**¿Funciona con ESX, QBCore o Qbox?**
Sí. `Config.Framework = 'auto'` detecta Qbox, QBCore o ESX y lee los grupos/permisos según `Config.RankMap` y `Config.JobRankMap`. Sin framework usa ACE `staff_suite.<rango>`. Ver [Rangos y permisos](permisos.md).

**¿Cómo le doy rango a alguien en standalone?**
Con ACE en `server.cfg` (`add_ace group.admin staff_suite.admin allow` + `add_principal identifier.license:... group.admin`) o en `Config.StandaloneRanks` de `server/config.lua`.

**¿Dónde pongo el webhook de Discord?**
En `server.cfg`: `set staff_suite_webhook "URL"`, antes de `ensure staff_suite`. Usá `set`, no `setr`.

**¿Cómo cambio el idioma?**
`Config.Locale = 'es'` o `'en'` en `config.lua`. Los textos se editan en `locales/`.

**¿Impacta en el rendimiento?**
No hay loops por tick: el server tiene un solo hilo que guarda cada 60 segundos y el cliente no tiene loops. La medición con `resmon` está pendiente.

**¿Qué partes puedo editar si compro la versión con escrow?**
`config.lua`, `server/config.lua`, `locales/`, `sql/` y el panel (`ui/`) quedan abiertos. El resto (core y adapter) va cifrado por el escrow de Cfx **(próximamente)**.

**¿Qué diferencia hay entre Lite, Core e Integrity Pro?**
Ver la tabla de ediciones en el [README](../../README.md#ediciones).

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `[StaffSuite] módulo no encontrado: core.xxx` | Falta una carpeta o el resource está anidado de más. | Verificá que `core/`, `server/`, `shared/` estén directamente dentro de `staff_suite/`. |
| `Config.Framework inválido` al arrancar | Valor distinto de `auto`, `qbox`, `qbcore`, `esx`, `standalone`. | Corregí `Config.Framework`. |
| La consola dice `framework=qbcore` en un server Qbox (o al revés) | Hay más de un framework iniciado. | Forzá `Config.Framework = 'qbox'` (o el que corresponda). |
| Un admin no tiene permisos | Su grupo/permiso/ACE no está en `Config.RankMap`, todavía no cargó personaje, o en standalone le falta el ACE `staff_suite.<rango>`. | Agregá el mapeo; en standalone, el ACE o `Config.StandaloneRanks`. |
| `Config.StandaloneRanks` o los ACE `staff_suite.*` no hacen nada | Hay un framework activo: en ese modo solo cuenta el framework. | Mapealo en `Config.RankMap`/`Config.JobRankMap`, o forzá `'standalone'`. |
| `persistencia=oxmysql` pero los datos van al JSON | oxmysql no estaba iniciado cuando arrancó Staff Suite. | Poné `ensure oxmysql` **antes** de `ensure staff_suite` y revisá que conecte a la base. |
| Los exports `exports.staff_suite` no existen / el panel no responde | La carpeta no se llama `staff_suite`. | Renombrala a `staff_suite`. |
| Apreto `F6` y no aparece nada, o queda el cursor | Falta el panel compilado en `ui/dist/`. | Compilalo con `cd ui && npm ci && npm run build` o usá un paquete de release que lo incluya. Ver [Panel](panel.md#compilar-el-panel). |
| `/audit` en juego no muestra nada | El resultado se manda al panel, no al chat. | Usá `audit` en la consola del server o el panel. |
| Aparece el nombre de una clave (ej. `report_created`) en vez del texto | Falta la clave en los locales. | Agregala en `locales/es.lua` **y** `locales/en.lua` y corré `lua5.4 tests/run_all.lua`. |
| No llegan mensajes al webhook | Convar vacío, `set` después del `ensure`, URL inválida, o todavía no se llegó a la siguiente ancla. | Revisá `set staff_suite_webhook` antes de `ensure staff_suite`. Las anclas salen cada `anchor_every` entradas. |
| La verificación dice que la cadena está rota en N | Alguien editó, borró o reordenó entradas (también pasa si editaste el JSON/DB a mano). | Ver "Si la cadena aparece rota" en [Auditoría](auditoria.md). |
| `kick` responde "Se requiere una razón." | `Config.Moderation.require_reason = true`. | Indicá una razón, o desactivalo (no recomendado). |
| "El jugador seleccionado no está conectado." | El objetivo se desconectó o el id no existe. | Elegí un jugador conectado. |
| La transferencia de un ticket falla | El destinatario no está conectado o no tiene `report.claim` + `report.view`. | Transferí a un staff conectado con ese rango. |

## Limitaciones conocidas de 0.2.0

- En Core, la cola de tickets se abre desde el panel. Lite también registra `/reports`.
- `audit_export.log` queda en la misma máquina: copialo afuera para que sirva como prueba independiente.
