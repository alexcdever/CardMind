import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src')
    }
  },
  server: {
    port: 5173,
    host: true
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
    // 优化chunk大小
    rollupOptions: {
      output: {
        manualChunks: {
          // 将大型依赖库单独打包
          'antd': ['antd'],
          'react': ['react', 'react-dom', 'react-router-dom'],
          'yjs': ['yjs', 'y-webrtc', 'y-indexeddb'],
          'zustand': ['zustand'],
        }
      }
    },
    // 调整chunk大小警告限制
    chunkSizeWarningLimit: 1500
  }
})
