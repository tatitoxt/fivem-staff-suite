# Orkelya FiveM — Ecosistema de productos

Línea completa de infraestructura RP: moderación, IA y UI. Todo standalone,
ES-first, 0 dependencias duras, verificado E2E en FXServer real.

## Productos

| Producto | Repo | Free (MIT) | Pago | Estado |
|---|---|---|---|---|
| Staff Integrity Suite | tatitoxt/fivem-staff-suite | Lite (tickets + reports) | Core $29 (escrow) | 0.3.0 listo p/ Tebex |
| NPC AI | tatitoxt/fivem-npc-ai | Lite (motor completo) | Pack $39 (13 NPCs + voz + soporte) | 0.3.0, falta escrow |
| Loadscreen | tatitoxt/fivem-loadscreen | — | $9–12 | 0.2.0 listo p/ Tebex |

## Bundle

**Orkelya RP Starter — $59**: Suite Core + NPC Pack + Loadscreen
(valor separado $77–80 → ahorro ~20%). Copy en `fivem-loadscreen/launch/bundle-listing.md`.

## Diferenciadores vs marketplace

- **Auditoría SHA-256 verificable** en la Suite — ningún competidor lo ofrece.
- **NPC AI**: edge-tts gratis sin key + audio servido por el recurso (sin hosting)
  + memoria por jugador/NPC + quests con bridge ESX/QBCore + 13 NPCs escritos.
- **Loadscreen**: editor WYSIWYG in-game (único a este precio) + theme packs vendibles.
- **Theme packs / content packs** = contenido vendible aparte del script.

## Roadmap de venta

1. Suite Core 0.3.0 → asset Cfx 1188513 + package Tebex $29
2. NPC AI Lite → post foro (ES/EN, en `fivem-npc-ai/launch/forum-post.md`)
3. NPC Pack → escrow + Tebex $39
4. Loadscreen → Tebex $9–12
5. Bundle $59 cuando los 3 estén live

## Content packs como producto

- `pack/*.lua` en npc_ai: zonas vivas escritas (barrio/puerto/playa) — vendibles
  por separado o en el Pack.
- `themes/*.json` en loadscreen: temas importables — vendibles como packs.
- Modelo: script barato/base gratis → contenido premium recurrente.

## Pendiente (solo usuario)

- Upload zips a Cfx (1188513 suite + nuevos assets para npc/loadscreen)
- Packages Tebex + escrow submissions
- Key Groq real → test in-game npc_ai; resmon de los 3 recursos
- Post foro con screenshots/videos reales
