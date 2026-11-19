# BUILD STATUS — Delivery autónomo del Staff Suite
**Modo:** Hermes ejecuta E2E sin depender de Fausto (solo identidad-bound al final). **Meta:** producto ship-ready.
**QA:** InstaBox fivem-qa (FXServer 38435 + MariaDB + oxmysql) ✅ vivo.

## Pipeline de delivery
| # | Componente | Estado | Tests |
|---|---|---|---|
| 1 | core/sha256.lua | ✅ | 4 NIST vectors |
| 2 | core/audit_chain.lua | ✅ | 6 (tamper edit/delete/reorder/head) |
| 3 | core/tickets.lua (state machine) | 🔨 en progreso | — |
| 4 | core/permissions.lua (capabilities) | 🔨 en progreso | — |
| 5 | core/analytics.lua (duty/stats) | ⏳ | — |
| 6 | adapter FiveM (natives, oxmysql, captura) | ⏳ | — |
| 7 | bridges ESX/QBCore/Qbox/standalone | ⏳ | — |
| 8 | NUI React (visor audit + panel tickets) | ⏳ | browser harness |
| 9 | fxmanifest + config + locales ES/EN | ⏳ | — |
| 10 | Deploy QA + E2E server-side | ⏳ | integración |
| 11 | Docs ES/EN + install guide | ⏳ | — |
| 12 | Packaging escrow + edición OS | ⏳ | — |
| 13 | Marketing assets (showcase, clips, posts) | ⏳ | — |
| 14 | Listing Tebex (contenido listo) | ⏳ | — |

## Identity-bound (Fausto, al final — todo preparado)
- [ ] gh auth login → push repo + CI
- [ ] Crear tienda Tebex (su cuenta) + conectar escrow
- [ ] Publicar foro cfx / X / YouTube (paquetes copy-paste listos)
- [ ] Sesión in-game feel (su Windows + FiveM) — yo expongo el puerto

## Log de progreso
- 19/11: QA InstaBox operativo. core sha256 + audit_chain (10 tests green, commit 77727ea). Bug head-cache cazado por test y arreglado. Demo visual audit-chain.
