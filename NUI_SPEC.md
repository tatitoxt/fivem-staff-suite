# NUI_SPEC — Staff Suite Panel (React + TS + Vite)
**Para:** builder de la UI. **Objetivo:** panel in-game premium, ES/EN, dark-first, performante.
**Ubicación:** `fivem-staff-suite/ui/`. Build → `ui/dist/` (lo sirve el resource FiveM).

## Principios de diseño (buen diseño, no slop)
- Dark-first (el juego es oscuro), acento cyan/verde para "íntegro", rojo para "roto/alerta".
- Tipografía limpia (Inter/system), jerarquía clara, densidad de información alta pero legible.
- Microinteracciones sutiles (transiciones 150ms), sin animaciones gratuitas.
- Layout: sidebar de navegación + contenido. Responsive a 1280–1920px.
- Estados vacíos, loading y error bien resueltos. Cero "AI slop" (nada de emojis decorativos, gradientes morados genéricos, lorem ipsum).
- Español rioplatense neutro + inglés. Strings vía objeto de locale (no hardcode).

## Vistas (sidebar)
1. **Auditoría** (la estrella): timeline de entradas con seq, acción, actor→target, razón, timestamp, hash (truncado, expandible). Filtros por actor/acción/fecha. Badge de estado de cadena (íntegra/rota). Botón "Verificar cadena" → muestra resultado (ok / rota en seq N). Entrada rota resaltada en rojo.
2. **Tickets**: lista (estado, prioridad, reporter, claimer, antigüedad) + vista detalle (chat jugador↔staff, notas internas, acciones: claim/transfer/resolve/close/reopen, moderation buttons). Filtros por estado/prioridad.
3. **Dashboard** (dueño): KPIs (tickets abiertos/resueltos, tiempo respuesta promedio, rating promedio, staff on-duty), leaderboard de staff, alertas de anomalías.
4. **Duty**: toggle on/off duty propio, tabla de staff con horas/sesiones/resueltos/rating.
5. **Ajustes**: idioma, keybind, info de versión, estado de export Discord.

## Contrato NUI ↔ Lua (mensajes)
**Entrantes (SendNUIMessage → window event `message`):**
```ts
{type:"init", payload:{locale:"es", strings:{...}, version:"0.1.0", player:{name,rank,capabilities:string[]}, config:{...}}}
{type:"audit", payload:{entries:AuditEntry[], head:string, verify:{ok:boolean,broken_at:number|null}}}
{type:"tickets", payload:{tickets:Ticket[]}}
{type:"dashboard", payload:{kpis:{...}, leaderboard:StaffStat[], alerts:Alert[]}}
{type:"duty", payload:{self:{on_duty:boolean}, staff:StaffStat[]}}
{type:"toast", payload:{kind:"ok"|"error"|"info", text:string}}
```
**Salientes (fetch POST a `https://staff_suite/<action>` o window.nui.send):**
```
close_ui, set_locale{locale}, audit_verify, audit_filter{actor,action,from,to},
ticket_claim{id}, ticket_transfer{id,to}, ticket_resolve{id,resolution}, ticket_close{id},
ticket_reopen{id}, ticket_message{id,body,internal}, ticket_create{category,priority,body},
mod_action{action,target,reason,duration?}, duty_toggle, refresh
```
**Tipos:**
```ts
AuditEntry={seq,ts,actor,action,target,reason,payload,prev_hash,hash}
Ticket={id,reporter,category,priority,state,claimer,created_ts,updated_ts,messages:Msg[],resolution,rating}
Msg={author,body,ts,internal}
StaffStat={actor,on_duty,duty_hours,sessions,resolved,avg_response,avg_rating}
```

## Capa de abstracción (clave para testear sin juego)
`ui/src/nui.ts`:
- `send(action, payload)`: en FiveM hace `fetch("https://staff_suite/"+action, {method:"POST", body:JSON.stringify(payload)})`; en dev (import.meta.env.DEV) usa un **mock** que actualiza un store local con datos demo y devuelve respuestas simuladas.
- `subscribe(cb)`: escucha `window.addEventListener("message", e=>cb(e.data))`; en dev inyecta datos demo iniciales.
- Esto permite correr `npm run dev` y ver el panel COMPLETO con datos realistas sin FiveM.

## Datos demo (dev harness)
Generar ~40 audit entries (grants, bans, kicks, permission changes, algunos con razón), ~12 tickets en varios estados con chats, 6 staff con stats, 2 alertas de anomalía. Incluir un escenario de cadena rota para mostrar la detección.

## Stack y calidad
- React 18 + TypeScript + Vite. CSS modules o Tailwind (elegí, mantené consistente). Sin librerías de UI pesadas.
- Componentes tipados, sin `any` salvo borde NUI. Estado con hooks/context (sin Redux).
- `npm run build` debe producir dist/ limpio. `npm run dev` harness funcional.
- Tests: al menos un smoke test de render (vitest + testing-library) de las vistas principales con datos demo.

## Entregable
Código en ui/, build green, dev harness con datos demo, smoke tests green. NO commitear (el integrador commitea). Reportar: estructura, cómo correr dev/build, qué vistas están, screenshot mental del diseño.
