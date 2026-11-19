# X (@https_tatito) — hilo de devlog + 5 posts sueltos

> Build-in-public ES/EN, 1–2 por semana (`DISTRIBUTION.md` §3). Cada post: un dato real del avance, con captura o clip.
> Antes de publicar: el estado de cada feature tiene que coincidir con la matriz de `launch/README.md`. Las cifras se actualizan con el número real de ese día. Donde dice **[RESMON PENDIENTE]**, no publicar hasta medirlo.
> ES y EN como posts separados (no mezclar idiomas). X no está permitido como link en el foro, pero sí se puede linkear el foro desde X.

## Hilo de devlog — ES (7 posts)

**1/**
Terminé Staff Integrity Suite, un script para servers de FiveM que audita a tu staff.

Reportes, moderación y turnos, y todo queda en un registro que no se puede editar sin que se note.

Cómo funciona 🧵
*(adjunto: clip de "Verificar cadena" → rojo, ~10 s)*

**2/**
El problema: en la mayoría de los servers, el log del staff es texto plano. Cualquiera con acceso puede borrar un ban abusivo o cambiarle la razón, y nadie se entera.

**3/**
La solución es vieja y aburrida (eso es bueno): una cadena de hashes.

Cada entrada (quién, qué, a quién, cuándo, por qué) guarda el SHA-256 de la anterior. Si cambiás una letra en la #7, la verificación te marca la #7.

**4/**
¿Y si alguien reescribe la cadena entera?

Cada 20 entradas el hash actual va a un webhook de Discord y a un archivo aparte. Para engañar al ancla necesitás acceso al server y también a tu Discord.

**5/**
Qué tiene Core:
- tickets con reclamo, transferencia, respuestas predefinidas, evidencia con screenshot-basic y calificación 1–5 del jugador
- ban (temporal o permanente, por todas las cuentas), warn, spectate, revive y más, desde el ticket
- nadie puede sancionar a un rango superior
- turnos y estadísticas por staff
- ESX, QBCore, Qbox o standalone; también registra eventos de txAdmin
- JSON u oxmysql con migraciones automáticas
*(adjunto: captura del ticket con el diálogo de ban)*

**6/**
Lo probé en un FXServer real: Core pasa 30 de 30 checks y Lite 29 de 29.

En el server, escribir una entrada cuesta 0.09 ms y leer el estado 0.30 ms por llamada. resmon de cliente: [RESMON PENDIENTE].

**7/**
Hay una versión Lite gratis (MIT) con reportes y la cadena verificable, y Core en Tebex.

Español e inglés desde el día uno. Link en el perfil.

## Devlog thread — EN (7 posts)

**1/**
I finished Staff Integrity Suite, a FiveM script that audits your staff.

Reports, moderation and duty, and everything goes into a record that can't be edited without it showing.

How it works 🧵
*(attach: "Verify chain" → red clip, ~10 s)*

**2/**
The problem: on most servers, the staff log is plain text. Anyone with access can delete an abusive ban or change its reason, and nobody finds out.

**3/**
The fix is old and boring (that's good): a hash chain.

Each entry (who, what, to whom, when, why) stores the SHA-256 of the previous one. Change one letter in #7 and verification flags #7.

**4/**
What if someone rewrites the whole chain?

Every 20 entries the current hash goes to a Discord webhook and a separate file. To fool the anchor you need access to the server and to your Discord.

**5/**
What Core has:
- tickets with claim, transfer, canned replies, screenshot-basic evidence and a 1–5 player rating
- bans (temporary or permanent, across all accounts), warnings, spectate, revive and more, from the ticket
- nobody can sanction a higher rank
- duty and per-staff stats
- ESX, QBCore, Qbox or standalone; it also logs txAdmin events
- JSON or oxmysql with automatic migrations
*(attach: ticket screenshot with the ban dialog)*

**6/**
I tested it on a real FXServer: Core passes 30 of 30 checks and Lite 29 of 29.

On the server, writing an entry costs 0.09 ms and reading the state 0.30 ms per call. Client resmon: [RESMON PENDIENTE].

**7/**
There's a free Lite version (MIT) with reports and the verifiable chain, and Core on Tebex.

Spanish and English from day one. Link in bio.

---

## 5 posts sueltos (ES / EN)

**1 · Evidencia**
- ES: Pedís una captura desde el ticket y su SHA-256 va a la cadena de auditoría. Si después alguien cambia el archivo, el panel te avisa al abrirla. *(clip: pedir evidencia → abrirla → verificada)*
- EN: Request a screenshot from the ticket and its SHA-256 goes into the audit chain. If someone swaps the file later, the panel tells you when you open it. *(clip: request evidence → open it → verified)*

**2 · Bans por cuenta**
- ES: Un ban guarda todos los identificadores del jugador: license, Steam, Discord, Xbox y tokens. Si vuelve con una cuenta nueva que comparte uno, el ban la alcanza y queda registrado. Sin IP.
- EN: A ban stores every identifier the player has: license, Steam, Discord, Xbox and tokens. If they come back on a new account that shares one, the ban follows and it's logged. No IP.

**3 · Jerarquía**
- ES: Un mod no puede kickear, advertir ni congelar a un admin. Parece obvio, pero lo controla el server, no el botón del panel. *(captura del rechazo)*
- EN: A mod can't kick, warn or freeze an admin. Sounds obvious, but the server enforces it, not a panel button. *(screenshot of the rejection)*

**4 · Lite gratis**
- ES: Lite es gratis y MIT: /report, cola de tickets, panel y la cadena SHA-256 con "Verificar cadena". Si después pasás a Core, tus tickets y tu cadena quedan.
- EN: Lite is free and MIT: /report, ticket queue, panel and the SHA-256 chain with "Verify chain". If you move to Core later, your tickets and chain stay.

**5 · Pricing**
- ES: Decidí no cobrar por staff. En RP el staff es voluntario y rota todo el tiempo: cobrar por asiento castiga al server que tiene un equipo grande. Core es un pago único por server.
- EN: I decided not to charge per staff member. RP staff are volunteers and rotate constantly: per-seat pricing punishes servers with big teams. Core is a one-time payment per server.
