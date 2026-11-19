# Free Lite and Core

| Feature | Free Lite | Core |
|---|---|---|
| Reports and tickets | `/report`, queue, claim, resolve, close and reopen | Basic workflow, priorities, chat, internal notes, transfers, and advanced F2 features as they land |
| Audit | SHA-256 chain for panel actions, viewer and verification | Everything in Lite, external event capture, anchoring and audit export |
| Moderation, duty and analytics | — | In-ticket moderation, duty and staff analytics |
| Integrations and access | Standalone with a single staff ACE permission | Standalone, ESX, QBCore and Qbox with ranks and capabilities. Exports API for other resources |
| Storage | JSON file | JSON or oxmysql with a JSON backup |
| Distribution | Free for GitHub and forum distribution, MIT-licensed, editable Lua code | Package for Tebex and Cfx Asset Escrow |

## Build and install

Use Linux with Bash, Node.js 24 and npm, Lua 5.4 and `zip`. GitHub Actions builds and uploads both ZIPs as artifacts.

| Command | ZIP |
|---|---|
| `./scripts/build-release.sh --edition lite` | `dist/staff_suite_lite-<version>.zip` |
| `./scripts/build-release.sh --edition core` | `dist/staff_suite-<version>.zip` |

Extract `staff_suite/` into `resources/` and add `ensure staff_suite` to `server.cfg`. For Lite, also add `add_ace group.admin staff_suite.lite allow`, adjusting the group to match your server. Players submit `/report <category> <description>`. Staff can open the panel with F6, the queue with `/reports`, or the audit viewer with `/audit`.

In Lite, set `Config.CoreUrl` to the package's HTTPS URL when it is available to enable the Tebex link. The panel shows the Core details even if the field is empty.

## Upgrade from Lite to Core

Stop the resource, back up `staff_suite_data.json`, and replace the Lite files with Core. Keep the `staff_suite` resource name and restore the JSON file if you moved it. Set up [Core permissions](permissions.md), choose storage using the [installation guide](installation.md), and restart the resource. Core keeps Lite tickets and the audit chain, and can import the JSON into a fresh database.
