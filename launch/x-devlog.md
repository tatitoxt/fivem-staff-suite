# X (@https_tatito) — hilo de devlog + 5 posts sueltos

> Build-in-public ES/EN, 1–2 por semana (`DISTRIBUTION.md` §3). Cada post: un dato real del avance, con captura o clip.
> Antes de publicar: el estado de cada feature tiene que coincidir con la matriz de `launch/README.md`. Las cifras (tests, líneas, resmon) se actualizan con el número real de ese día.
> ES y EN como posts separados (no mezclar idiomas en el mismo post).

## Hilo de devlog — ES (7 posts)

**1/**
Estoy armando un script para servers de FiveM que hace una cosa que casi nadie hace: auditar al staff.

Reportes, moderación y turnos, pero todo queda en un registro que no se puede editar sin que se note.

Hilo con cómo funciona 🧵
*(adjunto: clip de `/audit` → BROKEN, ~10 s)*

**2/**
El problema: en la mayoría de los servers el log de lo que hace el staff es texto plano. Cualquiera con acceso al server puede borrar un ban abusivo o cambiarle la razón, y nadie se entera.

**3/**
La solución es vieja y aburrida (eso es bueno): una cadena de hashes.

Cada entrada (quién, qué, a quién, cuándo, por qué) guarda el SHA-256 de la anterior. Si cambiás una letra en la #7, la #7 deja de coincidir y la verificación te marca esa entrada.

**4/**
¿Y si alguien reescribe la cadena entera desde cero?

Por eso cada 20 entradas el hash actual se manda a un webhook de Discord y a un archivo aparte. Para engañar al ancla tendría que tener acceso a tu server Y a tu Discord.

**5/**
Lo que hay hoy:
- /report con reclamo y transferencia (no se puede reclamar dos veces)
- moderación desde el ticket con razón obligatoria
- /duty con turnos registrados
- panel in-game (F6): cola de tickets con notas internas, visor de auditoría con "Verificar cadena", dashboard de servicio
- rangos desde ESX, QBCore, Qbox o ACE: nadie es staff hasta que lo configures
- standalone, sin base de datos obligatoria
- 41 tests en verde, con CI en cada PR

**6/**
Lo que NO hace, para que quede claro:
- no es un anticheat
- no reemplaza a txAdmin (se usa junto a él)
- no intercepta todo lo que hacen otros scripts: registra lo que pasa por el sistema y lo que le mandes

Próximamente: chat con el jugador, analytics por staff (resueltos, tiempo de respuesta, rating).

**7/**
Va a haber una versión Lite gratis y una Core paga.

Si tenés server (sobre todo en español), me sirve muchísimo saber: ¿qué le pedirías a algo así? Respondé o mandame DM.

*(cuando exista: link al GitHub del Lite)*

## Devlog thread — EN (7 posts)

**1/**
I'm building a FiveM resource that does something almost nobody does: audit the staff.

Reports, moderation and duty tracking, but everything goes into a record that can't be edited without it showing.

How it works 🧵
*(attach: `/audit` → BROKEN clip, ~10 s)*

**2/**
The problem: on most servers, the staff action log is plain text. Anyone with server access can delete an abusive ban or change its reason, and nobody notices.

**3/**
The fix is old and boring (that's good): a hash chain.

Each entry (who, what, to whom, when, why) stores the SHA-256 of the previous one. Change one letter in #7 and #7 stops matching: verification points at that exact entry.

**4/**
What if someone rewrites the whole chain from scratch?

That's why every 20 entries the current hash goes to a Discord webhook and a separate file. To fool the anchor you'd need access to the server AND the Discord.

**5/**
What works today:
- /report with claim and transfer (no double claims)
- moderation from the ticket with a required reason
- /duty with logged shifts
- in-game panel (F6): ticket queue with internal notes, audit viewer with "Verify chain", duty dashboard
- ranks from ESX, QBCore, Qbox or ACE: nobody is staff until you configure it
- standalone, no database required
- 41 tests passing, with CI on every PR

**6/**
What it does NOT do:
- it's not an anticheat
- it doesn't replace txAdmin (it runs alongside it)
- it can't intercept everything other scripts do: it logs what goes through it and what you send it

Coming soon: chat with the player, per-staff analytics (resolved, response time, rating).

**7/**
There'll be a free Lite and a paid Core.

If you run a server: what would you want from something like this? Reply or DM me.

*(once it exists: link to the Lite GitHub)*

---

## 5 posts sueltos (ES / EN)

**1 · Timing GTA VI** (publicar la semana del lanzamiento)
- ES: GTA 6 salió en consolas. El RP de PC sigue en FiveM, y los dueños de server siguen con el mismo problema: no saben qué hace su staff cuando no miran. Estoy armando algo para eso.
- EN: GTA 6 is out on console. PC RP is still on FiveM, and server owners still have the same problem: they don't know what staff does when they're not looking. I'm building something for that.

**2 · Bug real cazado por un test** (dato verdadero: commit `77727ea`)
- ES: Un test me cazó un bug que habría sido feo: si alguien borraba las últimas entradas del log, el "head" guardado en memoria seguía diciendo que todo estaba bien. Ahora la verificación recalcula el head desde las entradas reales. Por esto se escriben tests.
- EN: A test caught a nasty bug: if someone deleted the last log entries, the cached head still said everything was fine. Verification now recomputes the head from the actual entries. This is why you write tests.

**3 · Encuesta**
- ES: Dueños de server FiveM: ¿dónde queda hoy el registro de lo que hace tu staff? (encuesta: txAdmin / Discord con webhooks / un script de logs / no queda en ningún lado)
- EN: FiveM server owners: where does your staff action log live today? (poll: txAdmin / Discord webhooks / a logs script / nowhere)

**4 · Decisión de precio**
- ES: Decidí no cobrar por staff. En RP el staff es voluntario y rota todo el tiempo: cobrar por asiento castiga al server que tiene un equipo grande. Va a ser por server: Lite gratis, Core pago único.
- EN: I decided not to charge per staff member. RP staff are volunteers and rotate constantly: per-seat pricing punishes servers with big teams. It'll be per server: free Lite, one-time Core.

**5 · Demo de 10 s**
- ES: Cambié una sola letra en un log de 20 entradas. Esto es lo que pasa. *(clip #1 de `clips.md`)*
- EN: I changed one letter in a 20-entry log. Here's what happens. *(clip #1 from `clips.md`)*
