/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// FiveM sirve la NUI desde nui://<resource>/ui/dist/: rutas relativas y nombres
// de assets estables (sin hash) para que fxmanifest los liste con un glob simple.
export default defineConfig({
  base: './',
  plugins: [react()],
  server: {
    port: 5173,
    // el mock de dev lee locales/*.lua (fuera de ui/) para no duplicar strings
    fs: { allow: ['..'] },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    target: 'chrome103',
    assetsInlineLimit: 0,
    rollupOptions: {
      output: {
        entryFileNames: 'assets/index.js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name][extname]',
      },
    },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    css: { modules: { classNameStrategy: 'non-scoped' } },
  },
});
