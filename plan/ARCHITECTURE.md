# ARCHITECTURE — Staff Suite (Producto 1)
**v0.2 · 18/11/2026 · Stack: Lua (FiveM) + React/TS (NUI) + MySQL/MariaDB**

## Principios
1. **Standalone-first**: corre sin framework; bridges opcionales ESX/QBCore/Qbox (auto-detect).
2. **Server-authoritative**: toda validación, permiso y write ocurre server-side. El cliente nunca es confiable.
3. **Event-driven**: cero polling loops. Captura por eventos/comandos; writes a DB batched.
4. **Open config + NUI + locales**: el core cerrado va en escrow; lo editable queda abierto (patrón del mercado, anti-escrow sentiment).
5. **Performance budget**: <0.05ms idle en cliente (resmon), server sin loops por tick. Se mide en cada release.
6. **Dependencias mínimas**: oxmysql (opcional, fallback JSON en standalone lite), ox_lib (opcional). Nada más.
7. **Portabilidad GTA VI (D019)**: separar **core agnóstico de plataforma** (lógica de negocio pura, sin natives) del **adapter fino** (natives FiveM, NUI, bridges). El core es el activo que se porta a la Creator Platform de GTA VI cuando se anuncie; el adapter se reescribe. No sobre-ingenierizar un framework multi-plataforma ahora (YAGNI) — solo mantener la frontera limpia.

## Portabilidad GTA VI (D019) — qué se porta y qué no
| Capa | Contenido | ¿Portable a GTA VI? |
|---|---|---|
| **Core agnóstico** | hash-chain audit, state machine de tickets, modelo de permisos, analytics, orquestación IA (prompts/memoria/trust/costguard/fallback) | ✅ Sí — lógica pura + spec + tests. Si la plataforma es Lua-based (el equipo de FiveM está en Rockstar), se porta casi directo; si es otro SDK, se reimplementa desde la spec |
| **Adapter de plataforma** | natives FiveM (GetPlayerPed, TriggerEvent…), NUI bridge, oxmysql, bridges ESX/QB, hooks de captura | ❌ Se reescribe para el SDK de GTA VI |
| **Activos de negocio** | marca, reputación, distribución (audiencia/creator codes/Discord), relaciones con clientes, demanda validada | ✅✅ 100% transferible — es el 70% del valor real |

**Producto 2 (NPCs IA) es el MÁS portable:** el "cerebro" IA (orquestación LLM, personalidad, memoria, trust, cost guards) es 100% agnóstico — puede correr hasta como servicio aparte. Solo la "encarnación" (spawn del NPC, audio espacial, leer contexto del mundo, disparar acciones) es específica de plataforma. ~80% del producto se porta.

**Estrategia:** FiveM genera cash-flow + reputación + audiencia AHORA. Cuando se anuncie la Creator Platform de GTA VI (trigger, no fecha), se portea el adapter y se relanza con la marca/audiencia existente — siendo early en un mercado donde la competencia se resetea a cero.

## Estructura del resource
```
staff_suite/
├── fxmanifest.lua
├── config.lua                  # ABIERTO — toda la configuración
├── locales/                    # ABIERTO — es.lua, en.lua
├── shared/
│   ├── constants.lua           # eventos, estados, capabilities
│   └── schema.lua              # forma canónica de entradas de auditoría
├── server/
│   ├── main.lua                # lifecycle, exports, version check
│   ├── audit/
│   │   ├── capture.lua         # hooks de eventos/comandos/txAdmin
│   │   ├── chain.lua           # hash-chain SHA-256 (Lua puro)
│   │   ├── storage.lua         # oxmysql + fallback JSON
│   │   └── export.lua          # webhook Discord + archivo append-only
│   ├── reports/
│   │   ├── tickets.lua         # state machine + claim + chat
│   │   └── analytics.lua       # métricas, leaderboard, duty
│   ├── moderation/
│   │   └── actions.lua         # registry de acciones: permiso + razón + bridge call
│   ├── permissions/
│   │   └── ranks.lua           # capability map, least-privilege
│   ├── integrity/              # PRO (suscripción)
│   │   ├── inventory.lua       # ACE + txAdmin + framework + Discord
│   │   ├── flags.lua           # anomalías
│   │   ├── cases.lua           # case files
│   │   └── appeals.lua         # patrones
│   └── bridges/
│       ├── esx.lua / qbcore.lua / qbox.lua / standalone.lua
├── client/
│   ├── main.lua                # NUI bridge, keybinds, ox_target/qb-target opcional
│   └── callbacks.lua           # NUI → server (validado)
├── ui/                         # ABIERTO — React + TS + Vite → build estático
│   ├── src/ (panel, timeline, ticket-view, dashboard)
│   └── dist/                   # servido por el resource
└── sql/                        # migraciones versionadas
```

## Audit log + hash-chain (el diferencial)
**Entrada canónica:**
```lua
{ seq, ts, actor = {license, discord, name}, action, target = {license, name},
  reason, payload = {...}, prev_hash, hash }
-- hash = SHA256(canonical_json(entry sin hash) .. prev_hash)
```
- SHA-256 en Lua puro server-side (volumen de logs: miles/día, costo despreciable).
- Genesis entry al primer arranque; head persistido en DB.
- **Anclaje off-box**: cada N minutos o cada X entradas, export del head hash + entradas nuevas a webhook Discord y archivo append-only. La copia fuera del server permite verificar aunque el staff comprometa la DB.
- **Verificación**: comando/export `verifyChain()` recomputa toda la cadena; mismatch → alerta al owner + flag en dashboard.
- **Honestidad de captura** (documentada en el producto): acciones del propio panel 100%; eventos framework vía bridges (ESX/QB events); txAdmin best-effort (parseo de sus logs de archivo). No prometemos interceptar lo que no es interceptable server-side.

## Data model (MySQL/MariaDB, migraciones en sql/)
| Tabla | Contenido |
|---|---|
| `staff_audit` | entradas de la cadena (seq, hash, payload JSON) |
| `staff_tickets` | id, reporter, categoría, prioridad, estado, claimer, timestamps |
| `staff_messages` | chat por ticket (autor, body, interno flag) |
| `staff_duty` | turnos on/off, horas acumuladas |
| `staff_stats` | agregados por staff (resueltos, tiempo respuesta, ratings) |
| `staff_permissions` | PRO: inventario cross-system + vencimientos |
| `staff_cases` | PRO: case files + apelaciones |

## Reports — state machine
`open → claimed → (in_progress) → resolved → closed` (+ `reopened`).
Claim con lock (un staff por ticket), transfer, notas internas, canned responses, rating del jugador al resolver. Todo transición = entrada de auditoría.

## Moderación — action registry
Cada acción = `{capability, handler, requires_reason, audit_payload}`. El dispatcher verifica permiso server-side y motivo antes de ejecutar. Acciones Core: goto/bring/spectate/freeze/heal/revive/kick/ban/warn. Core también ofrece noclip e invisibilidad sobre el propio personaje, con autorización y auditoría previa. God y spawn se delegan a txAdmin.

## NUI
- React + TypeScript + Vite (estándar del mercado, AI-friendly para iterar).
- Protocolo: `SendNUIMessage` / `RegisterNUICallback` con tipos compartidos.
- **Browser harness**: la UI se testea en Chromium con mocks de SendNUIMessage (sin juego).
- Tema oscuro por default, ES/EN, responsive a resoluciones comunes.

## Seguridad
- NUI callbacks: validar source + permiso + rate limit server-side, siempre.
- SQL parametrizado (oxmysql). Secretos en convars `set` (nunca `setr`).
- Permisos: capability map por rango, least-privilege, sin escalada desde cliente.
- Export webhook: URL tratada como credencial (config server-side).
- Escrow: core cerrado; `escrow_ignore` = config.lua, locales/, ui/, sql/.

## Ediciones
| Edición | Contenido | Precio |
|---|---|---|
| Free Lite | reports básicos + audit del panel + visor | $0 (GitHub + foro) |
| Core Escrow | suite completo, core cerrado, config/NUI abiertos | $29–39 one-time |
| Core Open Source | todo abierto | ~2.5× Core |
| Integrity Pro | módulos integrity/ + updates + soporte prioritario | $8–12/mes (escrow subscription) |

## Repo y testing
- Monorepo GitHub `fivem-staff-suite`: resource + ui + tests + docs + tools. Privado hasta F1 (lite se publica en repo público separado o release del mismo).
- **Capas de test:** (1) unit Lua con natives mockeados; (2) integración: FXServer headless en InstaBox + test resource que dispara eventos simulados; (3) NUI browser harness; (4) in-game: Fausto beta tester #1 + externos en F2.
- CI: GitHub Actions x86_64 → unit + integration en cada push (license key free).
- SOPs operativas en `sops/`.
