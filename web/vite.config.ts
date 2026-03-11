import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const pairingProxyTarget = env.PAIRING_SERVICE_PROXY_TARGET || env.PAIRING_SERVICE_URL || 'http://127.0.0.1:8787'

  return {
    plugins: [react()],
    server: {
      proxy: {
        '/api': {
          target: pairingProxyTarget,
          changeOrigin: false,
        },
        '/health': {
          target: pairingProxyTarget,
          changeOrigin: false,
        },
      },
    },
  }
})
