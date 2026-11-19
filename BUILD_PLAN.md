# BUILD PLAN — Staff Suite (Producto 1) hasta producto final
**Goal (D020):** entregar el producto final completo, autónomo, siguiendo el plan — tests E2E, feedback, buen diseño. Fausto solo pone identidad para publicar (Tebex/foro/GitHub/X).
**Diseño NUI:** defaults de Fausto (skill better-ui) — LIGHT, Manrope 700/800 headings + DM Sans body ≥16px (mín 13px), colores vívidos (#16A34A/#F58220/#E5484D), bubble radius ~20px + pills, sombras suaves, transiciones 220ms cubic-bezier(0.2,0,0,1), paneles de altura fija con scroll interno (cero layout shift), todo interactivo, legibilidad ≥4.5:1 auditada. Anti-slop (unslop-ui). E2E con browser antes de dar por hecho.

## Tracker
| # | Tarea | Estado |
|---|---|---|
| 1 | Entorno QA InstaBox (FXServer+DB) | ✅ |
| 2 | Repo + git (separate-git-dir ext4) | ✅ |
| 3 | core/sha256.lua (NIST) | ✅ 4 tests |
| 4 | core/audit_chain.lua + tamper | ✅ 6 tests |
| 5 | core/tickets.lua (state machine) | ✅ 7 tests |
| 6 | core/permissions.lua (capabilities) | ✅ 7 tests |
| 7 | core/duty.lua (analytics) | ✅ 3 tests |
| 8 | Adapter FiveM: fxmanifest + server main | 🔨 |
| 9 | Adapter: captura eventos framework + comandos | ⏳ |
| 10 | Adapter: persistencia oxmysql + fallback JSON | ⏳ |
| 11 | Adapter: export off-box (webhook + archivo) | ⏳ |
| 12 | Adapter: bridges ESX/QBCore/Qbox/standalone | ✅ Tests Lua con mocks |
| 13 | NUI: design system + layout (light, Manrope/DM Sans) | ✅ React 18+TS+Vite, `ui/` |
| 14 | NUI: visor auditoría (timeline + filtros + verify) | ✅ smoke test tamper |
| 15 | NUI: panel tickets (cola, claim, chat, moderación) | ✅ smoke test claim |
| 16 | NUI: dashboard staff (duty, leaderboard) | ✅ + Duty + Ajustes |
| 17 | Locales ES/EN completos | ⏳ |
| 18 | Test resource E2E (eventos simulados → asserts) | ⏳ |
| 19 | Deploy QA + E2E green + resmon <0.05ms | ⏳ |
| 20 | Sesión in-game Fausto (beta) + feedback | ⏳ (requiere Fausto) |
| 21 | Docs ES/EN (install, config, permisos, FAQ) | ⏳ |
| 22 | Escrow packaging (portal.cfx.re) | ⏳ (requiere Fausto) |
| 23 | Launch materials: Tebex listing copy + imágenes | ✅ copy ES/EN + spec de imágenes (`launch/`) · capturas reales in-game tras #19 |
| 24 | Launch materials: post foro ES/EN + video script | ✅ `launch/forum-post-*.md`, `launch/video-script.md` · completar resmon (#19) |
| 25 | Launch materials: clips hooks + creator outreach | ✅ `launch/clips.md`, `launch/creator-outreach.md`, `launch/x-devlog.md` |
| 26 | Publicar (Tebex/foro/GitHub/X) | ⏳ (requiere Fausto, copy-paste) |

## Orden de ejecución
Core (5-7) → Adapter (8-12) → NUI (13-17) → E2E (18-19) → beta (20) → docs (21) → packaging+materials (22-25) → publicar (26).
Cada módulo del core: TDD (test primero → implementar → green → commit). NUI: E2E browser + legibilidad auditada antes de done.

## Lo que requiere identidad de Fausto (no puedo sin él, ToS/legal)
- GitHub auth (push repo + CI) → `gh auth login`.
- Crear tienda Tebex + paquete escrow (portal.cfx.re).
- Publicar en foro cfx / X / YouTube / TikTok / Discord con su cuenta.
- Sesión de beta in-game (su Windows + FiveM).
Todo lo demás (código, tests, diseño, docs, contenido, paquetes listos) lo hago yo.
