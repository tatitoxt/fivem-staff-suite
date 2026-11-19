# ROADMAP — Negocio FiveM (Staff Suite → NPCs IA)
**Actualizado:** 18/11/2026 · **Regla:** $0 fijo · **Dueño:** Fausto · **Ejecutor:** Hermes

## Vista general
```
F0 Cimientos ──→ F1 Free Lite + Validación ──G1──→ F2 Suite Core ──G2──→ F3 Launch ──G3──→ F4 Pro + Producto 2
   (sem 1)            (sem 1–3)                      (sem 4–8)            (sem 8–10)         (mes 3+)
```
Cada fase tiene un **gate**: no se avanza sin la señal definida. Esto evita construir meses algo que nadie quiere.

> **Workstream paralelo de DISTRIBUCIÓN (E2E):** corre en TODAS las fases desde F0, no solo al launch. Plan maestro en `DISTRIBUTION.md` (embudo completo, 6 canales redundantes, demanda pre-validada con design partners, activación/conversión in-product, contingencias por etapa). La demanda se ingenia antes de construir, no se espera al final.

## F0 — Cimientos (semana 1)
| Tarea | Owner | Estado |
|---|---|---|
| Cuenta InstaBox free + API key | **Fausto** | ⏳ pendiente |
| License key FiveM (portal.cfx.re) | **Fausto** | ⏳ pendiente |
| Entorno QA en InstaBox (FXServer nativo x86 + MariaDB + oxmysql) | Hermes | bloqueado por keys |
| Repo GitHub privado `fivem-staff-suite` + estructura + CI skeleton | Hermes | ⏳ |
| PC Windows de Fausto con FiveM actualizado (beta tester #1) | **Fausto** | ⏳ |
| **Distribución F0:** modelo de acceso (A: Fausto publica / B: delegar) — ver DISTRIBUTION §8 | **Fausto** decide | ⏳ |
| **Distribución F0:** reclutar 5–10 design partners (dueños server ES/LATAM) + unirse a 5 comunidades | Hermes drafts, Fausto contacto | ⏳ |
| **Distribución F0:** devlog X día 1 + waitlist (GitHub notifications + rol Discord) | Hermes contenido, Fausto publica | ⏳ |

## F1 — Free Lite + Validación (semanas 1–3)
- Construir lite: reports/tickets básicos + audit log con hash-chain + visor NUI (ES/EN).
- QA automatizado (SOP-QA-TESTING) + sesión in-game de Fausto.
- Publicar: foro cfx.re Releases (post ES/EN con video) + GitHub público.
- Devlog en X aprovechando la ola GTA VI (launch 19/11).
- **Métricas:** descargas, replies, pedidos de features, estrellas.
- **GATE G1 (2 semanas post-publicación):** ≥100 descargas OR ≥15 replies sustantivos OR ≥3 pedidos de features → F2. **Señales tempranas (semana 2, antes del gate):** waitlist signups, retención de clips, replies que preguntan "¿cuándo sale el pago?". Si flojas → ajustar posicionamiento ANTES del gate (DISTRIBUTION §7). Si no: iterar el lite o pivotear (admin tooling puro, EN-only, o adelantar Producto 2).

## F2 — Suite Core (semanas 4–8)
- Reports avanzados (prioridades, canned responses, notas, ratings, evidencia, export Discord).
- Moderación dentro del ticket (goto/bring/spectate/freeze/heal/kick/ban con razón obligatoria).
- Duty system + analytics de staff + leaderboard.
- Audit log unificado (framework + comandos + txAdmin best-effort) + export off-box.
- Permisos por rango granulares. Bridges ESX/QBCore/Qbox/standalone.
- Docs ES/EN + video showcase.
- Tebex store Starter + paquete escrow (portal.cfx.re) + edición Open Source.
- Beta round 2: Fausto + 3 testers externos reclutados en Discords ES/LATAM.
- **GATE G2:** tests green + sign-off de Fausto + feedback de ≥3 testers externos procesado → F3.

## F3 — Lanzamiento (semanas 8–10)
- Listing Tebex: precio intro $29 (luego $35–39). Edición OS ~2.5×.
- YouTube showcase ES/EN + clips TikTok/Shorts (SOP-MARKETING).
- Creator codes: outreach a 10 youtubers/streamers FiveM ES/EN.
- Discord seeding + post de lanzamiento en foro + X.
- **GATE G3:** primeras 10 ventas + reviews ≥4★ → F4. Si no: diagnosticar (¿tráfico? ¿conversión? ¿precio?) con datos antes de gastar en ads.

## F4 — Pro + Producto 2 (mes 3+)
- **Integrity Pro** ($8–12/mes por server, suscripción escrow): inventario de permisos cross-system, vencimientos, flags de anomalías, case files, apelaciones, dashboard del dueño.
- **Producto 2 (NPCs IA):** free lite de 1 NPC tendero (texto, BYO key Groq/Gemini/Ollama, ES-first) → validar con el mismo método G1 → pack pago $29–49.
- Bundle all-access ($20–27/mes) cuando ambos productos estén vivos.
- Registro de interés en Cfx Marketplace (vitrina invite-only).
- Ads pagos SOLO con conversión orgánica probada.

## F5 — Port GTA VI (TRIGGER, no fecha) — D019
**Se activa cuando Rockstar anuncie la Creator Platform de GTA VI** (no antes — no se construye sobre plataforma no anunciada).
- Evaluar el SDK/lenguaje de la plataforma (¿Lua-based como FiveM? ¿nuevo?).
- Portear el **adapter** (natives/NUI/bridges) reusando el **core agnóstico** + spec + tests.
- Relanzar productos con la marca/audiencia existente → early en un mercado con competencia reseteada.
- Producto 2 (NPCs IA) primero en portear (~80% agnóstico); Staff Suite después.
- **Riesgo de acceso:** Rockstar podría operar un marketplace cerrado/curado (como Cfx invite-only) y controlar quién vende. Monitorear los términos de la Creator Platform antes de invertir en el port.
- Trigger de vigilancia en `research/GTA6_FIVEM_STATUS.md`.

## Operación continua
- Soporte: SOP-SUPPORT (SLA 24–48h).
- Monitoreo mensual: SOP-MONITORING (competencia, precios, GTA VI ecosystem, métricas propias).
- Review de estrategia trimestral con Fausto (¿seguir, escalar, pivotear?).

## Riesgos del roadmap
1. G1 flojo → no construir Core a ciegas; el lite ya dejó reputación y aprendizaje.
2. GTA VI PC + creator platform oficial (2+ años) → monitorear, no sobreinvertir.
3. Soporte ES/EN consume tiempo → SOPs + docs desde el día 1, FAQ viva.
4. Dependencia de keys de Fausto (F0) → único bloqueante humano; recordatorio semanal hasta completar.
5. **Distribución = riesgo #1 del negocio** (no el producto). Mitigado con DISTRIBUTION.md: audiencia previa, 6 canales redundantes, design partners, activación medida, contingencias por etapa del embudo. Sin acceso a cuentas resuelto (§8), el contenido no sale → resolver en F0.
