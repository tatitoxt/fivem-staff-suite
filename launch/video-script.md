# Guion del video showcase (60–90 s) — ES y EN

> Dos videos separados (YouTube ES y YouTube EN), mismo montaje. Grabado in-game en el server QA con OBS (Fausto, PC Windows, D007), 1920×1080 a 60 fps, de día, HUD limpio. Se muestra **Core**; el cierre menciona Lite.
> Estructura sugerida por Tebex: presentación → lo que lo diferencia → el script en acción, en 30–90 s.
> Nada del modo demo del navegador ni mockups. Si algo no existe (unfreeze, chat con el jugador, Pro), no aparece en pantalla.
> La escena 9 muestra resmon: hasta medirlo queda **[RESMON PENDIENTE]** y el video no se publica.

## Preparación de la grabación
- 3 cuentas de prueba en el server QA: `Jugador_01` (reporta), `Mod_Lucas` (rango mod) y la de Fausto (admin). Nombres inventados.
- `screenshot-basic` iniciado (evidencia) y `set staff_suite_webhook` apuntando a un canal de prueba (ancla).
- Antes de grabar: ~15 entradas en la cadena (reportes, reclamos, un turno, un warn).
- Para la escena de manipulación: frenar el resource, editar a mano en `staff_suite_data.json` el `reason` de una entrada (ej. #7: "cheating" → "bug") y volver a iniciar. Con oxmysql, editar la fila en la base.

---

## ES — "¿Quién audita a tu staff?" (~85 s)

| # | Tiempo | En pantalla | Texto en pantalla | Voz en off |
|---|---|---|---|---|
| 1 | 0–5 s | Un log de texto plano: "baneó a X por cheating" pasa a "por bug" y nada avisa | "Un admin puede editar esto." | "En casi todos los servers, el log del staff es un archivo que cualquiera con acceso puede editar." |
| 2 | 5–10 s | Logo + tagline | "Staff Integrity Suite" | "Staff Integrity Suite: reportes, moderación y turnos, con un registro que no se puede tocar sin que se note." |
| 3 | 10–20 s | `Jugador_01` escribe `/report player me mató sin rol`. Fausto abre el panel con F6 y el ticket aparece en la cola | "/report → panel (F6)" | "El jugador reporta y tu staff lo ve en el panel." |
| 4 | 20–30 s | Fausto reclama. `Mod_Lucas` intenta reclamarlo también → "ya fue reclamado". Fausto usa una respuesta predefinida y pide evidencia: la captura aparece en el ticket con la marca de verificada | "Sin doble reclamo · evidencia verificada" | "Uno lo toma, el otro se entera. La captura de pantalla queda en la cadena." |
| 5 | 30–42 s | Desde el ticket: spectate al acusado → vuelve → "Banear" → escribe "RDM reiterado", elige 1 día → banear | "Ban con razón y duración" | "Moderás desde el ticket. Sin razón no se banea, y el ban cubre todas las cuentas del jugador." |
| 6 | 42–48 s | `Mod_Lucas` (moderador) intenta expulsar a Fausto → "No podés moderar a un staff de rango superior." | "Los rangos se respetan" | "Y nadie puede sancionar a alguien de rango más alto." |
| 7 | 48–54 s | Se resuelve el ticket. A `Jugador_01` le aparece la calificación → elige 5. Corte al dashboard: resueltos, tiempo de respuesta y calificación de Fausto | "Calificación 1–5 · estadísticas por staff" | "El jugador califica la atención y vos ves cómo responde cada uno." |
| 8 | 54–70 s | Visor de auditoría con todo lo anterior → "Verificar cadena" en verde. Corte: se edita la entrada #7 → reinicio → "Verificar cadena" → rojo en la #7 y "sin garantía" en las siguientes. Inserto: el mensaje del ancla en Discord | "Cambiás una letra → se rompe en la #7" | "Cada entrada guarda el hash de la anterior. Si alguien cambia una letra, la verificación te dice dónde. Y el ancla en Discord guarda el original." |
| 9 | 70–78 s | `resmon` con `staff_suite` → **[RESMON PENDIENTE]**. Al lado: "Standalone · ESX · QBCore · Qbox · txAdmin · oxmysql" | "[RESMON PENDIENTE] ms" | "Funciona solo o con tu framework, y también registra lo que pasa en txAdmin." |
| 10 | 78–85 s | Logo + "Core en Tebex · Lite gratis en GitHub" + links | "Probá Lite gratis" | "Probalo gratis con Lite. Link abajo." |

## EN — "Who audits your staff?" (~85 s)

| # | Time | On screen | On-screen text | Voice-over |
|---|---|---|---|---|
| 1 | 0–5 s | A plain-text log: "banned X for cheating" becomes "for bug" and nothing complains | "Any admin can edit this." | "On most servers the staff log is a file anyone with access can edit." |
| 2 | 5–10 s | Logo + tagline | "Staff Integrity Suite" | "Staff Integrity Suite: reports, moderation and duty, with a record nobody can touch without it showing." |
| 3 | 10–20 s | `Jugador_01` types `/report player killed me with no RP`. Fausto opens the panel with F6 and the ticket is in the queue | "/report → panel (F6)" | "The player reports it and your staff sees it in the panel." |
| 4 | 20–30 s | Fausto claims it. `Mod_Lucas` tries to claim it too → "already claimed". Fausto sends a canned reply and requests evidence: the screenshot shows up in the ticket marked as verified | "No double claims · verified evidence" | "One takes it, the other gets told. The screenshot goes into the chain." |
| 5 | 30–42 s | From the ticket: spectate the accused → back → "Ban" → types "repeated RDM", picks 1 day → ban | "Ban with reason and duration" | "You moderate from the ticket. No reason, no ban, and the ban covers all of the player's accounts." |
| 6 | 42–48 s | `Mod_Lucas` (moderator) tries to kick Fausto → rejected for higher rank | "Ranks are enforced" | "And nobody can sanction someone above them." |
| 7 | 48–54 s | Ticket resolved. `Jugador_01` gets the rating prompt → picks 5. Cut to the dashboard: Fausto's resolved count, response time and rating | "1–5 rating · per-staff stats" | "Players rate the help and you see how each staff member responds." |
| 8 | 54–70 s | Audit viewer with everything above → "Verify chain" green. Cut: entry #7 is edited → restart → "Verify chain" → red at #7, "not guaranteed" after it. Insert: the anchor message in Discord | "Change one letter → breaks at #7" | "Every entry stores the hash of the one before. If someone changes a letter, verification shows you where. And the Discord anchor keeps the original." |
| 9 | 70–78 s | `resmon` with `staff_suite` → **[RESMON PENDIENTE]**. Next to it: "Standalone · ESX · QBCore · Qbox · txAdmin · oxmysql" | "[RESMON PENDIENTE] ms" | "Works standalone or with your framework, and it logs what happens in txAdmin too." |
| 10 | 78–85 s | Logo + "Core on Tebex · Lite free on GitHub" + links | "Try Lite for free" | "Try it free with Lite. Link below." |

## Notas de edición
- Subtítulos quemados en los dos idiomas (mucha gente mira sin sonido).
- Escena 8 es la más importante: si hay que recortar, recortar 3 o 7.
- Versión corta de 30 s para el carrusel de Tebex: escenas 2, 5, 8 y 10.
- La voz la graba Fausto. Si se usa TTS, avisarlo en la descripción.
