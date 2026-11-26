/// <reference types="vitest/config" />
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const contractsDir = fileURLToPath(new URL('../contracts', import.meta.url))
const adminDir = fileURLToPath(new URL('./src/admin', import.meta.url))

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { '@contracts': contractsDir, '@admin': adminDir },
  },
  server: {
    port: 5173,
    // العقود خارج مجلد المشروع؛ يسمح بقراءتها فقط.
    fs: { allow: ['.', contractsDir] },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/admin/test/setup.ts'],
    include: ['src/**/*.test.{ts,tsx}'],
    css: false,
  },
})
