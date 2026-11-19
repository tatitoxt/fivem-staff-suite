# Creator outreach — 10 creadores FiveM ES/EN + creator code Tebex

> Objetivo F3 (`plan/ROADMAP.md`): 10 contactados, 2 activos. Canal estándar del ecosistema, $0 por adelantado (`PRODUCTO1_SPEC.md` §8).
> No se compran reviews ni se pide que hablen bien (`DISTRIBUTION.md` §10; las reglas del foro de Releases sancionan las interacciones falsas).

## 1. Criterios de selección
Buscar en YouTube/TikTok/Twitch: "fivem scripts showcase", "mejores scripts fivem", "fivem server owner", "como crear servidor fivem", "fivem tutorial qbcore/esx", "txadmin tutorial".

**Obligatorios (si falla uno, se descarta):**
1. Contenido de FiveM **para dueños/devs de server** (showcases de scripts, tutoriales de setup, reviews), no solo gameplay de RP.
2. Subió algo de FiveM en los **últimos 30 días**.
3. No promociona scripts filtrados o "leaks", ni bypasses de escrow o cheats.
4. Avisa cuando algo es patrocinado (o acepta hacerlo).

**Puntaje (0–2 cada uno, quedarse con los 10 de mayor puntaje, 5 ES/LATAM + 5 EN):**
| Criterio | 0 | 1 | 2 |
|---|---|---|---|
| Tamaño | <1K o >500K | 1K–10K o 100K–500K | 10K–100K (micro/medio: responde DMs, audiencia fiel) |
| Engagement | views/subs <2% | 2–8% | >8% o comentarios con preguntas técnicas |
| Audiencia de dueños | jugadores casuales | mixta | comentarios de "¿esto sirve para mi server?" |
| Idioma | — | inglés | español (menos competencia, D011) |
| Encaje | nunca habló de staff/admin | habló de admin menus | ya hizo videos de report systems / txAdmin / staff |
| Exclusividad | patrocinado por un report system competidor | tiene sponsors de scripts | sin conflicto |

**Hoja de seguimiento** (Google Sheets gratis): `nombre · plataforma · link · idioma · subs · puntaje · fecha DM · respuesta · código · ventas · notas`.

## 2. Propuesta de creator code
Datos de Tebex verificados ([Creator Codes](https://docs.tebex.io/creators/tebex-control-panel/engagement/creator-codes), [Fees](https://docs.tebex.io/creators/pricing-overview/tebex-fees-and-billing-overview)):
- Tebex cobra **+1%** sobre los pagos con código.
- Revenue share **máximo 50%** por transacción.
- En suscripciones, el descuento y el revenue share aplican **solo al primer pago**.
- Lo del creador se liquida a los **30 días hábiles**, en su Tebex Wallet (tiene que pasar su *Wallet Reference*).

**Oferta propuesta:**
| | Comprador | Creador |
|---|---|---|
| Core (pago único) | 10% de descuento con el código | 20% de cada venta |
| Pro (cuando exista) | 10% el primer mes | 30% del primer pago |
| Para empezar | — | Core gratis para su server de prueba, sin obligación de publicar nada |

Ejemplo con Core a $29: el comprador paga $26.10 → fees aprox. (15% FiveM + PayPal 2.49% + $0.40 + 1% del código) ≈ $5.20 → el creador recibe ~$5.20 (20% del pago; la base exacta sale del panel de Tebex) → nos quedan ~$15.70.

Revisar los números a los 60 días: si un creador convierte bien, subirle al 25%.

## 3. Plantillas de DM

### ES — primer contacto (DM de Discord/X o mail del canal)
```
Hola {{nombre}}, soy Fausto. Vi tu video de {{video concreto}} y {{algo puntual que te sirvió / te pareció bien}}.

Hice un script para servers de FiveM: Staff Integrity Suite. Es un sistema de reportes y moderación, pero lo que lo diferencia es que registra lo que hace el staff en una cadena SHA-256: si alguien edita o borra un log, el server te dice cuál.

Te paso el Core gratis para que lo pruebes en tu server, sin compromiso de publicar nada. Si te sirve y querés mostrarlo, te armo un código de Tebex: 10% de descuento para tu audiencia y 20% de cada venta para vos, pagado directo por Tebex.

Video de 80 s: {{YOUTUBE_ES}}
Lite gratis: {{GITHUB_URL}}

Si no te interesa, cero drama. ¡Gracias por leer!
```

### ES — seguimiento (una sola vez, 7 días después, sin insistir más)
```
Hola {{nombre}}, te escribí la semana pasada por Staff Integrity Suite. Por si se perdió: te paso la key del Core para tu server de prueba cuando quieras, sin compromiso. Si no es para tu canal, lo entiendo perfecto.
```

### EN — first contact
```
Hi {{name}}, I'm Fausto. I watched your video on {{specific video}} and {{one specific thing you liked}}.

I built a FiveM resource called Staff Integrity Suite. It's a report and moderation system, but the point is that it records what staff do in a SHA-256 hash chain: if someone edits or deletes a log entry, the server tells you which one.

Happy to give you Core for free to try on your test server, with no obligation to post anything. If you like it and want to show it, I'll set up a Tebex creator code: 10% off for your viewers and 20% of each sale for you, paid out by Tebex.

80-second demo: {{YOUTUBE_EN}}
Free Lite: {{GITHUB_URL}}

If it's not a fit, no worries at all. Thanks for reading!
```

### EN — follow-up (once, after 7 days)
```
Hi {{name}}, following up once on Staff Integrity Suite. The free Core key for your test server is there whenever you want it, no strings attached. If it's not for your channel, totally understood.
```

### Cuando aceptan (ES/EN)
```
ES: ¡Genial! Te paso: 1) la key del Core (te llega a tu cuenta cfx.re), 2) las docs: {{DOCS_URL}}, 3) para el código necesito tu Wallet Reference de Tebex (wallet.tebex.io → Withdraw → Your Details). Nombre del código: {{CODIGO}}. Solo te pido que avises que es un código patrocinado y que digas lo que te parezca, bueno o malo.

EN: Great! Here's: 1) the Core key (it goes to your cfx.re account), 2) docs: {{DOCS_URL}}, 3) for the code I need your Tebex Wallet Reference (wallet.tebex.io → Withdraw → Your Details). Code name: {{CODIGO}}. Only ask: mark it as sponsored and say whatever you honestly think, good or bad.
```

## 4. Material para el creador
- Video showcase + clips (`video-script.md`, `clips.md`) para usar libremente.
- Lista de features verificada (`launch/README.md`), incluyendo lo que NO hace. Pedirles que no muestren lo "próximamente" como si ya existiera.
- Datos de prueba para que lo muestren sin jugadores reales.

## 5. Reglas
- Máximo 5 DMs nuevos por semana (`DISTRIBUTION.md` §3), personalizados con un video concreto. Nada de DMs masivos copiados.
- Un seguimiento como máximo.
- No pedir reviews en el foro ni en Tebex a cambio del código.
