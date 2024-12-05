import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export default defineConfig(({ mode }) => {
  const isDevelopment = mode === 'development';

  return {
    root: 'src',
    base: isDevelopment ? '/' : './',
    resolve: {
      alias: {
        '@': resolve(__dirname, 'src'),
        '@cardmind/core': resolve(__dirname, '../core/src')
      },
    },
    build: {
      outDir: '../dist',
      emptyOutDir: true,
      rollupOptions: {
        input: resolve(__dirname, 'src/main.tsx'),
      },
    },
    server: {
      port: 3000,
      strictPort: true,
      host: true,
      hot: true,
      open: false,
      compress: true,
    },
    plugins: [
      react()
    ],
    optimizeDeps: {
      include: ['@ant-design/icons', 'antd'],
    },
    clearScreen: false,
  };
});
