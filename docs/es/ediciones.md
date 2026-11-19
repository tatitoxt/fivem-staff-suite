# Free Lite y Core

| Función | Free Lite | Core |
|---|---|---|
| Reportes y tickets | `/report`, cola, reclamar, resolver, cerrar y reabrir | Flujo básico, prioridades, chat, notas internas, transferencias, respuestas predefinidas, calificación y evidencia |
| Auditoría | Cadena SHA-256 de acciones del panel, visor y verificación | Todo Lite, captura externa, anclajes y exportación de auditoría |
| Moderación, turnos y estadísticas | — | Acciones desde el ticket, duty y analytics |
| Integraciones y acceso | Standalone, un permiso ACE para staff | Standalone, ESX, QBCore y Qbox con rangos y capabilities. API de exports para otros recursos |
| Persistencia | Archivo JSON | JSON u oxmysql con respaldo JSON |
| Distribución | Gratis para GitHub/foro, licencia MIT, código Lua editable | Paquete para Tebex y Cfx Asset Escrow |

## Compilar e instalar

Usá Linux con Bash, Node.js 24 y npm, Lua 5.4 y `zip`. GitHub Actions compila y publica ambos ZIP como artifacts.

| Comando | ZIP |
|---|---|
| `./scripts/build-release.sh --edition lite` | `dist/staff_suite_lite-<versión>.zip` |
| `./scripts/build-release.sh --edition core` | `dist/staff_suite-<versión>.zip` |

Extraé `staff_suite/` en `resources/` y agregá `ensure staff_suite` a `server.cfg`. En Lite, agregá también `add_ace group.admin staff_suite.lite allow`, adaptando el grupo a tu servidor. Los jugadores envían `/report <categoría> <descripción>`. El staff abre el panel con F6, la cola con `/reports` o la auditoría con `/audit`.

En Lite, el enlace a Tebex del panel se habilita con `Config.CoreUrl` cuando tengas la URL HTTPS del paquete. El panel muestra la información de Core aunque ese campo esté vacío.

## Pasar de Lite a Core

Detené el recurso, respaldá `staff_suite_data.json` y reemplazá los archivos de Lite por los de Core. Conservá el nombre `staff_suite` y restaurá el JSON si lo moviste. Ajustá los [permisos de Core](permisos.md), elegí la persistencia desde la [guía de instalación](instalacion.md) y reiniciá el recurso. Core conserva los tickets y la cadena de Lite y puede importar el JSON a una base nueva.
