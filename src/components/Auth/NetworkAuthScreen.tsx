import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Card, Form, Input, Button, Typography, Divider, message } from 'antd'
import { ReloadOutlined, UserAddOutlined } from '@ant-design/icons'
import useAuthStore from '@/stores/authStore'
import { NetworkAuthState } from '@/types/auth.types'
import { sanitizeInput } from '@/utils/validation'

const { Title, Paragraph, Text } = Typography
const { Item } = Form

/**
 * 网络认证页面组件
 * 用于用户创建网络或加入现有网络
 */
const NetworkAuthScreen = () => {
  const navigate = useNavigate()
  const { generateNetworkId, validateNetworkId, joinNetwork, isLoading, error } = useAuthStore()
  
  const [form] = Form.useForm<{ networkId: string }>()
  const [localState, setLocalState] = useState<NetworkAuthState>({
    networkId: '',
    isGenerating: false,
    isJoining: false,
    error: null,
    showAdvanced: false,
    autoJoinMode: false
  })
  
  // 生成新网络并加入
  const handleGenerateAndJoin = async () => {
    setLocalState(prev => ({ ...prev, isGenerating: true, error: null }))
    
    try {
      // 生成新的网络ID
      const newNetworkId = generateNetworkId()
      
      // 加入网络
      const success = await joinNetwork(newNetworkId)
      
      if (success) {
        message.success('成功创建并加入新网络')
        navigate('/')
      } else {
        message.error('创建网络失败')
      }
    } catch (err) {
      message.error('操作失败，请重试')
      setLocalState(prev => ({ ...prev, error: '创建网络失败', isGenerating: false }))
    } finally {
      setLocalState(prev => ({ ...prev, isGenerating: false }))
    }
  }
  
  // 加入现有网络
  const handleJoinNetwork = async (values: { networkId: string }) => {
    const networkId = sanitizeInput(values.networkId)
    
    // 验证网络ID格式
    if (!validateNetworkId(networkId)) {
      form.setFields([{
        name: 'networkId',
        errors: ['网络ID格式不正确']
      }])
      return
    }
    
    setLocalState(prev => ({ ...prev, isJoining: true, error: null }))
    
    try {
      const success = await joinNetwork(networkId)
      
      if (success) {
        message.success('成功加入网络')
        navigate('/')
      } else {
        message.error('加入网络失败')
      }
    } catch (err) {
      message.error('操作失败，请重试')
      setLocalState(prev => ({ ...prev, error: '加入网络失败', isJoining: false }))
    } finally {
      setLocalState(prev => ({ ...prev, isJoining: false }))
    }
  }
  
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 p-4">
      <Card className="w-full max-w-md">
        <div className="text-center mb-6">
          <Title level={2} className="text-primary mb-2">CardMind</Title>
          <Paragraph className="text-gray-500">现代化笔记卡片管理应用</Paragraph>
        </div>
        
        <Title level={4} className="mb-4">网络认证</Title>
        <Paragraph className="mb-6 text-gray-600">
          请输入网络ID加入现有网络，或创建新网络开始使用
        </Paragraph>
        
        {localState.error && (
          <div className="mb-4 text-red-500">{localState.error}</div>
        )}
        {error && (
          <div className="mb-4 text-red-500">{error}</div>
        )}
        
        <Form
          form={form}
          layout="vertical"
          onFinish={handleJoinNetwork}
          initialValues={{ networkId: '' }}
        >
          <Item
            name="networkId"
            label="网络ID"
            rules={[
              { required: true, message: '请输入网络ID' },
              { 
                pattern: /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
                message: '网络ID格式不正确'
              }
            ]}
            className="mb-4"
          >
            <Input
              placeholder="输入网络ID"
              prefix={<UserAddOutlined className="text-gray-400" />}
              disabled={localState.isJoining || localState.isGenerating}
              autoComplete="off"
            />
          </Item>
          
          <div className="flex flex-col gap-3">
            <Button
              type="primary"
              htmlType="submit"
              className="w-full"
              loading={localState.isJoining || isLoading}
              size="large"
            >
              加入网络
            </Button>
            
            <Button
              htmlType="button"
              className="w-full"
              onClick={handleGenerateAndJoin}
              loading={localState.isGenerating || isLoading}
              icon={<ReloadOutlined />}
              size="large"
            >
              创建新网络
            </Button>
          </div>
        </Form>
        
        <Divider className="my-6" />
        
        <div className="text-center text-gray-500 text-sm">
          <Text>
            网络ID是您与其他设备同步数据的密钥，请妥善保管
          </Text>
        </div>
      </Card>
    </div>
  )
}

export default NetworkAuthScreen