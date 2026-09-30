import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    host: true,
    port: 5173,
    // 容器内文件变更不走 inotify，开启轮询保证热更新可用
    watch: {
      usePolling: true
    },
    proxy: {
      // 开发环境把 /api 代理到 Rails，避免跨域
      // 本机直接跑时是 localhost:3000；docker compose 里通过 VITE_PROXY_TARGET 指向 api 服务
      '/api': {
        target: process.env.VITE_PROXY_TARGET || 'http://localhost:3000',
        changeOrigin: true
      }
    }
  }
})
