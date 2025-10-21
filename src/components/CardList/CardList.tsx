import { useState } from 'react'
import { List, Card, Typography, Button, Space, Badge, Tooltip, Modal } from 'antd'
import { EditOutlined, DeleteOutlined, ClockCircleOutlined } from '@ant-design/icons'
import { Card as CardType } from '@/types/card.types'
import useCardStore from '@/stores/cardStore'

const { Title, Text, Paragraph } = Typography

interface CardListProps {
  cards: CardType[];
  loading: boolean;
  searchQuery: string;
  onEditCard: (card: CardType) => void;
}

/**
 * 卡片列表组件
 * 显示卡片列表并提供编辑、删除等操作
 */
const CardList: React.FC<CardListProps> = ({ cards, loading, searchQuery, onEditCard }) => {
  const { deleteCard } = useCardStore()
  const [deleteConfirmVisible, setDeleteConfirmVisible] = useState(false)
  const [cardToDelete, setCardToDelete] = useState<string | null>(null)
  
  // 过滤卡片
  const filteredCards = cards.filter(card => {
    const query = searchQuery.toLowerCase()
    return card.title.toLowerCase().includes(query) || 
           card.content.toLowerCase().includes(query)
  })
  
  // 处理删除卡片
  const handleDelete = (cardId: string) => {
    setCardToDelete(cardId)
    setDeleteConfirmVisible(true)
  }
  
  // 确认删除
  const confirmDelete = async () => {
    if (cardToDelete) {
      try {
        await deleteCard(cardToDelete)
        Modal.success({ title: '删除成功', content: '卡片已成功删除' })
      } catch (error) {
        Modal.error({ title: '删除失败', content: '卡片删除失败，请重试' })
      } finally {
        setDeleteConfirmVisible(false)
        setCardToDelete(null)
      }
    }
  }
  
  // 取消删除
  const cancelDelete = () => {
    setDeleteConfirmVisible(false)
    setCardToDelete(null)
  }
  
  // 格式化时间
  const formatTime = (timestamp: number) => {
    const date = new Date(timestamp)
    return date.toLocaleString('zh-CN', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    })
  }
  
  // 截取内容预览
  const getContentPreview = (content: string, maxLength: number = 100) => {
    return content.length > maxLength 
      ? content.substring(0, maxLength) + '...' 
      : content
  }
  
  return (
    <>
      <List
        loading={loading}
        dataSource={filteredCards}
        renderItem={(card) => (
          <List.Item>
            <Card
              className="w-full hover:shadow-md transition-shadow duration-300"
              actions={[
                <Tooltip key="edit" title="编辑">
                  <Button
                    type="text"
                    icon={<EditOutlined />}
                    onClick={() => onEditCard(card)}
                  />
                </Tooltip>,
                <Tooltip key="delete" title="删除">
                  <Button
                    type="text"
                    danger
                    icon={<DeleteOutlined />}
                    onClick={() => handleDelete(card.id)}
                  />
                </Tooltip>
              ]}
            >
              <div className="flex justify-between items-start mb-2">
                <Title level={4} className="m-0 text-gray-800">
                  {card.title || '无标题'}
                </Title>
                <Tooltip title={`修改时间: ${formatTime(card.updatedAt)}`}>
                  <Space className="text-gray-400">
                    <ClockCircleOutlined />
                    <Text type="secondary">
                      {formatTime(card.updatedAt)}
                    </Text>
                  </Space>
                </Tooltip>
              </div>
              
              <Paragraph 
                className="text-gray-600 mb-0 line-clamp-3 cursor-pointer"
                onClick={() => onEditCard(card)}
              >
                {getContentPreview(card.content)}
              </Paragraph>
              
              {card.lastModifiedDeviceId && (
                <div className="mt-2">
                  <Badge.Ribbon 
                    text={`由设备修改`} 
                    placement="end"
                    color="blue"
                  />
                </div>
              )}
            </Card>
          </List.Item>
        )}
        pagination={{
          pageSize: 10,
          showSizeChanger: true,
          showQuickJumper: true,
          showTotal: (total) => `共 ${total} 张卡片`,
        }}
      />
      
      {/* 删除确认模态框 */}
      <Modal
        title="确认删除"
        open={deleteConfirmVisible}
        onOk={confirmDelete}
        onCancel={cancelDelete}
        okText="确认删除"
        cancelText="取消"
        okType="danger"
      >
        <p>确定要删除这张卡片吗？此操作无法撤销。</p>
      </Modal>
    </>
  )
}

export default CardList