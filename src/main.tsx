import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'
// 暂时注释掉PWA注册，直到配置完成
// import { registerSW } from 'virtual:pwa-register'

// 暂时注释掉Service Worker注册
// // 注册Service Worker以支持PWA功能
// const updateSW = registerSW({
//   onNeedRefresh() {
//     // 可以在这里显示更新提示
//     console.log('有新版本可用，请刷新页面')
//   },
//   onOfflineReady() {
//     // 可以在这里显示离线就绪提示
//     console.log('应用已准备好离线使用')
//   },
// })

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)