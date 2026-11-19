# Staff Integrity Suite (FiveM)

**ES** · [EN](#english)

**El único que audita a tu staff.** Reportes, moderación dentro del ticket, duty y un audit log con hash-chain SHA-256 que delata cualquier edición o borrado. Español-first, también en inglés.

Versión **0.1.0**. Lo marcado **(próximamente)** está planeado pero todavía no está implementado.

## Features

- **Reportes/tickets:** `/report`, máquina de estados (abierto → reclamado → en curso → resuelto → cerrado, reabrir), claim con lock, transferencia.
- **Chat del ticket:** chat dentro del ticket con notas internas y transferencia a otro staff conectado.
- **Moderación dentro del ticket:** goto, bring, freeze, heal y kick con capability, auditadas; kick con razón obligatoria. Ban, warn, spectate y revive están deshabilitadas **(próximamente)**.
- **Duty:** `/duty`, horas y sesiones por staff.
- **Panel NUI** (`F6`): auditoría, reportes, dashboard, servicio y ajustes; cada uno ve solo lo que su rango permite.
- **Auditoría verificable:** cada acción queda encadenada con SHA-256; verificación desde consola, panel o export.
- **Anclaje off-box:** archivo `audit_export.log` + webhook de Discord.
- **Permisos por rango** (least-privilege, capabilities), con detección automática de Qbox, QBCore y ESX, o ACE `staff_suite.<rango>` en standalone.
- **Persistencia:** archivo JSON sin dependencias, u oxmysql (MySQL/MariaDB).
- **ES/EN** con locales abiertos.
- **(próximamente):** calificación de tickets, ban/warn/spectate/revive, captura de eventos del framework y de txAdmin.

No reemplaza a txAdmin: noclip, god y spawn siguen ahí.

## Ediciones

| Edición | Precio | Incluye |
|---|---|---|
| **Lite** | $0 | Reportes básicos, auditoría con hash-chain de lo que pasa por el panel, visor. |
| **Core** | $29–39 pago único | Suite completo: reportes avanzados, moderación en ticket, duty/analytics, auditoría unificada con export off-box, permisos por rango, multi-framework. |
| **Integrity Pro** | $8–12/mes por server | **(próximamente)** Inventario de permisos cross-system, permisos con vencimiento, flags de anomalías, case files, apelaciones, dashboard del dueño. |

Venta por Tebex con escrow de Cfx **(próximamente)**.

## Requisitos

- FXServer reciente (Lua 5.4).
- Opcional: oxmysql + MySQL/MariaDB.
- Opcional: ESX Legacy, QBCore o Qbox (se detectan solos con `Config.Framework = 'auto'`). Sin framework, permisos por ACE.

## Paquete para Cfx Asset Escrow

Desde el repositorio, ejecutá `./scripts/build-release.sh` en Linux con Bash, Node.js 24 y npm, Lua 5.4 y `zip`. El script compila la NUI y genera `dist/staff_suite-<version>.zip` con una carpeta raíz `staff_suite/`. La versión sale de `fxmanifest.lua`. GitHub Actions también publica ese ZIP como artifact. Para instalar el recurso, extraé `staff_suite/` en `resources/` y agregá `ensure staff_suite` a `server.cfg`.

`escrow_ignore` mantiene editables `config.lua`, `server/config.lua` y `locales/*.lua`. Los bridges quedan protegidos porque la selección de framework y los mapeos de permisos y jobs se ajustan en la configuración abierta. El build de la NUI se incluye en el ZIP y Cfx Asset Escrow no cifra la NUI.

## Documentación

- [Instalación](docs/es/instalacion.md)
- [Configuración (`config.lua` y `server/config.lua`)](docs/es/configuracion.md)
- [Rangos y permisos](docs/es/permisos.md)
- [Panel (NUI)](docs/es/panel.md)
- [Auditoría: export y verificación](docs/es/auditoria.md)
- [FAQ y solución de problemas](docs/es/faq.md)
- [QA y E2E en FXServer](docs/es/qa.md)

## Tests

```
lua5.4 tests/run_all.lua
cd ui && npm ci && npm test
FIVEM_LICENSE_KEY=... scripts/e2e-fxserver.sh   # E2E en FXServer real, ver docs/es/qa.md
```

---

## English

**The only one that audits your staff.** Reports, in-ticket moderation, duty and an audit log with a SHA-256 hash chain that exposes any edit or deletion. Spanish-first, also in English.

Version **0.1.0**. Anything marked **(coming soon)** is planned but not implemented yet.

### Features

- **Reports/tickets:** `/report`, state machine (open → claimed → in progress → resolved → closed, reopen), locked claim, transfer.
- **Ticket chat:** in-ticket chat with internal notes and transfer to another online staff member.
- **In-ticket moderation:** goto, bring, freeze, heal and kick with capability check, audited; kick requires a reason. Ban, warn, spectate and revive are disabled **(coming soon)**.
- **Duty:** `/duty`, hours and sessions per staff member.
- **NUI panel** (`F6`): audit, reports, dashboard, duty and settings; each person only sees what their rank allows.
- **Verifiable audit log:** every action is chained with SHA-256; verify from console, panel or export.
- **Off-box anchoring:** `audit_export.log` file + Discord webhook.
- **Rank-based permissions** (least privilege, capabilities), with automatic Qbox, QBCore and ESX detection, or `staff_suite.<rank>` ACEs in standalone.
- **Persistence:** dependency-free JSON file, or oxmysql (MySQL/MariaDB).
- **ES/EN** with open locales.
- **(coming soon):** ticket ratings, ban/warn/spectate/revive, framework and txAdmin event capture.

It does not replace txAdmin: noclip, god and spawning stay there.

### Editions

| Edition | Price | Includes |
|---|---|---|
| **Lite** | $0 | Basic reports, hash-chain audit of everything done through the panel, viewer. |
| **Core** | $29–39 one-time | Full suite: advanced reports, in-ticket moderation, duty/analytics, unified audit log with off-box export, rank permissions, multi-framework. |
| **Integrity Pro** | $8–12/month per server | **(coming soon)** Cross-system permission inventory, expiring permissions, anomaly flags, case files, appeals, owner dashboard. |

Sold on Tebex with Cfx escrow **(coming soon)**.

### Requirements

- Recent FXServer (Lua 5.4).
- Optional: oxmysql + MySQL/MariaDB.
- Optional: ESX Legacy, QBCore or Qbox (auto-detected with `Config.Framework = 'auto'`). Without a framework, permissions come from ACE.

### Cfx Asset Escrow package

Run `./scripts/build-release.sh` from the repository on Linux with Bash, Node.js 24 and npm, Lua 5.4, and `zip`. The script builds the NUI and creates `dist/staff_suite-<version>.zip` with a top-level `staff_suite/` folder. The version comes from `fxmanifest.lua`. GitHub Actions also publishes the ZIP as an artifact. To install the resource, extract `staff_suite/` into `resources/` and add `ensure staff_suite` to `server.cfg`.

`escrow_ignore` keeps `config.lua`, `server/config.lua`, and `locales/*.lua` editable. The bridges stay protected because framework selection and permission and job mappings are managed in the open configuration. The ZIP includes the compiled NUI, which Cfx Asset Escrow does not encrypt.

### Documentation

- [Installation](docs/en/installation.md)
- [Configuration (`config.lua` and `server/config.lua`)](docs/en/configuration.md)
- [Ranks and permissions](docs/en/permissions.md)
- [Panel (NUI)](docs/en/panel.md)
- [Audit: export and verification](docs/en/audit.md)
- [FAQ and troubleshooting](docs/en/faq.md)
- [QA and FXServer E2E](docs/en/qa.md)

### Tests

```
lua5.4 tests/run_all.lua
cd ui && npm ci && npm test
FIVEM_LICENSE_KEY=... scripts/e2e-fxserver.sh   # real FXServer E2E, see docs/en/qa.md
```
