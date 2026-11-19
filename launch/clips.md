# 10 clips para TikTok / Shorts / Reels

> Formato: vertical 1080×1920, 15–35 s, subtítulos quemados, el hook en pantalla en el primer segundo. Mínimo 2 por semana (`DISTRIBUTION.md` §3).
> Material: grabaciones reales del server QA o de las sesiones de Fausto (OBS). Nada que no exista. El panel ya está (#13–16): los clips [PANEL] se graban in-game en el server QA, no con el modo demo del navegador.
> Medir por clip: retención a los 3 s, % visto completo, clics al link de la bio. A las 4 semanas, repetir el ángulo que mejor rinda.
> Caption base: hook + `Lite gratis, link en bio` + `#fivem #gtarp #fivemscripts #gtav` (EN: `#fivem #gtarp #fivemdev #gtav`).

| # | Hook ES (pantalla + voz, 1 s) | Hook EN | Ángulo | Necesita |
|---|---|---|---|---|
| 1 | "¿Alguien borró un log de tu server? Mirá." | "Someone deleted a log on your server. Watch." | Detección de manipulación | Consola |
| 2 | "Tu log de staff es un .txt. Cualquier admin lo puede editar." | "Your staff log is a .txt file. Any admin can edit it." | Problema | Nada |
| 3 | "Este ban tenía otra razón. Te muestro cómo me di cuenta." | "This ban had a different reason. Here's how I caught it." | Historia | Consola |
| 4 | "¿Quién audita a tu staff?" | "Who audits your staff?" | Diferencial | [PANEL] |
| 5 | "2 admins, 1 ticket. Solo uno lo puede reclamar." | "2 admins, 1 ticket. Only one gets it." | Tickets | [PANEL] o E2E |
| 6 | "En mi server no se banea sin razón. Literalmente no se puede." | "On my server you can't ban without a reason. Literally." | Razón obligatoria | [PANEL] |
| 7 | "Cómo funciona un hash-chain, explicado con un ban de GTA RP." | "How a hash chain works, explained with a GTA RP ban." | Educativo | Consola |
| 8 | "GTA 6 salió en consola. El RP de PC sigue en FiveM, y tu staff sigue sin control." | "GTA 6 is out on console. PC RP is still on FiveM, and your staff is still unchecked." | Timing GTA VI | Nada |
| 9 | "Le pedí a mi staff que intente borrar un ban sin que me entere." | "I asked my staff to delete a ban without me noticing." | Reto | Consola (+ [PANEL] mejor) |
| 10 | "Armo scripts de FiveM en público. Día N: ..." | "Building FiveM scripts in public. Day N: ..." | Devlog | Nada |
| 11 | "Un moderador no puede expulsar a su jefe. Así lo armé." | "A moderator can't kick their boss. Here's how." | Jerarquía de rangos | [PANEL] |

---

## Guiones

**1 · "¿Alguien borró un log?" (20 s)**
- 0–1 s: consola con `[StaffSuite] audit OK: 18 entries`. Hook en pantalla.
- 1–8 s: abrir `staff_suite_data.json`, cambiar la razón de la entrada #7 ("cheating" → "bug"), guardar, reiniciar el resource.
- 8–15 s: `audit` → `[StaffSuite] audit BROKEN at 7`. Zoom al 7.
- 15–20 s: VO: "Cada entrada lleva el hash de la anterior. Cambiás una letra y se rompe. Staff Integrity Suite, Lite gratis."

**2 · "Tu log es un .txt" (15 s)**
- 0–1 s: un archivo de log de texto cualquiera. Hook.
- 1–8 s: se borra una línea de "ban" y se guarda. Nada avisa. VO: "Así de fácil desaparece un ban abusivo de un log común."
- 8–15 s: misma acción en Staff Integrity Suite → `audit BROKEN`. VO: "Acá no."

**3 · "Este ban tenía otra razón" (30 s)**
- Formato historia, cara de Fausto o voz sobre gameplay.
- VO: "Un admin baneó a un jugador por 'cheating'. Después la razón decía 'bug'. Alguien la cambió. La cadena de auditoría lo marcó en la entrada exacta, y el ancla en Discord tenía el hash original." Cierre: "Escenario armado en mi server de prueba." (es una recreación: decirlo).

**4 · "¿Quién audita a tu staff?" (25 s) [PANEL]**
- 0–1 s: hook sobre el visor de auditoría.
- 1–18 s: scroll por el timeline: reports, claims, kick con razón, duty. VO: "Cada reporte, cada kick, cada turno, con quién, a quién y por qué."
- 18–25 s: clic en "Verificar cadena" → verde. VO: "Y lo podés verificar cuando quieras."

**5 · "2 admins, 1 ticket" (15 s)**
- Pantalla partida: dos staff hacen clic en "Reclamar" a la vez → uno lo toma, al otro le sale "Este reporte ya fue reclamado por otro staff." VO: "Se terminó el 'pensé que lo estabas viendo vos'." Sin panel: salida del E2E (`doble claim rechazado`).

**6 · "No se banea sin razón" (20 s) [PANEL]**
- Ticket abierto → intentar "Banear" con la razón vacía: no se puede (grabar lo que muestre el panel). Escribir "RDM reiterado", elegir 1 día → banear → aparece la entrada en la auditoría con la razón y el vencimiento. VO: "Y queda registrado quién lo hizo, por qué y hasta cuándo."

**7 · "Hash-chain explicado con un ban" (35 s)**
- Pizarra simple: 3 cajas (entrada 1, 2, 3), flechas con el hash de la anterior. VO: "Cada entrada guarda una huella de la anterior. Si cambiás la 2, su huella cambia, y la 3 ya no coincide." Corte a la consola: `audit BROKEN at 2`. Cierre: "Esto es lo que usa Staff Integrity Suite. El Lite es gratis."

**8 · Timing GTA VI (20 s)**
- Publicar la semana del lanzamiento de GTA VI. Gameplay de FiveM RP + texto. VO: "GTA 6 salió en consolas. El RP de PC sigue en FiveM por un buen tiempo. Si tenés server, el problema de siempre sigue: no sabés qué hace tu staff cuando no mirás." Cierre con clip #1 acortado. No afirmar fechas de GTA VI en PC.

**9 · Reto al staff (35 s)**
- Fausto le pide a un staff de su server (con permiso y avisándole que se graba) que borre o edite un ban del archivo. VO al final: "Duró hasta el primer `/audit`." Si nadie se presta, no se hace: no simular con actores sin decirlo.

**10 · Devlog (20–30 s, serie)**
- Cara o pantalla + texto "Día N". Un avance real por clip (ej.: "hoy: el doble claim ya no pasa", "hoy: medí resmon, dio X ms"). Va de la mano con `x-devlog.md`.

**11 · "No puede expulsar a su jefe" (15 s) [PANEL]**
- Dos jugadores en el server QA: un moderador intenta expulsar o advertir a un admin → el server lo rechaza ("No podés moderar a un staff de rango superior."). VO: "Los rangos se respetan en el server, no en el botón."

> El 11 es un extra por si alguno de los 10 no se puede grabar.

## Reglas
- Nada de "tu staff te está robando": acusa al público que compra (los dueños confían en su staff). El ángulo es "sabé qué pasa" y no "desconfiá".
- Recreaciones: avisar en pantalla ("recreación en server de prueba").
- No usar música con copyright ni clips de streamers sin permiso.
