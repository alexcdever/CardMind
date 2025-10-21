import { Navigate, useLocation } from 'react-router-dom'
import { Spin } from 'antd'

interface ProtectedRouteProps {
  isAuthenticated: boolean;
  children: React.ReactNode;
  loading?: boolean;
}

/**
 * 受保护路由组件
 * 用于保护需要认证才能访问的路由
 */
const ProtectedRoute: React.FC<ProtectedRouteProps> = ({ 
  isAuthenticated, 
  children, 
  loading = false 
}) => {
  const location = useLocation()
  
  // 如果正在加载，显示加载状态
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Spin size="large" />
      </div>
    )
  }
  
  // 如果未认证，重定向到认证页面
  if (!isAuthenticated) {
    return <Navigate to="/auth" replace state={{ from: location }} />
  }
  
  // 已认证，渲染子组件
  return <>{children}</>
}

export default ProtectedRoute