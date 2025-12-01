import React, { useState, useEffect } from 'react'
import { Layout, Button, Space, Typography, Card, Input, message } from 'antd'
import { PlusOutlined, SettingOutlined } from '@ant-design/icons'
import { useNavigate } from 'react-router-dom'
import useCardStore from '../stores/cardStore'
import useSyncStore from '../stores/syncStore'
import { Card as CardType } from '../types/card.types'

const { Header, Content, Footer } = Layout
const { Title, Text } = Typography
const { Search } = Input

const MainPage: React.FC = () => {
  const navigate = useNavigate()
  const { cards, isLoading, error, fetchAllCards, createCard } = useCardStore()
  const { isOnline, connectedDevices, syncStatus } = useSyncStore()
  const [searchQuery, setSearchQuery] = useState('')
  const [filteredCards, setFilteredCards] = useState<CardType[]>([])

  // 初始化时获取卡片数据
  useEffect(() => {
    fetchAllCards()
  }, [fetchAllCards])

  // 根据搜索查询过滤卡片
  useEffect(() => {
    if (searchQuery.trim()) {
      const lowerQuery = searchQuery.toLowerCase()
      const filtered = cards.filter(card => 
        card.title.toLowerCase().includes(lowerQuery) ||
        card.content.toLowerCase().includes(lowerQuery)
      )
      setFilteredCards(filtered)
    } else {
      setFilteredCards(cards)
    }
  }, [cards, searchQuery])

  // 处理创建新卡片
  const handleCreateCard = async () => {
    try {
      await createCard({
        title: '新卡片',
        content: '点击编辑卡片内容',
        createdAt: Date.now(),
        updatedAt: Date.now(),
        isDeleted: false
      })
      message.success('卡片创建成功')
    } catch (error) {
      message.error('卡片创建失败')
      console.error('Create card error:', error)
    }
  }

  return (
    <Layout className="min-h-screen">
      <Header className="bg-white shadow-sm px-6">
        <div className="flex items-center justify-between h-full">
          <Title level={4} className="m-0 text-primary">CardMind</Title>
          <Space>
            <Button
              type="primary"
              icon={<PlusOutlined />}
              onClick={handleCreateCard}
            >
              新建卡片
            </Button>
            <Button
              icon={<SettingOutlined />}
              onClick={() => navigate('/settings')}
            >
              设置
            </Button>
          </Space>
        </div>
      </Header>

      <Content className="p-6">
        <div className="max-w-4xl mx-auto">
          {/* 搜索框 */}
          <div className="mb-6">
            <Search
              placeholder="搜索卡片标题或内容"
              allowClear
              enterButton="搜索"
              size="large"
              onSearch={setSearchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full"
            />
          </div>

          {/* 同步状态 */}
          <div className="mb-6">
            <Card size="small">
              <Space size="middle">
                <Text strong>同步状态:</Text>
                <Text type={isOnline ? "success" : "danger"}>
                  {isOnline ? "在线" : "离线"}
                </Text>
                <Text>连接设备: {connectedDevices}</Text>
                <Text type="secondary">
                  同步状态: {syncStatus}
                </Text>
              </Space>
            </Card>
          </div>

          {/* 卡片列表 */}
          {isLoading ? (
            <div className="text-center py-12">
              <Text>加载中...</Text>
            </div>
          ) : error ? (
            <div className="text-center py-12">
              <Text type="danger">{error}</Text>
            </div>
          ) : filteredCards.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {filteredCards.map((card) => (
                <Card
                  key={card.id}
                  title={card.title}
                  bordered={false}
                  className="h-full"
                >
                  <div className="text-left">
                    <Text>{card.content}</Text>
                    <div className="mt-4 text-right">
                      <Text type="secondary" style={{ fontSize: '12px' }}>
                        创建于: {new Date(card.createdAt).toLocaleString()}
                      </Text>
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          ) : (
            <div className="text-center py-12">
              <Text type="secondary">暂无卡片数据</Text>
              <div className="mt-4">
                <Button
                  type="primary"
                  icon={<PlusOutlined />}
                  onClick={handleCreateCard}
                >
                  创建第一张卡片
                </Button>
              </div>
            </div>
          )}
        </div>
      </Content>

      <Footer className="text-center">
        CardMind ©{new Date().getFullYear()} - 跨设备卡片应用
      </Footer>
    </Layout>
  )
}

export default MainPage
