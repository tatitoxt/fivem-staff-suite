# NUI — Staff Integrity Suite

React 18 + TypeScript + Vite. Contrato de mensajes: `NUI_SPEC.md` (raíz). El puente Lua es `client/main.lua`.

## Desarrollo

```bash
cd ui
npm ci
npm run dev        # http://localhost:5173 con backend mock y datos demo
npm test           # smoke tests (vitest + testing-library)
npm run typecheck
```

En el navegador (fuera de FiveM) `src/nui.ts` enruta `send()` al mock (`src/mock/backend.ts`), que emite los
mismos mensajes que el adapter y lee los strings de `locales/*.lua`. La barra "Harness dev" permite
simular una manipulación de la entrada #27 y verificar que la cadena se rompe.

## Build de release

### Demo para el foro / Forum demo

Desde la raíz del repositorio / From the repository root:

```bash
npm --prefix ui ci --include=dev
npm --prefix ui run build:demo
npm --prefix ui run preview -- --outDir dist-demo
```

Publicá el contenido de `ui/dist-demo/` en un host estático gratuito y pegá su URL en el material del foro. El artifact `staff-suite-forum-demo` de GitHub Actions incluye ese directorio y las licencias de terceros. Los tickets, los escenarios y la cadena de auditoría son ficticios y se reinician al recargar la página. Para mostrar la verificación, usá **Simular manipulación**, verificá desde Auditoría, restaurá la entrada y verificá de nuevo.

Publish the contents of `ui/dist-demo/` to a free static host and use its URL in the forum material. The GitHub Actions artifact `staff-suite-forum-demo` includes the site and third-party licenses. Tickets, scenarios, and the audit chain use sample data and reset on reload. Use **Simulate tampering**, verify in the Audit view, restore the entry, then verify again.

### Core y Lite

`ui/dist/` no se versiona. Para preparar el ZIP de Tebex y Cfx Asset Escrow, ejecutá desde la raíz del repositorio:

```bash
./scripts/build-release.sh
```

El script ejecuta `npm ci` y `npm run build` dentro de `ui/`. El build genera `ui/dist/index.html` y
`ui/dist/assets/*` con los nombres estables que lista `fxmanifest.lua`. El ZIP incluye `ui/dist/`.
