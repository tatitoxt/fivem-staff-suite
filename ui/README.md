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

`ui/dist/` no se versiona (`.gitignore`). Antes de empaquetar el resource para Tebex/escrow:

```bash
cd ui && npm ci && npm run build
```

El build genera `ui/dist/index.html` y `ui/dist/assets/*` con nombres estables (sin hash), que es lo que
lista `fxmanifest.lua` (`ui_page` + `files`). El zip de release debe incluir `ui/dist/` y puede excluir
`ui/src`, `ui/node_modules` y el resto de `ui/`.
