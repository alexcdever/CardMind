import { useState, useEffect } from 'react'
import { Layout, Typography, Form, Input, Button, Card, Divider, message, Badge, Switch } from 'antd'
import { ArrowLeftOutlined, WifiOutlined, GlobalOutlined } from '@ant-design/icons'
import { useNavigate } from 'react-router-dom'
import useDeviceStore from '@/stores/deviceStore'
import useAuthStore from '@/stores/authStore'
import useSyncStore from '@/stores/syncStore'
// validateDeviceNickname暂时未使用

const { Header, Content } = Layout
const { Title, Text, Paragraph } = Typography

/**
 * 设置页面组件
 * 允许用户管理设备信息和网络连接
 */
const SettingsScreen = () => {
  const navigate = useNavigate()
  const [form] = Form.useForm()
  const { deviceId, deviceType, nickname, updateNickname } = useDeviceStore()
  const { networkId, isAuthenticated, leaveNetwork } = useAuthStore()
  const { isOnline, setOnlineStatus } = useSyncStore()
  
  const [isSaving, setIsSaving] = useState(false)
  const [offlineMode, setOfflineMode] = useState(!isOnline)
  
  // 初始化表单值
  useEffect(() => {
    form.setFieldsValue({
      nickname: nickname
    })
  }, [nickname, form])
  
  // 处理昵称保存
  const handleSaveNickname = async (values: { nickname: string }) => {
    // 验证昵称
    if (!values.nickname.trim()) {
      message.error('昵称不能为空')
      return
    }
    
    setIsSaving(true)
    try {
      await updateNickname(values.nickname)
      message.success('设备昵称更新成功')
    } catch (error) {
      message.error('设备昵称更新失败')
      console.error('Update nickname error:', error)
    } finally {
      setIsSaving(false)
    }
  }
  
  // 处理离线模式切换
  const handleOfflineModeChange = (checked: boolean) => {
    setOfflineMode(checked)
    setOnlineStatus(!checked)
    message.info(checked ? '已切换为离线模式' : '已切换为在线模式')
  }
  
  // 处理退出网络
  const handleLeaveNetwork = async () => {
    try {
      await leaveNetwork()
      message.success('已退出网络')
      navigate('/')
    } catch (error) {
      message.error('退出网络失败')
      console.error('Leave network error:', error)
    }
  }
  
  return (
    <Layout className="min-h-screen">
      <Header className="bg-white shadow-sm px-6">
        <div className="flex items-center h-full">
          <Button 
            type="text" 
            icon={<ArrowLeftOutlined />}
            onClick={() => navigate(-1)}
            className="mr-4"
          >
            返回
          </Button>
          <Title level={4} className="m-0 text-primary">设置</Title>
        </div>
      </Header>
      
      <Content className="p-6">
        <div className="max-w-3xl mx-auto">
          <Title level={3} className="mb-6">设备与账户</Title>
          
          <Card className="mb-6">
            <Title level={5}>设备信息</Title>
            
            <Form
              form={form}
              layout="vertical"
              onFinish={handleSaveNickname}
            >
              <Form.Item
                  label="设备昵称"
                  name="nickname"
                  tooltip="给你的设备起个名字，便于在多设备同步时识别"
                >
                  <Input placeholder="请输入设备昵称" maxLength={30} />
                </Form.Item>
              
              <Form.Item>
                <Button type="primary" htmlType="submit" loading={isSaving}>
                  保存昵称
                </Button>
              </Form.Item>
            </Form>
            
            <Divider />
            
            <div>
              <Text strong className="block mb-2">设备ID：</Text>
              <Text code className="block break-all mb-3">{deviceId}</Text>
              
              <Text strong className="block mb-2">设备类型：</Text>
              <Text className="block mb-3">{deviceType}</Text>
            </div>
          </Card>
          
          <Card className="mb-6">
            <Title level={5}>网络连接</Title>
            
            <div className="mb-4">
              <div className="flex items-center justify-between mb-2">
                <Text>离线模式</Text>
                <Switch 
                  checked={offlineMode} 
                  onChange={handleOfflineModeChange}
                />
              </div>
              <Text type="secondary">
                开启后，数据将仅保存在本地设备上，不会与其他设备同步
              </Text>
            </div>
            
            <Divider />
            
            {isAuthenticated ? (
              <div>
                <div className="mb-4">
                  <Text strong className="block mb-2">当前网络ID：</Text>
                  <Text code className="block break-all mb-3">{networkId}</Text>
                  
                  <Badge status="success" text="已连接到网络" className="mb-3" />
                </div>
                
                <Button 
                  danger 
                  icon={<GlobalOutlined />} 
                  onClick={handleLeaveNetwork}
                >
                  退出网络
                </Button>
              </div>
            ) : (
              <div className="text-center py-4">
                <Badge status="default" text="未连接到网络" className="mb-4" />
                <Paragraph className="mb-4">
                  您当前未连接到任何网络。请返回主页并连接到网络以启用多设备同步。
                </Paragraph>
                <Button 
                  type="primary" 
                  icon={<WifiOutlined />}
                  onClick={() => navigate('/')}
                >
                  连接网络
                </Button>
              </div>
            )}
          </Card>
          
          <Card>
            <Title level={5}>关于</Title>
            <Paragraph>
              CardMind v1.0.0<br />
              一个简单、高效的跨设备笔记卡片应用
            </Paragraph>
          </Card>
        </div>
      </Content>
    </Layout>
  )
}

export default SettingsScreen