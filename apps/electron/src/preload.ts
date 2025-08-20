// Electron预加载脚本
// 在渲染进程和主进程之间建立安全的通信桥梁
import { contextBridge, ipcRenderer } from 'electron'

// 暴露给渲染进程的API
contextBridge.exposeInMainWorld('electronAPI', {
  // 示例：获取应用版本
  getAppVersion: () => ipcRenderer.invoke('get-app-version'),
  
  // 示例：打开外部链接
  openExternal: (url: string) => ipcRenderer.invoke('open-external', url),
  
  // 示例：最小化窗口
  minimizeWindow: () => ipcRenderer.invoke('minimize-window'),
  
  // 示例：关闭窗口
  closeWindow: () => ipcRenderer.invoke('close-window'),
  
  // 监听窗口事件
  onWindowEvent: (callback: (event: string) => void) => {
    ipcRenderer.on('window-event', (_, event) => callback(event))
  }
})

// 定义类型声明
declare global {
  interface Window {
    electronAPI: {
      getAppVersion: () => Promise<string>
      openExternal: (url: string) => Promise<void>
      minimizeWindow: () => Promise<void>
      closeWindow: () => Promise<void>
      onWindowEvent: (callback: (event: string) => void) => void
    }
  }
}