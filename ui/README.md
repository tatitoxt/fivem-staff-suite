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

`ui/dist/` no se versiona. Para preparar el ZIP de Tebex y Cfx Asset Escrow, ejecutá desde la raíz del repositorio:

```bash
./scripts/build-release.sh
```

El script ejecuta `npm ci` y `npm run build` dentro de `ui/`. El build genera `ui/dist/index.html` y
`ui/dist/assets/*` con los nombres estables que lista `fxmanifest.lua`. El ZIP incluye `ui/dist/`.
