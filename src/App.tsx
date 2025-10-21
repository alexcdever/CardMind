import { useState, useEffect } from 'react'
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { ConfigProvider } from 'antd'

// 导入状态管理
import useAuthStore from './stores/authStore'
import useDeviceStore from './stores/deviceStore'

// 导入组件
import AppLoadingScreen from './components/AppLoadingScreen'
import NetworkAuthScreen from './components/Auth/NetworkAuthScreen'
import MainScreen from './components/MainScreen'
import SettingsScreen from './components/Settings/SettingsScreen'
import ProtectedRoute from './components/ProtectedRoute'

function App() {
  const { isAuthenticated, joinNetwork } = useAuthStore()
  const { initializeDevice } = useDeviceStore()
  const [isLoading, setIsLoading] = useState(true)
  
  // 应用初始化
  useEffect(() => {
    const initializeApp = async () => {
      try {
        // 初始化设备信息
        await initializeDevice()
        
        // 检查是否已认证
        const savedNetworkId = localStorage.getItem('currentNetworkId')
        if (savedNetworkId) {
          try {
            await joinNetwork(savedNetworkId)
          } catch (error) {
            // 加入失败，清除保存的网络ID
            localStorage.removeItem('currentNetworkId')
          }
        }
      } finally {
        setIsLoading(false)
      }
    }
    
    initializeApp()
  }, [initializeDevice, joinNetwork])
  
  if (isLoading) {
    return <AppLoadingScreen />
  }
  
  return (
    <ConfigProvider
      theme={{
        token: {
          colorPrimary: '#3b82f6',
          colorTextSecondary: '#8b5cf6',
          colorSuccess: '#10b981',
          colorWarning: '#f59e0b',
          colorError: '#ef4444',
        },
      }}
    >
      <Router>
        <Routes>
          {/* 无需认证的路由 */}
          <Route path="/auth" element={<NetworkAuthScreen />} />
          <Route 
            path="/" 
            element={
              <ProtectedRoute isAuthenticated={isAuthenticated}>
                <MainScreen />
              </ProtectedRoute>
            } 
          />
          <Route 
            path="/settings" 
            element={
              <ProtectedRoute isAuthenticated={isAuthenticated}>
                <SettingsScreen />
              </ProtectedRoute>
            } 
          />
          {/* 重定向其他路径到首页或认证页面 */}
          <Route 
            path="*" 
            element={
              isAuthenticated 
                ? <Navigate to="/" replace /> 
                : <Navigate to="/auth" replace /> 
            } 
          />
        </Routes>
      </Router>
    </ConfigProvider>
  )
}

export default App