# Guion del video showcase (60–90 s) — ES y EN

> Dos videos separados (YouTube ES y YouTube EN), mismo montaje. Grabado en el server QA con OBS (Fausto, PC Windows, D007), 1920×1080 a 60 fps, de día in-game, HUD limpio.
> Estructura sugerida por Tebex para videos de scripts: presentación → features únicas → script en acción, en 30–90 s.
> **Prerrequisito:** panel final (#13–16) y números de resmon (#19). Las escenas marcadas [PANEL] necesitan el panel. Si se graba antes, usar la **variante consola** indicada en cada escena: también es real.
> Nada de mockups presentados como producto. Si una feature todavía no existe, no aparece en pantalla.

## Datos de prueba para la grabación
- 3 jugadores de prueba (`Jugador_01`, `Jugador_02`, `Mod_Lucas`), nombres inventados.
- Antes de grabar: ~15 entradas en la cadena (reports, claims, un kick con razón, duty in/out).
- Para la escena de manipulación: frenar el resource, editar a mano en `staff_suite_data.json` el campo `reason` de una entrada (ej. #7: "cheating" → "bug"), y volver a iniciar.

---

## ES — "¿Quién audita a tu staff?" (~80 s)

| # | Tiempo | En pantalla | Texto en pantalla | Voz en off |
|---|---|---|---|---|
| 1 | 0–5 s | Plano negro → un log de texto plano se edita solo: "baneó a X por cheating" pasa a "baneó a X por bug" | "Un admin puede editar esto." | "En casi todos los servers, el log del staff es un archivo que cualquier admin con acceso puede editar." |
| 2 | 5–10 s | Logo + nombre | **Staff Integrity Suite** · "El staff suite que audita a tu staff" | "Staff Integrity Suite registra lo que hace tu staff, y si alguien lo toca, se nota." |
| 3 | 10–22 s | Jugador escribe `/report player me mató sin rol` → notificación "Reporte #4 creado" | `/report` | "El jugador reporta con un comando. El ticket llega al staff." |
| 4 | 22–34 s | [PANEL] Mod_Lucas abre F6 → cola → reclama el #4 → otro staff intenta reclamarlo → "Este reporte ya fue reclamado". *Variante consola:* salida del resource de E2E (`tests/e2e_resource`): `[SSTEST] ok   doble claim rechazado`. | "Reclamar · transferir · resolver" | "Lo reclama un staff, y nadie más se lo puede pisar. Se puede transferir, resolver o reabrir." |
| 5 | 34–46 s | [PANEL] Desde el ticket: goto → kick → pide razón → escribe "RDM reiterado" → kick | "Razón obligatoria" | "La moderación se hace desde el mismo ticket, y para un kick o un ban, la razón es obligatoria." |
| 6 | 46–58 s | [PANEL] Visor de auditoría: timeline con seq, actor → target, razón, hash. Zoom a `prev_hash` de una entrada = `hash` de la anterior. *Variante consola:* el JSON con dos entradas, resaltando los hashes. | "Cada entrada lleva el hash de la anterior" | "Todo queda en una cadena SHA-256: cada entrada lleva el hash de la anterior." |
| 7 | 58–70 s | Corte: archivo editado (entrada #7). Clic en "Verificar cadena" → rojo "Cadena ROTA en la entrada 7". *Variante consola:* `audit` → `audit BROKEN at 7`. | "Alguien editó la #7" | "Si alguien cambia una razón, borra un ban o reordena entradas, la verificación te dice exactamente dónde se rompió." |
| 8 | 70–76 s | Canal de Discord con mensajes "Audit anchor · seq 20 · hash…" | "Ancla fuera del server" | "Y cada tantas entradas, el hash queda en tu Discord, fuera del alcance del que tenga acceso al server." |
| 9 | 76–84 s | resmon con `staff_suite` · tabla Lite / Core | "Lite gratis · Core {{PRECIO_CORE}}" · "Standalone · ES/EN" | "Funciona standalone, sin base de datos. Lite gratis, Core con moderación y permisos por rango." |
| 10 | 84–90 s | Links | "Link en la descripción" | "Probalo gratis. Link abajo." |

**Descripción de YouTube (ES):**
```
Staff Integrity Suite: reportes, moderación desde el ticket y un registro del staff que no se puede editar sin que se note (cadena SHA-256).

00:00 El problema de los logs del staff
00:10 Reportes (/report)
00:22 Reclamar tickets
00:34 Moderación con razón obligatoria
00:46 Cadena de auditoría
00:58 Detección de manipulación
01:10 Ancla en Discord

Lite gratis: {{GITHUB_URL}}
Core: {{TEBEX_URL}}
Docs: {{DOCS_URL}}
Soporte: {{DISCORD_URL}}

No es un anticheat ni reemplaza a txAdmin: se usa junto a él.
#FiveM #GTARP #FiveMScripts #ServerFiveM
```

---

## EN — "Who audits your staff?" (~80 s)

| # | Time | On screen | On-screen text | Voice-over |
|---|---|---|---|---|
| 1 | 0–5 s | Black → a plain-text log edits itself: "banned X for cheating" becomes "banned X for bug" | "An admin can edit this." | "On most servers, the staff log is a file any admin with access can edit." |
| 2 | 5–10 s | Logo + name | **Staff Integrity Suite** · "The staff suite that audits your staff" | "Staff Integrity Suite records what your staff does, and if someone touches the record, it shows." |
| 3 | 10–22 s | Player types `/report player killed me with no RP` → "Report #4 created" | `/report` | "Players report with one command. The ticket goes to staff." |
| 4 | 22–34 s | [PANEL] Mod_Lucas opens F6 → queue → claims #4 → another staff tries → "already claimed". *Console variant:* output of the E2E resource (`tests/e2e_resource`): `[SSTEST] ok   doble claim rechazado`. | "Claim · transfer · resolve" | "One staff member claims it, and nobody else can take it over. Transfer, resolve or reopen it." |
| 5 | 34–46 s | [PANEL] From the ticket: goto → kick → reason prompt → "repeated RDM" → kick | "Reason required" | "Moderation happens right from the ticket, and kicks and bans require a reason." |
| 6 | 46–58 s | [PANEL] Audit viewer: timeline with seq, actor → target, reason, hash. Zoom on `prev_hash` matching the previous `hash`. *Console variant:* the JSON with two entries, hashes highlighted. | "Each entry carries the previous hash" | "Everything goes into a SHA-256 chain: each entry carries the hash of the one before it." |
| 7 | 58–70 s | Cut: edited file (entry #7). Click "Verify chain" → red "Chain BROKEN at entry 7". *Console variant:* `audit` → `audit BROKEN at 7`. | "Someone edited #7" | "If someone changes a reason, deletes a ban or reorders entries, verification shows exactly where it broke." |
| 8 | 70–76 s | Discord channel with "Audit anchor · seq 20 · hash…" | "Anchored off-server" | "And every few entries, the hash is posted to your Discord, out of reach of whoever has server access." |
| 9 | 76–84 s | resmon with `staff_suite` · Lite / Core table | "Lite free · Core {{PRECIO_CORE}}" · "Standalone · EN/ES" | "It runs standalone, no database needed. Lite is free; Core adds moderation and rank permissions." |
| 10 | 84–90 s | Links | "Link in the description" | "Try it free. Link below." |

**YouTube description (EN):**
```
Staff Integrity Suite: reports, moderation from the ticket and a staff log that can't be edited without it showing (SHA-256 hash chain).

00:00 The problem with staff logs
00:10 Reports (/report)
00:22 Claiming tickets
00:34 Moderation with a required reason
00:46 The audit chain
00:58 Tamper detection
01:10 Discord anchor

Lite (free): {{GITHUB_URL}}
Core: {{TEBEX_URL}}
Docs: {{DOCS_URL}}
Support: {{DISCORD_URL}}

Not an anticheat and not a txAdmin replacement: it runs alongside it.
#FiveM #GTARP #FiveMScripts #FiveMServer
```

## Notas de producción
- Voz: la de Fausto (ES) es lo más creíble. EN: la misma voz con subtítulos, o una voz TTS gratis avisando que es TTS. Nada de voces de famosos.
- Subtítulos quemados en los dos idiomas (mucha gente mira sin sonido).
- Música sin copyright (YouTube Audio Library), baja, debajo de la voz.
- Escena 7 es la que vende: darle 2–3 s de pausa al rojo antes de cortar.
- Versión vertical de 30 s (escenas 1, 6, 7, 10) → sirve como clip #1 de `clips.md`.
