import { useState, useEffect } from 'react'
import { Layout, Typography, Button, Space, Input, Badge, Divider, Empty, Modal } from 'antd'
import { PlusOutlined, SettingOutlined } from '@ant-design/icons'
import { useNavigate } from 'react-router-dom'
import CardList from './CardList/CardList'
import CardEditor from './CardEditor/CardEditor'
import { Card as CardType } from '@/types/card.types'
import useCardStore from '@/stores/cardStore'
import useSyncStore from '@/stores/syncStore'

const { Header, Content } = Layout
const { Title, Text } = Typography
const { Search } = Input

/**
 * 主屏幕组件
 * 显示卡片列表和提供相关操作
 */
const MainScreen = () => {
  const navigate = useNavigate()
  const { cards, isLoading, fetchAllCards } = useCardStore()
  const { isOnline, isSyncing, connectedDevices } = useSyncStore()
  
  const [searchQuery, setSearchQuery] = useState<string>('')
  const [showEditor, setShowEditor] = useState(false)
  const [editingCard, setEditingCard] = useState<CardType | null>(null)
  
  // 页面加载时获取卡片数据
    useEffect(() => {
      fetchAllCards()
    }, [fetchAllCards]); // 只在组件挂载时执行一次
  
  // 处理创建新卡片
  const handleCreateCard = () => {
    setEditingCard(null)
    setShowEditor(true)
  }
  
  // 处理编辑卡片
  const handleEditCard = (card: CardType) => {
    setEditingCard(card)
    setShowEditor(true)
  }
  
  // 处理卡片保存成功
  const handleSaveSuccess = () => {
    setShowEditor(false)
    fetchAllCards() // 重新获取卡片列表
  }
  
  // 获取同步状态图标
  const getSyncStatusIcon = () => {
    if (!isOnline) {
      return (
        <Badge 
          status="error" 
          text="离线模式" 
          className="ml-2 cursor-help"
          title="当前处于离线状态，数据仅保存在本地"
        />
      )
    }
    
    if (isSyncing) {
      return (
        <Badge 
          dot
          text="同步中"
          className="ml-2 cursor-help"
          title="正在同步数据"
        />
        )
    }
    
    return (
      <Badge 
        status="success" 
        text={`已同步 (${connectedDevices}台设备)`}
        className="ml-2 cursor-help"
        title={`当前已连接${connectedDevices}台设备`}
      />
    )
  }
  
  return (
    <Layout className="min-h-screen">
      <Header className="bg-white shadow-sm px-6">
        <div className="flex items-center justify-between h-full">
          <div className="flex items-center">
            <Title level={4} className="m-0 mr-4 text-primary">CardMind</Title>
            {getSyncStatusIcon()}
          </div>
          
          <Space>
            <Button
              icon={<SettingOutlined />}
              onClick={() => navigate('/settings')}
              title="设置"
            >
              设置
            </Button>
          </Space>
        </div>
      </Header>
      
      <Content className="p-6">
        <div className="max-w-4xl mx-auto">
          <div className="flex flex-col md:flex-row items-start md:items-center justify-between mb-6 gap-4">
            <div>
              <Title level={3} className="m-0">我的卡片</Title>
              <Text className="text-gray-500">
                共 {cards.length} 张卡片
              </Text>
            </div>
            
            <div className="w-full md:w-auto flex gap-3">
              <Search
                placeholder="搜索卡片..."
                allowClear
                onSearch={(value) => setSearchQuery(value)}
                onChange={(e) => setSearchQuery(e.target.value)}
                style={{ width: 250 }}
                size="middle"
              />
              <Button
                type="primary"
                icon={<PlusOutlined />}
                onClick={handleCreateCard}
                size="middle"
              >
                新建卡片
              </Button>
            </div>
          </div>
          
          <Divider />
          
          {cards.length > 0 ? (
            <CardList 
              cards={cards} 
              loading={isLoading}
              searchQuery={searchQuery}
              onEditCard={handleEditCard}
            />
          ) : (
            <Empty 
              description="当前卡片列表为空，请添加卡片"
              className="py-12"
              image={Empty.PRESENTED_IMAGE_SIMPLE}
            >
              <Button
                type="primary"
                icon={<PlusOutlined />}
                onClick={handleCreateCard}
              >
                创建第一张卡片
              </Button>
            </Empty>
          )}
        </div>
      </Content>
      
      {/* 卡片编辑器模态框 */}
      <Modal
        title={editingCard ? "编辑卡片" : "创建新卡片"}
        open={showEditor}
        onCancel={() => setShowEditor(false)}
        footer={null}
        width={800}
        destroyOnClose
      >
        <CardEditor
          initialCard={editingCard}
          onClose={() => setShowEditor(false)}
          onSaveSuccess={handleSaveSuccess}
        />
      </Modal>
    </Layout>
  )
}

export default MainScreen