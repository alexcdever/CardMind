import { useEffect, useState } from 'react'
import { Form, Input, Button, Space, message, Spin } from 'antd'
import { Card as CardType } from '@/types/card.types'
import useCardStore from '@/stores/cardStore'
import useDeviceStore from '@/stores/deviceStore'
import { sanitizeInput } from '@/utils/validation'

const { TextArea } = Input

interface CardEditorProps {
  initialCard: CardType | null;
  onClose: () => void;
  onSaveSuccess: () => void;
}

/**
 * 卡片编辑器组件
 * 用于创建和编辑卡片内容
 */
const CardEditor: React.FC<CardEditorProps> = ({ initialCard, onClose, onSaveSuccess }) => {
  const [form] = Form.useForm()
  const { createCard, updateCard } = useCardStore()
  const { deviceId } = useDeviceStore()
  const [isSubmitting, setIsSubmitting] = useState(false)
  
  // 初始化表单数据
  useEffect(() => {
    if (initialCard) {
      form.setFieldsValue({
        title: initialCard.title,
        content: initialCard.content
      })
    } else {
      form.resetFields()
    }
  }, [initialCard, form])
  
  // 处理表单提交
  const handleSubmit = async (values: { title: string; content: string }) => {
    setIsSubmitting(true)
    
    try {
      // 清理输入数据
      const sanitizedTitle = sanitizeInput(values.title.trim())
      const sanitizedContent = sanitizeInput(values.content.trim())
      
      // 创建或更新卡片
      const cardData = {
        title: sanitizedTitle,
        content: sanitizedContent,
        lastModifiedDeviceId: deviceId,
        updatedAt: Date.now()
      }
      
      if (initialCard) {
        // 更新现有卡片
        await updateCard({
          ...cardData,
          id: initialCard.id,
          createdAt: initialCard.createdAt,
          isDeleted: false
        })
        message.success('卡片更新成功')
      } else {
        // 创建新卡片
        await createCard({
          ...cardData,
          createdAt: Date.now()
        })
        message.success('卡片创建成功')
      }
      
      onSaveSuccess()
    } catch (error) {
      message.error(initialCard ? '卡片更新失败' : '卡片创建失败')
      console.error('Card operation failed:', error)
    } finally {
      setIsSubmitting(false)
    }
  }
  
  return (
    <div className="p-1">
      <Form
        form={form}
        layout="vertical"
        onFinish={handleSubmit}
        initialValues={{
          title: '',
          content: ''
        }}
      >
        <Form.Item
          label="标题"
          name="title"
          rules={[
            { required: true, message: '请输入卡片标题' },
            { max: 100, message: '标题长度不能超过100个字符' }
          ]}
        >
          <Input placeholder="请输入卡片标题" size="large" />
        </Form.Item>
        
        <Form.Item
          label="内容"
          name="content"
          rules={[
            { required: true, message: '请输入卡片内容' }
          ]}
        >
          <TextArea 
            placeholder="请输入卡片内容..." 
            autoSize={{ minRows: 10, maxRows: 20 }}
            showCount
            maxLength={2000}
          />
        </Form.Item>
        
        <div className="flex justify-end gap-2 mt-4">
          <Button onClick={onClose} disabled={isSubmitting}>
            取消
          </Button>
          <Button 
            type="primary" 
            htmlType="submit" 
            disabled={isSubmitting}
          >
            {isSubmitting ? (
              <Spin size="small" />
            ) : initialCard ? '更新卡片' : '创建卡片'}
          </Button>
        </div>
      </Form>
    </div>
  )
}

export default CardEditor