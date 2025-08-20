import { defineConfig, UserConfigExport } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA, VitePWAOptions } from 'vite-plugin-pwa';

// PWA配置选项
const pwaOptions: Partial<VitePWAOptions> = {
  registerType: 'autoUpdate',
  workbox: {
    globPatterns: ['**/*.{js,css,html,ico,png,svg}']
  },
  manifest: {
    name: 'CardMind',
    short_name: 'CardMind',
    description: '分布式笔记应用',
    theme_color: '#1890ff',
    background_color: '#ffffff',
    display: 'standalone',
    icons: [
      {
        src: 'pwa-192x192.png',
        sizes: '192x192',
        type: 'image/png'
      },
      {
        src: 'pwa-512x512.png',
        sizes: '512x512',
        type: 'image/png'
      }
    ]
  }
};

// Vite配置
const config: UserConfigExport = {
  plugins: [
    react(),
    VitePWA(pwaOptions)
  ],
  server: {
    port: 3000,
    open: true
  },
  build: {
    outDir: 'dist'
  }
};

export default defineConfig(config);