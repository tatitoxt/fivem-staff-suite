# DECISIONS — Registro de decisiones del negocio FiveM
Formato: ID · fecha · decisión · rationale · estado. Lo decidido acá no se re-discute sin evidencia nueva.

| ID | Fecha | Decisión | Rationale | Estado |
|---|---|---|---|---|
| D001 | 18/11 | Chat/proyecto dedicado FiveM separado del clipping | Handoff limpio, contexto propio (CONTEXTO.md) | ✅ |
| D002 | 18/11 | Regla $0 fijo: todo free tier/self-hosted | Infra Oracle Always Free existente; sin costo hundido | ✅ |
| D003 | 18/11 | Research de gaps antes de construir | Scrapeo completo 1.198 listings Cfx + demanda foro → datos, no intuición | ✅ |
| D004 | 18/11 | Producto 1 = Staff Suite; Producto 2 = NPCs IA después | Staff tooling: menos competencia (9 listings vs 46 jobs), comprador con tarjeta, sin costo API. NPCs IA: mayor techo pero nicho joven con 6+ competidores | ✅ |
| D005 | 18/11 | NO tocar el VPS Oracle para este proyecto | Pedido explícito de Fausto; entorno FEX de prueba montado y luego borrado (cleanup verificado) | ✅ |
| D006 | 18/11 | QA en InstaBox Free (x86 nativo, 4vCPU/8GB, on-demand) | Independiente total del Oracle; FXServer nativo sin emulador; auto-pause OK para QA; bookmark del vault verificado en docs oficiales | ⏳ esperando cuenta de Fausto |
| D007 | 18/11 | Fausto = beta tester #1 (PC Windows + GTA V + FiveM) | Cierra el loop de QA in-game sin terceros; clips de marketing propios | ✅ |
| D008 | 18/11 | Scope v0.2: suite COMPLETO del flujo de staff (reports + moderación en ticket + duty/analytics + audit), NO clonar txAdmin | Fausto: el dueño no quiere pagar 3 scripts. "Completo" = flujo de trabajo, no todos los poderes de admin (txAdmin gratis ya instalado) | ✅ |
| D009 | 18/11 | Canal de venta = Tebex (Cfx Marketplace es invite-only) | Escrow + entrega nativa FiveM + confianza + suscripciones nativas; Starter £0/mes, 15% fee FiveM | ✅ |
| D010 | 18/11 | Pricing: Lite $0 / Core $29–39 one-time / Pro $8–12/mes por server / OS ~2.5×. NO per-user | Mediana mercado $29.99; per-seat castiga staff voluntario rotativo; enforcement mensual vía escrow subscription de Cfx (sin infra nuestra) | ✅ |
| D011 | 18/11 | Español-first (ES/LATAM) + inglés | Todos los competidores English-first; comunidad ES/LATAM enorme; pregunta explícita de español en threads del nicho | ✅ |
| D012 | 18/11 | Validación con free lite ANTES de construir el pago (gates G1–G3) | Método probado del ecosistema; evita meses de build sin demanda; el lite ya genera reputación | ✅ |
| D013 | 18/11 | Marketing 100% orgánico primero; ads solo con conversión probada | Regla $0; foro cfx + YouTube ES + clips + creator codes Tebex = canales estándar del ecosistema | ✅ |
| D014 | 18/11 | Diferencial = integridad auditable (hash-chain + off-box), no "otro report system" | Report systems saturados ($20–25, 6+ productos); nadie combina auditoría verificable + permisos cross-system + casos en ES | ✅ |
| D015 | 18/11 | Estructura de proyecto registrada: ROADMAP + ARCHITECTURE + DECISIONS + SOPs + índice en vault Obsidian | Pedido de Fausto: dejar todo registrado antes de ejecutar | ✅ |
| D016 | 18/11 | Plan E2E de distribución y demanda (DISTRIBUTION.md) como workstream paralelo desde F0 | Fausto: "el plan tiene que cubrir TODO, asegurar distribución y demanda". Demanda se ingenia antes de construir: design partners, audiencia previa, 6 canales redundantes, activación/conversión in-product, contingencias por etapa del embudo | ✅ |
| D017 | 18/11 | Diagramas con archify (skill instalado, pipeline JSON→validate→HTML interactivo) | Pedido de Fausto; arquitectura del Staff Suite renderizada con gates green. NOTA: Hermes-Workspace es FUSE → archify finalize corre en scratch local y se copia el HTML al proyecto | ✅ |
| D018 | 18/11 | Vault Obsidian = espejo navegable del proyecto + archivo MASTER de navegación + handoff de conversación + gráficos PNG | Pedido de Fausto: "todo registrado en obsidian, junto con la conversación, y un archivo maestro para ir a gráficos/plan/arquitectura/SOPs/roadmap". Fuente de verdad sigue en VPS; Hermes sincroniza al vault tras cada cambio significativo | ✅ |
| D019 | 18/11 | FiveM = beachhead; GTA VI Creator Platform = premio mayor (reset de competencia). Construir PORTABLE: core agnóstico + adapter fino por plataforma | Fausto: "lo ideal sería migrar o recrear lo mismo para GTA VI". No se puede construir sobre plataforma no anunciada, pero sí: (1) separar lógica de negocio del adapter de plataforma, (2) acumular activos transferibles (marca/reputación/distribución/lógica validada), (3) portear rápido cuando se anuncie la Creator Platform de GTA VI. El launch de GTA VI resetea la competencia — los sellers establecidos de FiveM no ganan automáticamente ahí | ✅ |
| D020 | 19/11 | Directiva de build autónomo E2E: Hermes entrega el producto FINAL completo (core+adapter+NUI+diseño+tests E2E+feedback+docs) sin depender de Fausto paso a paso | Fausto: "tu goal es entregarme el producto final siguiendo todo el plan, con tests E2E, feedback, buen diseño, encargate de todo vos sin depender de mí". Único límite real de identidad: publicado final (GitHub push/Tebex/posts) requiere sus cuentas → se deja 100% listo. Mostrar hitos de progreso, no pedir permiso por paso. Diseño NUI = defaults Fausto (better-ui). Tracker: BUILD_PLAN.md | ✅ |

## Pendientes de decisión
- **Modelo de acceso a cuentas para distribución (A: Fausto publica 5min/día / B: delegar acceso a Hermes)** — F0, bloqueante de distribución. Recomendado: A para arrancar, B para X/YouTube cuando el volumen lo justifique.
- Nombre final del producto y del studio (¿Orkelya Studio? ¿marca propia FiveM?) — antes de F1.
- Precio intro exacto ($29 vs $35) — antes de F3, con datos del lite.
- ¿Edición Open Source desde el launch o después? — F2.
