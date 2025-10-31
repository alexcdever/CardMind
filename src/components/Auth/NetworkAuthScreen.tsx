import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Card, Form, Input, Button, Typography, Divider } from 'antd'
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
  const authStore = useAuthStore()
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
      const newNetworkId = authStore.generateNetworkId()
      
      // 加入网络
      await authStore.joinNetwork(newNetworkId)
      
      // 直接导航，不显示message以避免警告
      navigate('/')
    } catch (err) {
      setLocalState(prev => ({ ...prev, error: '创建网络失败', isGenerating: false }))
    } finally {
      setLocalState(prev => ({ ...prev, isGenerating: false }))
    }
  }
  
  // 加入现有网络
  const handleJoinNetwork = async (values: { networkId: string }) => {
    const networkId = sanitizeInput(values.networkId)
    
    // 验证网络ID格式
    if (!authStore.validateNetworkId(networkId)) {
      form.setFields([{
        name: 'networkId',
        errors: ['网络ID格式不正确']
      }])
      return
    }
    
    setLocalState(prev => ({ ...prev, isJoining: true, error: null }))
    
    try {
      await authStore.joinNetwork(networkId)
      
      // 直接导航，不显示message以避免警告
      navigate('/')
    } catch (err) {
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
          请输入其他设备生成的访问码以加入其协作网络，或创建新网络开始使用
        </Paragraph>
        
        {localState.error && (
          <div className="mb-4 text-red-500">{localState.error}</div>
        )}
        {authStore.error && (
          <div className="mb-4 text-red-500">{authStore.error}</div>
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
              validator: (_, value) => {
                if (!value || !authStore.validateNetworkId(value)) {
                  return Promise.reject('网络ID格式不正确')
                }
                return Promise.resolve()
              }
            }
          ]}
          validateTrigger="onBlur"
        >
          <Input
            placeholder="输入其他设备生成的网络ID以加入其网络"
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
              loading={localState.isJoining || authStore.isLoading}
              size="large"
            >
              加入网络
            </Button>
            
            <Button
              htmlType="button"
              className="w-full"
              onClick={handleGenerateAndJoin}
              loading={localState.isGenerating || authStore.isLoading}
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
            网络ID包含网络连接信息，用于加入其他设备的协作网络
          </Text>
        </div>
        
        {/* 跳过网络设置按钮 */}
        <div className="text-center mt-6">
          <Button
            type="link"
            onClick={() => {
              // 生成临时网络ID并通过joinNetwork方法设置认证状态
              const tempNetworkId = authStore.generateNetworkId();
              // 调用joinNetwork方法来设置认证状态
              authStore.joinNetwork(tempNetworkId).then(() => {
                // 认证成功后导航到主页面
                navigate('/');
              });
            }}
            danger
          >
            跳过网络设置
          </Button>
        </div>
      </Card>
    </div>
  )
}

export default NetworkAuthScreen