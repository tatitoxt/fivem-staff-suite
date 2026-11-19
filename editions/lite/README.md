# Staff Suite Free Lite

## Español

Free Lite incluye reportes, una cola de tickets básicos y un visor de auditoría con verificación SHA-256. Guarda los tickets y la cadena en un archivo JSON. El contenido de este paquete se distribuye bajo la licencia MIT.

1. Extraé la carpeta `staff_suite/` en `resources/`.
2. Agregá `add_ace group.admin staff_suite.lite allow` y `ensure staff_suite` a `server.cfg`. Ajustá el grupo al que usa tu staff.
3. Los jugadores pueden enviar `/report <categoría> <descripción>`. El staff abre la cola con `/reports`, el visor con `/audit` o el panel con F6.

Staff Suite Core suma prioridades, notas y flujos avanzados de tickets, moderación, servicio y estadísticas, integraciones con frameworks, captura externa, oxmysql y exports para otros recursos. Para pasar de Lite a Core, respaldá `staff_suite_data.json`, reemplazá los archivos del recurso y configurá los permisos de Core antes de reiniciar. El nombre del recurso y el archivo de datos se conservan.

## English

Free Lite includes reports, a basic ticket queue and an audit viewer with SHA-256 verification. It stores tickets and the audit chain in a JSON file. The contents of this package are distributed under the MIT license.

1. Extract the `staff_suite/` folder into `resources/`.
2. Add `add_ace group.admin staff_suite.lite allow` and `ensure staff_suite` to `server.cfg`. Adjust the group to match your staff setup.
3. Players can submit `/report <category> <description>`. Staff can open the queue with `/reports`, the viewer with `/audit`, or the panel with F6.

Staff Suite Core adds priorities, notes and advanced ticket workflows, moderation, duty and analytics, framework integrations, external event capture, oxmysql and exports for other resources. To upgrade from Lite to Core, back up `staff_suite_data.json`, replace the resource files and configure Core permissions before restarting. Keep the resource and data file names.
