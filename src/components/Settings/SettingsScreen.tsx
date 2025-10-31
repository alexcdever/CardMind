import { useState, useEffect } from 'react'
import { Layout, Typography, Form, Input, Button, Card, Divider, Badge, Switch, Space, Tooltip, message, Tag, List, Avatar } from 'antd'
import { ArrowLeftOutlined, WifiOutlined, GlobalOutlined, CopyOutlined, CheckOutlined, LinkOutlined, SyncOutlined, ClockCircleOutlined, UserOutlined, MobileOutlined, DesktopOutlined } from '@ant-design/icons'
import { useNavigate } from 'react-router-dom'
import useDeviceStore from '@/stores/deviceStore'
import useAuthStore from '@/stores/authStore'
import useSyncStore from '@/stores/syncStore'
import SyncService from '@/services/syncService'
// validateDeviceNickname暂时未使用

// 获取本地IP地址的函数
const getLocalIPAddresses = async (): Promise<string[]> => {
  try {
    // 使用RTCPeerConnection API获取本地IP地址
    const pc = new RTCPeerConnection({ iceServers: [] });
    const ips: Set<string> = new Set();
    
    // 添加console日志以便调试
    console.log('开始获取IP地址...');
    
    // 创建数据通道以触发ICE候选者收集
    pc.createDataChannel('');
    
    // 监听ICE候选者事件
    pc.onicecandidate = (event) => {
      console.log('ICE候选者事件触发:', event);
      if (event.candidate) {
        // 解析ICE候选者字符串以提取IP地址
        const candidate = event.candidate.candidate;
        console.log('ICE候选者:', candidate);
        const ipRegex = /([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/;
        const match = candidate.match(ipRegex);
        
        if (match && match[1]) {
          console.log('找到IP地址:', match[1]);
          ips.add(match[1]);
        }
      } else {
        console.log('ICE候选者收集完成');
      }
    };
    
    // 监听ICE连接状态变化
    pc.oniceconnectionstatechange = () => {
      console.log('ICE连接状态:', pc.iceConnectionState);
    };
    
    // 创建一个虚拟的offer以触发ICE候选者收集
    const offer = await pc.createOffer({
      offerToReceiveAudio: false,
      offerToReceiveVideo: false
    });
    
    // 必须设置本地描述才能真正触发ICE候选者收集
    await pc.setLocalDescription(offer);
    
    // 延迟返回以确保所有候选者都被收集
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // 如果没有收集到IP，尝试添加fallback方法
    if (ips.size === 0) {
      console.log('通过RTCPeerConnection未收集到IP，尝试备用方法');
      // 添加localhost作为备选
      ips.add('127.0.0.1');
      // 如果能从window.location中获取，也添加到列表
      if (window.location.hostname && /^\d+\.\d+\.\d+\.\d+$/.test(window.location.hostname)) {
        ips.add(window.location.hostname);
      }
    }
    
    // 清理
    pc.close();
    
    console.log('最终收集到的IP地址:', Array.from(ips));
    // 返回收集到的IP地址数组
    return Array.from(ips);
  } catch (error) {
    console.error('获取IP地址失败:', error);
    // 出错时返回localhost作为默认值
    return ['127.0.0.1'];
  }
}

const { Header, Content } = Layout
const { Title, Text, Paragraph } = Typography

/**
 * 设置页面组件
 * 允许用户管理设备信息和网络连接
 */
const SettingsScreen = () => {
  const navigate = useNavigate()
  const [form] = Form.useForm()
  const { deviceId, deviceType, nickname, updateNickname, onlineDevices } = useDeviceStore()
  const { networkId, isAuthenticated, leaveNetwork } = useAuthStore()
  const { isOnline, setOnlineStatus, lastSyncTime, connectedDevices } = useSyncStore()
  const [messageApi, contextHolder] = message.useMessage() // 使用useMessage hook获取message API
  
  const [isSaving, setIsSaving] = useState(false)
  const [offlineMode, setOfflineMode] = useState(!isOnline)
  const [copiedStatus, setCopiedStatus] = useState(false) // 用于跟踪复制状态
  const [ipAddresses, setIpAddresses] = useState<string[]>([]) // 存储IP地址
  const [hostname, setHostname] = useState<string>('') // 存储主机名
  const [connectionStatus, setConnectionStatus] = useState({ isConnected: false, peersCount: 0, isSyncing: false }) // 网络连接状态
  
  // 初始化表单值
  useEffect(() => {
    form.setFieldsValue({
      nickname: nickname
    })
  }, [nickname, form])
  
  // 获取IP地址和主机名
  useEffect(() => {
    const fetchNetworkInfo = async () => {
      try {
        console.log('开始获取网络信息...');
        // 获取IP地址
        const ips = await getLocalIPAddresses();
        setIpAddresses(ips);
        
        // 获取主机名
        const hostnameValue = window.location.hostname || 'localhost';
        setHostname(hostnameValue);
        console.log('主机名设置为:', hostnameValue);
      } catch (error) {
        console.error('获取网络信息失败:', error);
        // 出错时设置默认值
        setIpAddresses(['127.0.0.1']);
        setHostname('localhost');
      }
    };

    // 立即执行一次
    fetchNetworkInfo();
    
    // 每分钟刷新一次IP地址
    const intervalId = setInterval(fetchNetworkInfo, 60000);
    
    return () => clearInterval(intervalId);
  }, []);

  // 获取网络连接状态
  useEffect(() => {
    const updateConnectionStatus = () => {
      const status = SyncService.getConnectionStatus();
      setConnectionStatus(status);
    };

    // 立即获取一次状态
    updateConnectionStatus();

    // 每5秒更新一次连接状态
    const intervalId = setInterval(updateConnectionStatus, 5000);

    return () => clearInterval(intervalId);
  }, []);
  
  // 复制IP地址到剪贴板
  const handleCopyIP = async (ip: string) => {
    try {
      await navigator.clipboard.writeText(ip);
      messageApi.success(`IP地址 ${ip} 已复制到剪贴板`);
    } catch (error) {
      messageApi.error('复制失败，请手动复制');
      console.error('Copy IP error:', error);
    }
  }
  
  // 处理昵称保存
  const handleSaveNickname = async (values: { nickname: string }) => {
    // 验证昵称
    if (!values.nickname.trim()) {
      messageApi.error('昵称不能为空') // 使用messageApi替代静态message
      return
    }
    
    setIsSaving(true)
    try {
      await updateNickname(values.nickname)
      messageApi.success('设备昵称更新成功') // 使用messageApi替代静态message
    } catch (error) {
      messageApi.error('设备昵称更新失败') // 使用messageApi替代静态message
      console.error('Update nickname error:', error)
    } finally {
      setIsSaving(false)
    }
  }
  
  // 处理离线模式切换
  const handleOfflineModeChange = (checked: boolean) => {
    setOfflineMode(checked)
    setOnlineStatus(!checked)
    messageApi.info(checked ? '已切换为离线模式' : '已切换为在线模式') // 使用messageApi替代静态message
  }
  
  // 处理退出网络
  const handleLeaveNetwork = async () => {
    try {
      await leaveNetwork()
      messageApi.success('已退出网络') // 使用messageApi替代静态message
      navigate('/')
    } catch (error) {
      messageApi.error('退出网络失败') // 使用messageApi替代静态message
      console.error('Leave network error:', error)
    }
  }
  
  // 复制访问码到剪贴板
  const handleCopyNetworkId = async () => {
    if (!networkId) return
    
    try {
      await navigator.clipboard.writeText(networkId)
      messageApi.success('访问码已复制到剪贴板') // 使用messageApi替代静态message
      // 显示复制成功状态
      setCopiedStatus(true)
      // 2秒后恢复原始状态
      setTimeout(() => setCopiedStatus(false), 2000)
    } catch (error) {
      messageApi.error('复制失败，请手动复制') // 使用messageApi替代静态message
      console.error('Copy access code error:', error)
    }
  }

  // 获取设备图标
  const getDeviceIcon = (deviceType: string) => {
    switch (deviceType) {
      case 'mobile':
        return <MobileOutlined />
      case 'desktop':
        return <DesktopOutlined />
      default:
        return <UserOutlined />
    }
  }

  // 格式化时间戳
  const formatTime = (timestamp: number | null) => {
    if (!timestamp) return '从未同步'
    const date = new Date(timestamp)
    return date.toLocaleString('zh-CN')
  }

  // 获取连接状态颜色
  const getConnectionStatusColor = () => {
    if (!isAuthenticated) return 'default'
    if (connectionStatus.isSyncing) return 'processing'
    if (connectionStatus.isConnected) return 'success'
    return 'error'
  }

  // 获取连接状态文本
  const getConnectionStatusText = () => {
    if (!isAuthenticated) return '未连接到网络'
    if (connectionStatus.isSyncing) return '同步中'
    if (connectionStatus.isConnected) {
      const totalDevices = connectionStatus.peersCount + 1
      return `已连接 (${totalDevices}台设备在线)`
    }
    return '连接断开'
  }
  
  return (
    <Layout className="min-h-screen">
      {contextHolder} {/* 添加contextHolder到组件中 */}
      <Header className="bg-white shadow-sm px-6">
        <div className="flex items-center h-full">
          {/* 使用Button组件和事件处理程序，这是React推荐的方式 */}
          <Button 
            type="primary" 
            icon={<ArrowLeftOutlined />}
            onClick={() => {
              // 直接导航到主页，避免依赖浏览器历史记录
              navigate('/');
            }}
            className="mr-4"
            size="middle"
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
              
              <Text strong className="block mb-2">主机名/域名：</Text>
              <Text code className="block break-all mb-3">{hostname || '未知'}</Text>
              
              <Text strong className="block mb-2">本地IP地址：</Text>
              <div className="space-y-2">
                {ipAddresses.length > 0 ? (
                  ipAddresses.map((ip, index) => (
                    <div key={index} className="flex items-center">
                      <Text code className="block flex-1">{ip}</Text>
                      <Tooltip title="复制IP地址">
                        <Button
                          size="small"
                          icon={<CopyOutlined />}
                          onClick={() => handleCopyIP(ip)}
                          type="text"
                          className="ml-2"
                        />
                      </Tooltip>
                    </div>
                  ))
                ) : (
                  <Text type="secondary">正在获取IP地址...</Text>
                )}
              </div>
              
              <Text strong className="block mt-4 mb-2">当前端口：</Text>
              <Text code className="block break-all">
                {window.location.port ? window.location.port : 
                  (window.location.protocol === 'https:' ? '443' : '80')}
              </Text>
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
                {/* 网络连接状态 */}
                <div className="mb-4">
                  <Text strong className="block mb-2">连接状态：</Text>
                  <Badge 
                    status={getConnectionStatusColor() as any} 
                    text={getConnectionStatusText()} 
                    className="mb-3" 
                  />
                </div>

                {/* 当前网络ID */}
                <div className="mb-4">
                  <Text strong className="block mb-2">当前网络ID：</Text>
                  <Space className="w-full flex-wrap" wrap>
                    <Text code className="block break-all flex-1 min-w-[200px]">{networkId}</Text>
                    <Tooltip title={copiedStatus ? "已复制" : "复制网络ID"}>
                      <Button
                        size="small"
                        icon={copiedStatus ? <CheckOutlined /> : <CopyOutlined />}
                        onClick={handleCopyNetworkId}
                        type={copiedStatus ? "primary" : "default"}
                      >
                        {copiedStatus ? "已复制" : "复制"}
                      </Button>
                    </Tooltip>
                  </Space>
                </div>

                {/* 最后同步时间 */}
                {lastSyncTime && (
                  <div className="mb-4">
                    <Text strong className="block mb-2">
                      <ClockCircleOutlined /> 最后同步时间：
                    </Text>
                    <Text type="secondary">{formatTime(lastSyncTime)}</Text>
                  </div>
                )}

                {/* 在线设备列表 */}
                {onlineDevices.length > 0 && (
                  <div className="mb-6">
                    <Text strong className="block mb-3">
                      <UserOutlined /> 在线设备 ({onlineDevices.length + 1}台设备)：
                    </Text>
                    <List
                      size="small"
                      bordered
                      dataSource={[
                        { id: deviceId, nickname: nickname || '当前设备', deviceType, isCurrent: true },
                        ...onlineDevices.map((device: any) => ({ ...device, isCurrent: false }))
                      ]}
                      renderItem={(item: any) => (
                        <List.Item>
                          <List.Item.Meta
                            avatar={
                              <Avatar icon={getDeviceIcon(item.deviceType)} size="small" />
                            }
                            title={
                              <Space>
                                <Text>{item.nickname}</Text>
                                {item.isCurrent && <Tag color="blue">当前设备</Tag>}
                              </Space>
                            }
                            description={
                              <Text type="secondary" style={{ fontSize: '12px' }}>
                                ID: {item.id.substring(0, 8)}...
                              </Text>
                            }
                          />
                        </List.Item>
                      )}
                    />
                  </div>
                )}
                
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