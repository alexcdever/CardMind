import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'
import useDeviceStore from './stores/deviceStore'
import syncService from './services/syncService'

// 初始化设备信息
const initializeApp = async () => {
  try {
    // 初始化设备
    await useDeviceStore.getState().initializeDevice()
    
    // 初始化同步服务
    syncService.initialize()
    
    console.log('应用初始化完成')
  } catch (error) {
    console.error('应用初始化失败:', error)
  }
}

// 启动应用
initializeApp()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
