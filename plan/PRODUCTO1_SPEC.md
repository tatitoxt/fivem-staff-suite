# PRODUCTO 1 — Staff Integrity Suite (spec operativa v0.1)
**Fecha:** 18/11/2026 · **Estado:** pre-validación · **Budget:** $0 fijo

## 1. Tesis (v0.2 — scope ampliado por Fausto, 18/11/2026)
El comprador es el **dueño del server**. No quiere comprar 3 scripts separados (reports + staff management + auditoría): quiere **un solo producto que cubra todo el flujo de staff**. Pero el mercado de "report systems" sueltos está saturado (6+ productos a $20–25 con chat/claim/analytics).

Posicionamiento: **"Staff Suite completo — el único que audita a tu staff"**. Un solo script con: reports/tickets de jugadores + acciones de moderación dentro del ticket + duty/analytics de staff + **audit log unificado a prueba de manipulación** (el diferencial que ningún incumbente combina). Se monta ENCIMA de txAdmin (gratis, ya instalado) para los poderes crudos de admin (noclip/god/spawn) — NO reconstruimos eso.

Regla de scope: "completo" = todo el FLUJO DE TRABAJO del staff en una compra. No = clonar txAdmin ni cada feature de admin que existe.

## 2. Mapa competitivo verificado (18/11/2026)
| Producto | Precio | Qué hace | Qué NO hace |
|---|---|---|---|
| txAdmin (gratis, viene con FXServer) | $0 | Menú in-game, web panel, bans/warns/whitelist, logs de acciones, monitoring | Logs en texto plano editables, sin correlación cross-system, sin analytics de staff, sin gestión de casos |
| EVOLVE Reports | s/d (Tebex) | Tickets, claim/transfer, chat, spectate, canned responses, ratings, leaderboard staff, 9 temas | Auditoría de integridad, permisos cross-system |
| AZ Scripts Report System | s/d | Reports + chat + notas + analytics dashboard, 5 idiomas | Igual que arriba |
| GCMods Report System | $20 | Duty system, colas, métricas, screenshot, historial | Igual |
| 0Bug Report System | $24.99 | Reports + evidencia + leaderboard | Igual |
| Jota Dev Admin Panel + Reports | €49.99 + €20.61 | Panel web completo + reports, demo pública | Igual |
| **Agency-Admin** (agencyg.de) | s/d | Logs "tamper-resistant" con contexto, tiers de permisos, **detección de anomalías** (money-spike, teleport imposible), flags por tier, stealth | Es el competidor más cercano. Verificar alcance real antes de afirmar gaps. English-first, closed core |

**Conclusión:** NO construir "otro report system" (saturado, $20–25, guerra de features). El wedge es la **capa de integridad/auditoría** que ninguno combina completa. Agency-Admin tiene detección → no podemos decir "nadie lo hace"; decimos "nadie combina auditoría unificada + prueba de manipulación + inventario de permisos cross-system + casos, en español, con config abierta".

## 3. Features (v0.2 — suite completo, modular)
### Free lite (validación + embudo, 2–3 semanas)
1. **Reports/tickets básicos**: jugador `/report` → panel staff, claim, chat en tiempo real, resolver. Categorías configurables.
2. **Audit log de todo lo que pasa por el panel**: cada acción queda registrada (quién/qué/a quién/cuándo/razón) con **hash-chain** verificable.
3. **Visor NUI**: timeline filtrable. Open config + NUI. ES/EN, español-first.
→ Ya es un producto gratuito ÚTIL y diferenciado (todos los reports systems free no auditan nada).

### Suite Core (pago único $29–39 — el producto "completo")
4. **Reports avanzados**: prioridades, canned responses, notas privadas, ratings de satisfacción, historial completo, evidencia (imágenes vía screenshot-basic), export Discord.
5. **Moderación dentro del ticket**: goto/bring/spectate/freeze/heal/revive/kick/ban con razón obligatoria — wrappers finos sobre natives/framework, NO un admin menu completo (eso sigue siendo txAdmin).
6. **Duty system + analytics de staff**: on/off duty, horas, tickets resueltos, tiempo de respuesta, leaderboard.
7. **Audit log unificado server-side**: captura acciones del framework (QB/ESX), comandos registrados y eventos txAdmin. Hash-chain SHA-256 + export off-box (webhook + archivo append-only). Si editan/borran una entrada, la cadena se rompe → verificable.
8. Permisos por rango (granulares, least-privilege), multi-framework ESX/QBCore/Qbox/standalone.

### Integrity Pro ($8–12/mes por server — suscripción escrow)
9. **Inventario de permisos cross-system**: ACE + txAdmin + grupos framework + Discord. Huérfanos, cuentas compartidas, escaladas.
10. **Permisos con vencimiento** + offboarding automático.
11. **Flags de anomalías**: grants fuera de patrón, bans sin razón o repetidos contra los mismos nombres, noclip/god fuera de duty. (Agency-Admin hace parte → diferencial: correlación con reports + cadena verificable.)
12. **Case files**: report + acciones staff + writes de economía + evidencia en un timeline exportable.
13. **Apelaciones con detección de patrones** (patrón contra un mismo staff = señal temprana).
14. **Dashboard del dueño** + resumen semanal por Discord.

### Explícitamente FUERA
- No clonar txAdmin/vMenu (noclip, god, spawn, teleport libre): gratis y ya instalado. Coexistencia.
- No SaaS alojado por nosotros. No IA/LLM en Producto 1 (opcional futuro: resumen de casos con key del comprador). No anticheat.

## 4. Arquitectura técnica
- **Resource FiveM standalone** + bridges opcionales ESX/QBCore/Qbox (patrón ox_lib/helix_lib).
- Server Lua: captura de eventos, hash-chain, storage oxmysql (89% de servers lo tienen) + fallback JSON.
- NUI (HTML/JS): visor de auditoría, dashboard, casos. Open source en la edición OS.
- Export: Discord webhooks (sin bot, $0) + archivo append-only.
- Dependencias mínimas: oxmysql (opcional), ox_lib (opcional). Standalone-first.
- Escrow: core cerrado en edición escrow; config + NUI + locales abiertos (patrón del mercado). Edición Open Source completa a precio premium (Apex cobra 2.5×).

## 5. Plan de pruebas ($0) — procedimiento PROBADO, entorno DESMONTADO
**Estado (18/11/2026):** el entorno FEX-Emu + FXServer se montó y verificó en el VPS Oracle (arrancó hasta la license key), pero **Fausto pidió borrarlo y no tocar el VPS por ahora**. Cleanup verificado: paquetes FEX purgados, PPA eliminado, binfmt desregistrado, `~/fivem-test/` y RootFS borrados. El procedimiento completo quedó documentado en la skill `fivem-test-server-fexemu` (se remonta en ~10 min cuando se decida dónde hostear el QA).
**Ubicación del entorno de QA: PENDIENTE de decisión de Fausto** (opciones: VPS cuando lo autorice, Mac local vía Docker+box64, u otra máquina x86).

**Hecho técnico:** FXServer Linux es x86_64 ONLY ("courtesy port" de Cfx). En ARM `run.sh` falla nativo con "Exec format error". No hay build ARM ni planes de soporte.

**Solución verificada (probada en Oracle ARM 2 cores/11GB, Ubuntu 24.04):** FEX-Emu (PPA fex-emu/fex) + RootFS Fedora 44 + fuse3 → `FEXBash -c 'uname -m'` = x86_64; FXServer build 38435 arrancó, escaneó 20 resources y frenó solo por falta de sv_licenseKey (gratuita, de portal.cfx.re/servers/registration-keys — requiere cuenta cfx de Fausto).

**Local en la Mac de Fausto:** posible pero peor — la Mac es ARM también, no hay build macOS de FXServer; sería Docker+box64/qemu comiendo recursos de su máquina de uso diario. El VPS es always-on y lo gestiona Hermes.

### Capas de testing
1. **Unit tests Lua** (cualquier máquina): hash-chain, permisos, parsing, natives mockeados. $0.
2. **FXServer headless en el VPS vía FEX-Emu**: ✅ entorno montado. Server vacío + resource de test que ejercita captura/persistencia/export (MariaDB local). Falta: license key + instalar MariaDB + oxmysql.
3. **NUI en browser**: HTML/JS con SendNUIMessage mockeado. $0.
4. **Gameplay real (cliente FiveM)**: Windows-only; la Mac no lo corre nativo. Beta testers con sus propios servers (early access gratis por feedback). No hace falta comprar GTA V para el 90% del QA.
5. **CI opcional**: GitHub Actions x86_64 gratis + license key → regresión automática por push.

## 6. Tebex — qué es y por qué (verificado)
- **Qué es:** plataforma de monetización para servers de juegos. Es el **merchant of record**: vende al jugador en tu nombre, maneja pagos, IVA internacional, chargebacks (Seller Protection) y entrega.
- **Es necesario?** Para este modelo, sí en la práctica: (a) los assets con **escrow de Cfx se distribuyen vía Tebex** y el entitlement queda atado a la cuenta cfx.re del comprador; (b) entrega automática nativa FiveM; (c) es donde los compradores de FiveM confían y compran; (d) soporta **suscripciones recurrentes** nativas. Alternativas (Stripe/Gumroad propio) existen para open-source pero pierden escrow, entrega automática y confianza — no valen la pena al inicio.
- **Costo fijo: $0.** Plan Starter £0/mes (ilimitados packages, analytics, SSL, seller protection). Plus £12.49/mo es opcional (custom domain/templates) — NO lo necesitamos.
- **Comisiones por venta:** 15% plataforma FiveM + gateway (PayPal 2.49% + $0.40; tarjetas ~2.49%). Settlement 14 días. Retiro PayPal desde $5 (fee $0.50).
- **Ejemplo:** venta $35 → ~$29.3 netos después de fees (aprox).
- **Suscripciones:** Tebex cobra recurrente y Cfx escrow hace cumplir: *"If the subscription expires, the asset is removed from the subscribed user's account and will no longer start on the user's server"* (docs.fivem.net). **Enforcement de monthly SIN infraestructura nuestra.** Ejemplo real: Senor Scripts $20/mes por colección escrow.

## 7. Pricing y modelo mensual
### Por qué NO per-user (por asiento de staff)
- El staff de RP es **voluntario y rotativo**: cobrar por asiento castiga al server por tener equipo grande y genera churn cada vez que alguien se va.
- El que paga es el dueño (una tarjeta), no cada staff. Per-seat agrega fricción de gestión sin valor percibido.
- Enforcement por asiento requeriría licencia propia (infra nuestra, contra regla $0).
- **Nadie en el mercado lo hace** → no es convención validada; es fricción inventada.

### Lo que SÍ funciona: mensual por server (con tiers)
Mecanismo: package de suscripción Tebex + escrow subscription de Cfx (el resource deja de arrancar si expira). $0 de infra nuestra.

| Tier | Precio sugerido | Qué incluye |
|---|---|---|
| **Lite** | $0 | Audit log + hash-chain + visor básico (validación y embudo) |
| **Core one-time** | $29–39 pago único | MVP completo + updates de por vida (ancla del mercado: reports $20–25, paneles €50) |
| **Integrity Pro** | **$8–12/mes por server** | Pro features (inventario permisos, flags, casos, apelaciones, dashboard) + updates + soporte prioritario |
| **Tiers por tamaño de staff** (opcional, aproxima tu idea per-user sin fricción) | ≤10 staff: $8 · ≤25: $12 · ilimitado: $18 | Mismo producto, precio por banda |
| **All-access bundle** (fase 2, cuando exista Producto 2) | $20–27/mes | Staff Suite + NPC pack IA + futuros (benchmark: Apex €26.65/mes, Senor $20/mes) |

### Matemática honesta (sin humo)
- 10 servers en Pro × $9 = **$90 MRR** (neto ~$74 después de fees).
- 30 ventas one-time × $35 = **~$1.050** una vez (neto ~$880).
- La suscripción exige valor continuo (updates, soporte, features nuevas). Un seller nuevo sin reputación convierte mejor one-time; por eso el modelo mixto: **one-time para entrar, monthly para el que quiere la capa Pro viva, bundle cuando haya 2+ productos**.
- El monthly se vuelve mucho más vendible como **all-access** (Apex y Senor lo prueban) que como un solo script suelto.

## 8. Go-to-market orgánico ($0) — plan por fases
**Fase 0 — Validación (semanas 1–3):** free lite (reports + audit) → post en foro cfx.re Releases (ES/EN) + GitHub. El foro es EL canal de descubrimiento de scripts; cada seller grande arrancó ahí. Video showcase corto en el post. Medir: descargas, replies, pedidos de features.
**Fase 1 — Lanzamiento Core (semanas 4–8):**
1. YouTube showcase ES/EN (los compradores de FiveM miran videos antes de comprar; el contenido FiveM en español está desatendido → wedge). SEO: "sistema de reportes FiveM", "panel de staff FiveM", "FiveM report system 2026".
2. Clips TikTok/Shorts/Reels de las sesiones de test de Fausto (OBS en su Windows) — hooks: "tu staff te está robando y no lo sabés", "el panel que audita a tus admins". Pipeline de clipping del otro chat, contenido 100% propio.
3. Timing GTA VI: launch 19/11/2026 → ola de atención gratis esta semana. Ángulo: "GTA 6 sale en consolas, el RP de PC sigue en FiveM — y tu server necesita esto".
4. Discords de owners/devs FiveM LATAM/ES: valor primero (free lite, ayuda), no spam. Fausto = beta tester #1 (su PC Windows con GTA V + FiveM) → testimonios y clips propios.
5. Tebex store Starter + entrega nativa FiveM + **creator codes** (1% fee): youtubers/streamers de FiveM promocionan a cambio de comisión — el canal de influencers estándar del ecosistema, $0 upfront.
6. X build-in-public (@https_tatito) ES/EN: devlog, clips, encuestas a owners.
**Fase 2 — Escala (mes 3+):** Integrity Pro subscription + bundle all-access con Producto 2 (NPCs IA) → registro de interés en Cfx Marketplace (vitrina invite-only) + ads pagos SOLO si la conversión orgánica ya está probada.

## 8b. Monetización y futuro — escenarios honestos (sin humo)
**Tamaño de mercado (verificado):** ~35K servers públicos escaneados (fivesearch.net), ~131K jugadores concurrentes en servers con oxmysql. El comprador es el owner con presupuesto: nicho de utilidad evergreen (todo server con staff lo necesita), menos estacional que heists/jobs.
**Benchmarks reales:** Apex = 5.300+ órdenes en ~18 meses con 55 scripts (~300 órdenes/mes toda la store, y son top seller 2026). Report systems sueltos $20–25; paneles €50. Un seller nuevo no arranca en esos números.
**Escenarios (a 6–12 meses, con marketing consistente):**
- Base: 10–30 ventas/mes × $35 ≈ $350–1.050 bruto (~$290–880 neto tras fees) + MRR Pro creciendo lento.
- Bueno (clip viral + tracción en foro): 50–100 ventas/mes + 20–40 subs Pro ≈ $2–4K/mo.
- Techo realista año 1 para un solo dev nuevo: ~10% de la velocidad de Apex. La mayoría de los que fallan, fallan en marketing, no en producto.
**Futuro / tailwinds:** GTA VI sale mañana en consolas, PC ~Q1 2027 → FiveM retiene el RP de PC por meses/años (la base de GTA V RP es pegajosa; Rockstar compró FiveM y está invirtiendo en el marketplace). Utilidad de staff = demanda recurrente dentro de esa ventana.
**Riesgos:** (1) GTA VI PC + creator platform oficial podría absorber el ecosistema a largo plazo (2+ años, especulativo — monitorear, no invertir de más); (2) saturación de report systems → el diferencial de integridad tiene que ser visible en el marketing, no una feature escondida; (3) soporte ES/EN consume tiempo; (4) Agency-Admin y incumbentes pueden copiar features — la ventaja es velocidad + español + comunidad.
**Veredicto:** no es la promesa de $50K del thread. Es una semilla de negocio realista ($500–3K/mo en 6–12 meses ejecutando bien), con el producto de NPCs IA como upside de mayor techo/riesgo. El activo compuesto: reputación + distribución en un nicho, no un script suelto.

## 9. Riesgos honestos
- Agency-Admin ya cubre parte (detección + logs con contexto): hay que verificar su alcance real y precio antes de fijar el diferencial final. No afirmar "nadie lo hace".
- txAdmin es gratis y viene instalado: el producto tiene que demostrar valor POR ENCIMA (auditoría a prueba de manipulación + casos + permisos cross-system), no competir con el menú.
- Capturar eventos de otros resources tiene límites técnicos (no todo es interceptable server-side); el MVP debe ser honesto sobre qué captura y qué no.
- Nicho de utilidad: menos volumen que jobs/heists, pero comprador con tarjeta y menos competencia.
- Soporte en español es diferencial pero consume tiempo nuestro.

## 10. Próximo paso
Validación antes de construir el Pro: **free lite (audit log + hash-chain + visor)** → publicar en foro + clip → medir recepción (descargas, replies, estrellas, pedidos de features). Si tracciona, construir Pro y listar en Tebex con el modelo mixto.
