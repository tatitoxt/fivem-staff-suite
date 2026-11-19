# DISTRIBUTION — Plan E2E de distribución y demanda
**v1.0 · 18/11/2026 · Regla $0 · Owner: Fausto (cuentas/identidad) + Hermes (ejecución/contenido/medición)**

> Principio rector: **la demanda no se garantiza, se ingenia.** No podemos prometer que 100 personas compren. Sí podemos construir un sistema con redundancia de canales, audiencia previa al producto, activación medida y contingencias por etapa del embudo — para que el resultado no dependa de un solo post en un foro. Este plan cubre el ciclo completo: descubrimiento → descarga → activación → conversión → retención → referido.

## 1. El embudo E2E (con targets y dueño por etapa)
```
DESCUBRIMIENTO   →   LANDING   →   DESCARGA LITE   →   ACTIVACIÓN   →   CONVERSIÓN   →   RETENCIÓN   →   REFERIDO
(foro/YT/TikTok/    (GitHub/foro/   (free, sin         (instala <10min,   (lite→Core        (updates,        (creator
 X/Discord/SEO)      Tebex)          fricción)          ve valor real)     $29–39)           soporte)         codes, proof)
```
| Etapa | Métrica | Target F1–F3 | Dueño |
|---|---|---|---|
| Descubrimiento | impressions/views por canal | 5K views acumuladas mes 1 | Hermes contenido, Fausto publica |
| Landing | clicks a GitHub/foro/Tebex | CTR ≥3% desde clips | Hermes |
| Descarga lite | descargas GitHub + clone | ≥100 (gate G1) | Hermes |
| Activación | installs que llegan a "primer audit log visible" | ≥40% de descargas | Hermes (producto) |
| Conversión | lite → Core pago | 3–8% (benchmark freemium) | Fausto (precio) + Hermes (upgrade path) |
| Retención | reviews ≥4★, refunds <5% | ≥4★, churn Pro <10%/mes | Hermes soporte |
| Referido | ventas por creator code, testimonios | ≥2 codes activos, ≥3 testimonios | Hermes outreach |

**Cuello de botella real identificado:** la distribución depende de cuentas con identidad (foro cfx, X, YouTube, TikTok, Discord). Hermes prepara TODO listo para publicar; Fausto publica (5 min/día) o delega acceso (ver §8). Sin esto resuelto, el mejor contenido no sale.

## 2. Asegurar demanda ANTES de construir (F0–F1)
La forma de "asegurar" demanda es validarla antes de gastar semanas en el Core:
1. **Design partners (F0):** reclutar 5–10 dueños de server ES/LATAM para calls de 15 min. Preguntar: ¿qué pagás hoy? ¿qué te duele del staff? ¿pagarías $30 por esto? → demanda pre-validada con humanos reales, no encuestas anónimas. Las commissions son validación paga (método fivesecured).
2. **Audiencia previa (F0, no F3):** devlog en X desde el día 1 ("construyendo tools FiveM mientras GTA 6 sale"), presencia en 5–10 Discords, waitlist vía GitHub release notifications + rol Discord. **Target: 100+ personas aware antes de que el lite exista.** "Announce before you finish."
3. **Señales tempranas en F1:** waitlist signups, retención de clips, calidad de replies en el foro (¿preguntan "cuándo sale el pago?" = demanda). Si las señales son flojas a la semana 2, ajustar posicionamiento ANTES del gate G1.

## 3. Redundancia de canales (ningún punto único de fallo)
6 canales independientes. Si uno falla, los otros cargan. Cada uno con mínimo semanal:
| Canal | Rol | Mínimo semanal | Métrica clave |
|---|---|---|---|
| **Foro cfx.re Releases** | descubrimiento primario (donde los owners buscan scripts) | 1 post/bump de valor | replies, views, descargas |
| **YouTube ES/EN** | tráfico evergreen de búsqueda (SEO) | 1 video showcase/largo por mes + shorts | views, CTR a landing |
| **TikTok/Shorts/Reels** | upside viral | 2 clips | retención, clicks bio |
| **X (@https_tatito)** | build-in-public, comunidad dev | 1–2 devlog | followers, clicks |
| **Discords ES/LATAM** | confianza, design partners, testers | presencia diaria 15 min | partners reclutados, feedback |
| **Creator codes Tebex** | audiencia prestada de influencers | 5 outreach hasta 10 activos | ventas por código |

**Regla:** a las 4 semanas, duplicar apuesta en el canal que convierte y cortar el que no. No mantener 6 canales muertos por inercia.

## 4. Activación y conversión (el producto como canal)
La distribución no termina en la descarga — el lite tiene que ACTIVAR y CONVERTIR:
1. **Instalación <10 min:** docs ES paso a paso + video install + cero dependencias raras. Un lite que no se instala = cero conversión sin importar las descargas.
2. **Demo mode / primer valor inmediato:** al primer arranque, el lite muestra un audit timeline con datos simulados para que el dueño VEA el valor sin necesitar jugadores. "Aha moment" en el minuto 1.
3. **Upgrade path in-product:** el lite muestra features Core/Pro bloqueadas con valor claro ("desbloqueá moderación en ticket + analytics + auditoría unificada") + link directo a Tebex. Conversión freemium target 3–8%.
4. **Fricción de pago mínima:** Tebex entrega automática a cuenta cfx.re, compra en 1 minuto, PayPal/tarjeta.

## 5. Flywheel de prueba social
```
beta testers → testimonios + case studies ("server X detectó Y abusos")
   → posts en foro + reviews Tebex (NUNCA compradas)
   → más confianza → más ventas → más testers → ...
```
- Cada beta session de Fausto = material para 1 clip + 1 testimonio potencial.
- Case studies reales (con permiso del server) son el contenido que más convierte en B2B de nicho.
- Reviews: responder las negativas con fix concreto (vende más que 5★ sin contexto).

## 6. Targets por fase (números, no humo)
| Fase | Descubrimiento | Demanda | Conversión |
|---|---|---|---|
| F0 | 5 comunidades, devlog iniciado | 3 design partners, 30 waitlist | — |
| F1 | 2 clips >1K views, post foro | 100 descargas, 15 replies, 3 feature requests (G1) | — |
| F2 | 1 video showcase, 3 testers externos | feedback procesado (G2) | pre-orders / interest |
| F3 | 10 creator outreach, 2 activos | — | 10 ventas, 3 reviews ≥4★ (G3) |
| F4 | canal ganador escalado | — | 20 subs Pro, MRR $200+ |

## 7. Escalera de contingencias (si G1/G3 flojean)
**Diagnosticar la etapa del embudo que falla, no "hacer más marketing" a ciegas:**
| Síntoma | Diagnóstico | Fix concreto | Re-test |
|---|---|---|---|
| Poco tráfico | descubrimiento | más canales + creator outreach + SEO ES | 2 sem |
| Tráfico pero no descargas | landing/posicionamiento | título/video/hook nuevo, probar ángulo "audita a tu staff" vs "report system" | 2 sem |
| Descargas pero no activación | fricción install | demo mode, docs video, reducir dependencias | 2 sem |
| Activación pero no conversión | precio/valor | precio intro menor, upgrade path más claro, feature gating | 2 sem |
| Nada funciona | demanda insuficiente | **pivotear** (abajo) | — |

**Opciones de pivot (en orden de preferencia):**
1. Reposicionar como admin tooling puro (el nicho de 9 listings, menos saturado que reports).
2. Mercado EN-only (si ES no tracciona, EN tiene más volumen aunque más competencia).
3. Acelerar Producto 2 (NPCs IA tiene prensa/attention actual — HumaLike, GTA BOOM).
4. Trabajo commissioned de design partners (validación paga mientras se productiza).

## 8. Modelo de ejecución y acceso (DECISIÓN PENDIENTE)
Hermes puede: escribir todo el contenido, editar clips, preparar posts copy-paste, medir, hacer outreach drafts, scrapear competencia.
Hermes NO puede (sin acceso): publicar en foro cfx/X/YouTube/TikTok/Discord con identidad de Fausto, crear cuentas, cobrar.

**Dos modelos (elegir):**
- **A) Fausto publica (5 min/día):** Hermes deja paquetes listos (post + video + captions + links) en `distribution/ready-to-post/`; Fausto copia y pega en sus cuentas. Cero acceso compartido.
- **B) Delegar acceso:** Fausto autentica xurl (X), da acceso al foro/YouTube/TikTok/Discord → Hermes publica autónomo. Más rápido, requiere credenciales (regla: aprobación explícita + bóveda).

**Recomendación:** empezar con A (cero fricción de seguridad), migrar a B para X/YouTube cuando el volumen lo justifique.

## 9. Ritual semanal de distribución (30 min, Hermes → Fausto)
1. Métricas del embudo por canal (en `metrics/AAAA-MM.md`).
2. Qué canal ganó/perdió → ajuste de apuesta.
3. Paquete de contenido listo para la semana (clips, post, devlog).
4. Señales de demanda (waitlist, replies, design partners).
5. ¿Algún gate en riesgo? → contingencia §7.

## 10. Lo que NO hacemos (reglas)
- No comprar reviews/descargas/followers (ToS + reputación = el activo).
- No spam en Discords (valor primero, baneo = canal muerto).
- No ads pagos hasta conversión orgánica probada (D013).
- No prometer features con fecha en público.
- No repetir claims de ingresos de threads virales sin verificar.
