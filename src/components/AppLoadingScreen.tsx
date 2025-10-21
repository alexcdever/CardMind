import { Spin, Typography } from 'antd'
import { LoadingOutlined } from '@ant-design/icons'

const { Title } = Typography
const antIcon = <LoadingOutlined style={{ fontSize: 48 }} spin />

/**
 * 应用加载屏幕组件
 * 用于应用初始化过程中的显示
 */
const AppLoadingScreen = () => {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="text-center p-8">
        <div className="mb-6">
          {antIcon}
        </div>
        <Title level={3} className="text-primary mb-2">CardMind</Title>
        <Typography.Text className="text-gray-500">正在初始化应用...</Typography.Text>
      </div>
    </div>
  )
}

export default AppLoadingScreen