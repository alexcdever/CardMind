import { app, BrowserWindow, ipcMain, shell, dialog } from 'electron';
import * as path from 'path';

let mainWindow: BrowserWindow | null = null;

function createWindow() {
  // 创建浏览器窗口
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      nodeIntegration: false,  // 关闭 Node.js 集成
      contextIsolation: true,  // 启用上下文隔离
      preload: path.join(__dirname, 'preload.js')  // 预加载脚本
    }
  });

  // 加载应用
  const isDev = process.env.ELECTRON_START_URL != null;
  if (isDev) {
    console.log('Loading development server...');
    const startUrl = process.env.ELECTRON_START_URL || 'http://localhost:4000';
    console.log('Loading URL:', startUrl);
    console.log('Preload script path:', path.join(__dirname, 'preload.js'));
    mainWindow.loadURL(startUrl).catch(err => {
      console.error('Failed to load URL:', err);
    });
    // 打开开发者工具
    mainWindow.webContents.openDevTools();
  } else {
    console.log('Loading production build...');
    // 修改这里：使用正确的相对路径
    const indexPath = path.join(__dirname, '..', 'dist', 'index.html');
    console.log('Loading file:', indexPath);
    mainWindow.loadFile(indexPath).catch(err => {
      console.error('Failed to load file:', err);
    });
  }

  // 监听窗口关闭事件
  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  // 打印一些调试信息
  console.log('Environment:', isDev ? 'development' : 'production');
  console.log('Current directory:', __dirname);
  console.log('Window created');
}

// 处理 IPC 通信
ipcMain.handle('get-app-version', async () => {
  return app.getVersion();
});

ipcMain.handle('open-external', (_event, url: string) => {
  shell.openExternal(url);
});

ipcMain.handle('save-file', async (_event, content: string) => {
  if (mainWindow) {
    const result = await dialog.showSaveDialog(mainWindow);
    if (!result.canceled && result.filePath) {
      require('fs').writeFileSync(result.filePath, content);
      return result.filePath;
    }
  }
  return null;
});

ipcMain.handle('read-file', async (_event, filePath: string) => {
  const fs = require('fs');
  return fs.readFileSync(filePath, 'utf-8');
});

// 应用程序准备就绪时创建窗口
app.whenReady().then(() => {
  console.log('App is ready');
  createWindow();
});

// 所有窗口关闭时退出应用
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (mainWindow === null) {
    createWindow();
  }
});

// 添加未捕获异常处理
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});

// 添加未处理的 Promise 拒绝处理
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});

export {}; // 添加空导出以确保文件被视为 ES 模块