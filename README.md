# Staff Integrity Suite (FiveM)

**ES** · [EN](#english)

**El único que audita a tu staff.** Reportes, moderación dentro del ticket, duty y un audit log con hash-chain SHA-256 que delata cualquier edición o borrado. Español-first, también en inglés.

Versión **0.1.0**. Lo marcado **(próximamente)** está planeado pero todavía no está implementado.

## Features

- **Reportes/tickets:** `/report`, máquina de estados (abierto → reclamado → en curso → resuelto → cerrado, reabrir), claim con lock, transferencia.
- **Moderación dentro del ticket:** goto, bring, freeze, heal y kick con capability y razón obligatoria. Ban, warn, spectate y revive quedan auditados; su ejecución en juego está **(próximamente)**.
- **Duty:** `/duty`, horas y sesiones por staff.
- **Auditoría verificable:** cada acción queda encadenada con SHA-256; verificación desde consola, panel o export.
- **Anclaje off-box:** archivo `audit_export.log` + webhook de Discord.
- **Permisos por rango** (least-privilege, capabilities).
- **Persistencia:** archivo JSON sin dependencias, u oxmysql (MySQL/MariaDB).
- **ES/EN** con locales abiertos.
- **(próximamente):** panel NUI, mapeo de rangos ESX/QBCore/Qbox/ACE, ratings y chat de tickets en el panel, captura de eventos del framework y txAdmin.

No reemplaza a txAdmin: noclip, god y spawn siguen ahí.

## Ediciones

| Edición | Precio | Incluye |
|---|---|---|
| **Lite** | $0 | Reportes básicos, auditoría con hash-chain de lo que pasa por el panel, visor. |
| **Core** | $29–39 pago único | Suite completo: reportes avanzados, moderación en ticket, duty/analytics, auditoría unificada con export off-box, permisos por rango, multi-framework. |
| **Integrity Pro** | $8–12/mes por server | **(próximamente)** Inventario de permisos cross-system, permisos con vencimiento, flags de anomalías, case files, apelaciones, dashboard del dueño. |

Venta por Tebex con escrow de Cfx **(próximamente)**. `config.lua`, `locales/` y `ui/` quedan abiertos.

## Requisitos

- FXServer reciente (Lua 5.4).
- Opcional: oxmysql + MySQL/MariaDB.
- Opcional: ESX, QBCore o Qbox (en 0.1.0 corre en modo standalone).

## Documentación

- [Instalación](docs/es/instalacion.md)
- [Configuración (`config.lua`)](docs/es/configuracion.md)
- [Rangos y permisos](docs/es/permisos.md)
- [Auditoría: export y verificación](docs/es/auditoria.md)
- [FAQ y solución de problemas](docs/es/faq.md)

## Tests

```
lua5.4 tests/run_all.lua
```

---

## English

**The only one that audits your staff.** Reports, in-ticket moderation, duty and an audit log with a SHA-256 hash chain that exposes any edit or deletion. Spanish-first, also in English.

Version **0.1.0**. Anything marked **(coming soon)** is planned but not implemented yet.

### Features

- **Reports/tickets:** `/report`, state machine (open → claimed → in progress → resolved → closed, reopen), locked claim, transfer.
- **In-ticket moderation:** goto, bring, freeze, heal and kick with capability check and mandatory reason. Ban, warn, spectate and revive are audited; in-game execution is **(coming soon)**.
- **Duty:** `/duty`, hours and sessions per staff member.
- **Verifiable audit log:** every action is chained with SHA-256; verify from console, panel or export.
- **Off-box anchoring:** `audit_export.log` file + Discord webhook.
- **Rank-based permissions** (least privilege, capabilities).
- **Persistence:** dependency-free JSON file, or oxmysql (MySQL/MariaDB).
- **ES/EN** with open locales.
- **(coming soon):** NUI panel, ESX/QBCore/Qbox/ACE rank mapping, ticket ratings and chat in the panel, framework and txAdmin event capture.

It does not replace txAdmin: noclip, god and spawning stay there.

### Editions

| Edition | Price | Includes |
|---|---|---|
| **Lite** | $0 | Basic reports, hash-chain audit of everything done through the panel, viewer. |
| **Core** | $29–39 one-time | Full suite: advanced reports, in-ticket moderation, duty/analytics, unified audit log with off-box export, rank permissions, multi-framework. |
| **Integrity Pro** | $8–12/month per server | **(coming soon)** Cross-system permission inventory, expiring permissions, anomaly flags, case files, appeals, owner dashboard. |

Sold on Tebex with Cfx escrow **(coming soon)**. `config.lua`, `locales/` and `ui/` stay open.

### Requirements

- Recent FXServer (Lua 5.4).
- Optional: oxmysql + MySQL/MariaDB.
- Optional: ESX, QBCore or Qbox (0.1.0 runs in standalone mode).

### Documentation

- [Installation](docs/en/installation.md)
- [Configuration (`config.lua`)](docs/en/configuration.md)
- [Ranks and permissions](docs/en/permissions.md)
- [Audit: export and verification](docs/en/audit.md)
- [FAQ and troubleshooting](docs/en/faq.md)

### Tests

```
lua5.4 tests/run_all.lua
```
