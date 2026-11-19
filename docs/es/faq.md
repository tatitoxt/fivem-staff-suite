# FAQ y solución de problemas

## Preguntas frecuentes

**¿Reemplaza a txAdmin?**
No. Se monta encima: txAdmin sigue para noclip, god, spawn, etc. Staff Suite cubre el flujo de trabajo del staff (reportes, moderación dentro del ticket, duty) y audita todo eso.

**¿Mi staff puede borrar o editar los logs?**
Quien tenga acceso a la base de datos o al archivo JSON puede modificarlos, pero la verificación lo detecta (la cadena se rompe en la primera entrada tocada). Para detectar también una reescritura completa o un borrado al final, activá el export off-box. Ver [Auditoría](auditoria.md).

**¿Captura todo lo que pasa en el server?**
No, y no lo prometemos. Captura el 100% de lo que pasa por Staff Suite, los comandos de `Config.Audit.capture_commands` y lo que otros resources manden con el export `Record`. La captura de eventos del framework y de logs de txAdmin está **(próximamente)**.

**¿Necesito base de datos?**
No. Sin oxmysql usa un archivo JSON. Con oxmysql + MySQL/MariaDB guarda en la tabla `staff_state`.

**¿Funciona con ESX, QBCore o Qbox?**
Corre en servers con esos frameworks, pero en 0.1.0 todavía no lee sus grupos: todos reciben `Config.StandaloneRank`. Los bridges están escritos y se conectan **(próximamente)**. Ver [Rangos y permisos](permisos.md).

**¿Cómo cambio el idioma?**
`Config.Locale = 'es'` o `'en'` en `config.lua`. Los textos se editan en `locales/`.

**¿Impacta en el rendimiento?**
No hay loops por tick: el server tiene un solo hilo que guarda cada 60 segundos y el cliente no tiene loops. La medición con `resmon` está pendiente.

**¿Qué partes puedo editar si compro la versión con escrow?**
`config.lua`, `locales/` y el panel (`ui/`) quedan abiertos. El resto (core y adapter) va cifrado por el escrow de Cfx.

**¿Qué diferencia hay entre Lite, Core e Integrity Pro?**
Ver la tabla de ediciones en el [README](../../README.md#ediciones).

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `[StaffSuite] módulo no encontrado: core.xxx` | Falta una carpeta o el resource está anidado de más. | Verificá que `core/`, `server/`, `shared/` estén directamente dentro de `staff_suite/`. |
| La consola dice `persistencia=json` aunque configuré oxmysql | oxmysql no estaba iniciado cuando arrancó Staff Suite. | Poné `ensure oxmysql` **antes** de `ensure staff_suite` y revisá que oxmysql conecte a la base. |
| Los exports `exports.staff_suite` no existen / el panel no responde | La carpeta no se llama `staff_suite`. | Renombrala a `staff_suite`. |
| Apreto `F6` y no aparece nada, o queda el cursor | Falta el panel compilado en `ui/dist/`. | Usá un paquete de release que incluya `ui/dist/`. Mientras tanto, usá los comandos. |
| `/audit` en juego no muestra nada | En 0.1.0 el resultado se manda al panel, no al chat. | Usá `audit` en la consola del server o el panel. |
| Aparece el nombre de una clave (ej. `report_created`) en vez del texto | Falta la clave en el locale elegido. | Agregala en `locales/es.lua` **y** `locales/en.lua` y corré `lua5.4 tests/run_all.lua`. |
| Un comando de otro resource (`ban`, `kick`, `warn`, `giveitem`, `givemoney`, `setjob`) dejó de andar | Choca con la captura de comandos. | `Config.Audit.capture_commands = false`. |
| Los comandos capturados no se registran | Son comandos restringidos: requieren el ACE `command.<nombre>`. | Dale el ACE al grupo de staff en `server.cfg`, ej. `add_ace group.admin command.kick allow`. |
| No llegan mensajes al webhook | URL vacía o inválida, o todavía no se llegó a la siguiente ancla. | Revisá `Config.Export.webhook`. Las anclas salen cada `anchor_every` entradas, no por cada acción. |
| La verificación dice `BROKEN at N` | Alguien editó, borró o reordenó entradas (también pasa si editaste el JSON/DB a mano). | Ver "Si la cadena aparece rota" en [Auditoría](auditoria.md). |
| `kick`/`ban`/`warn` responde "Se requiere una razón." | `Config.Moderation.require_reason = true`. | Indicá una razón, o desactivalo (no recomendado). |
| `ban`/`warn`/`spectate`/`revive` quedan en la auditoría pero no pasa nada en el juego | En 0.1.0 todavía no ejecutan acción **(próximamente)**. | Por ahora hacé el ban desde txAdmin o tu framework. |

## Limitaciones conocidas de 0.1.0

- Todos los jugadores reciben `Config.StandaloneRank` (default `owner`).
- `config.lua` llega al cliente: la URL del webhook es visible para jugadores con conocimientos.
- El panel pide el estado completo (tickets y auditoría) sin chequear permisos; el chequeo está **(próximamente)**.
- `audit_export.log` queda en la misma máquina: copialo afuera para que sirva como prueba independiente.
