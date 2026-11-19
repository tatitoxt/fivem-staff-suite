# Auditoría: export off-box y verificación de la cadena

## Cómo funciona la cadena

Cada acción queda como una entrada con `seq`, `ts`, `actor`, `action`, `target`, `reason`, `payload`, `prev_hash` y `hash`. Cada `hash` incluye el `hash` de la entrada anterior:

```
hash = SHA-256( seq ␟ ts ␟ actor ␟ action ␟ target ␟ reason ␟ payload ␞ prev_hash )
```

- `␟` = byte `0x1F`, `␞` = byte `0x1E`; el resultado va en hex minúscula (64 caracteres).
- La primera entrada usa como `prev_hash` 64 ceros (génesis).

Si alguien edita un campo, borra una entrada del medio o cambia el orden, los hashes dejan de coincidir y la verificación marca la primera entrada rota.

## Qué se registra (0.1.0)

| Acción | Origen |
|---|---|
| `ticket_create`, `ticket_claim`, `ticket_unclaim`, `ticket_transfer`, `ticket_start`, `ticket_resolve`, `ticket_close`, `ticket_reopen` | reportes (`/report`, panel y export `TicketAction`) |
| `ticket_message` | mensajes del ticket (el `payload` dice si es nota interna, no el texto) |
| `mod_<acción>` | moderación desde el panel (`goto`, `bring`, `freeze`, `heal`, `kick`, `ban`, `warn`, `spectate`, `revive`) |
| `duty.in`, `duty.out` | `/duty` y el export `SetDuty` |
| `audit_verify` | verificación desde el panel (con resultado en `reason`) |
| `framework_job`, `framework_group`, `framework_item_added`, `framework_money` | eventos del framework activo con `Config.Audit.capture_framework = true` |
| `txadmin_ban`, `txadmin_kick`, `txadmin_warn`, `txadmin_heal` | eventos de txAdmin con la misma opción |
| lo que mande otro resource | export `Record` (ver abajo) |

La cobertura externa depende de los eventos que emite cada recurso y su versión. Los eventos de framework pueden identificar al jugador afectado sin informar quién hizo el cambio. Para registrar operaciones de otros recursos, usá el export `Record`.

## Verificar la cadena

| Dónde | Cómo | Requiere |
|---|---|---|
| Consola del server | `audit` → `[StaffSuite] auditoría OK: N entradas` o `auditoría ROTA en la entrada <seq>` | acceso a consola |
| En juego | `/audit` (resultado al panel) | `audit.view` |
| Panel | botón "Verificar cadena" | `audit.verify` |
| Panel (alerta) | si la cadena está rota, el panel muestra una alerta | `staff.analytics` |
| Otro resource (server) | `local ok, seq = exports.staff_suite:Verify()` | — |

`verify` recalcula toda la cadena desde la génesis. Sola **no** detecta dos casos: que borren las últimas entradas o que reescriban la cadena completa recalculando todos los hashes. Para eso están las anclas off-box.

## Export off-box (anclas)

Cada `Config.Export.anchor_every` entradas (default 20, o sea `seq` 20, 40, 60…; se configura en `server/config.lua`) Staff Suite ancla la entrada actual:

- **Archivo** (`Config.Export.file = true`): agrega una línea a `audit_export.log` en la carpeta del resource:
  ```
  seq|hash|prev_hash|action
  40|9f2c…e1|51ab…07|ticket_resolve
  ```
  Este archivo está en la misma máquina: para que sirva como prueba, copialo afuera del server (backup, otro host, nube). Una copia que el staff con acceso al server no puede tocar es la que vale.
- **Discord** (`set staff_suite_webhook "URL"` en `server.cfg`, leído en `server/config.lua`): manda un mensaje con el `seq` y los primeros 16 caracteres del hash. Los mensajes de Discord quedan con fecha y fuera de tu server. Usá `set`, no `setr`, para que la URL no llegue a los clientes.

### Comparar contra un ancla

Para cada ancla (`seq`, `hash`) guardada afuera, el `hash` de la entrada con ese `seq` en la cadena actual tiene que ser **el mismo** (para Discord, que empiece igual). Si no coincide, o si la cadena tiene menos entradas que el último `seq` anclado, la historia fue reescrita o truncada.

Ejemplo de chequeo desde un resource propio (server-side):

```lua
RegisterCommand('ss_checkanchor', function(src, args)
  if src ~= 0 then return end -- solo consola
  local seq, expected = tonumber(args[1]), args[2]
  local e = exports.staff_suite:GetChain()[seq]
  if not e then print('falta la entrada ' .. seq .. ': cadena truncada'); return end
  print(e.hash:sub(1, #expected) == expected and 'ancla OK' or 'ancla NO coincide')
end, true)
```

Uso en consola: `ss_checkanchor 40 9f2c1a...`.

La comparación automática contra el ancla (el core ya tiene `verify_head`) y una herramienta de verificación offline están **(próximamente)**.

## Exports para otros resources (server-side)

| Export | Descripción |
|---|---|
| `Record(action, actor, target, reason, payload)` | Agrega una entrada. `payload` es una tabla (se guarda como JSON). Devuelve la entrada. |
| `Verify()` | `ok, seq_roto` |
| `GetChain()` | Copia de todas las entradas. |
| `CreateTicket(data)` | Crea un ticket (`reporter`, `category`, `priority`, `description`, `ts`). Devuelve el id. |
| `TicketAction(id, action, actor, extra)` | Transición de ticket (`claim`, `unclaim`, `transfer`, `start`, `resolve`, `close`, `reopen`) y su entrada en la auditoría. Devuelve `ticket, evento` o `nil, error`. Para `transfer`, `extra.to` es el identificador del destinatario. |
| `GetState()` | Estado completo (cadena, tickets, permisos, duty). |
| `SetDuty(actor, onDuty)` | Entrada (`true`) o salida (`false`) de servicio con su entrada `duty.in`/`duty.out`. Devuelve el evento o `nil, error`. |

Ejemplo:

```lua
exports.staff_suite:Record('grant_money', 'license:abc', 'license:def', 'premio evento', { amount = 5000 })
```

La cadena prueba que una entrada **no se tocó después de escrita**, no que lo que reportó el otro resource sea cierto. Llamá a `Record` solo desde scripts de confianza.

## Si la cadena aparece rota

1. No toques nada más. Anotá el `seq` que informa la verificación.
2. Compará con tu última copia off-box de `audit_export.log` y con los mensajes del webhook.
3. Revisá quién tuvo acceso a la base de datos o a `staff_suite_data.json` en ese período.
4. Para seguir operando, restaurá el backup íntegro más reciente. Editar el archivo a mano para "arreglarla" deja la cadena rota igual: es lo esperado.
