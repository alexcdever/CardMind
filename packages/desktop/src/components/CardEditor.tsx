import React, { useState, useEffect } from 'react';
import { Form, Input, Button, Card, Space, Select, message, Tag } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import { useCardStore } from '../store/cardStore';
import MDEditor from '@uiw/react-md-editor';
import { Card as CardType } from '../types/electron';
import { getTagColor } from '../utils/colorUtils';
import './CardEditor.css';

interface CardEditorProps {
  onClose: () => void;
  card?: CardType | null;
}

const CardEditor: React.FC<CardEditorProps> = ({ onClose, card }) => {
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);
  const [content, setContent] = useState<string | undefined>(card?.content);
  const addCard = useCardStore(state => state.addCard);
  const updateCard = useCardStore(state => state.updateCard);

  useEffect(() => {
    if (card) {
      console.log('CardEditor: Setting form fields with card data:', card);
      form.setFieldsValue({
        title: card.title,
        tags: card.tags?.map(tag => tag.name || tag) || []
      });
      setContent(card.content);
    } else {
      console.log('CardEditor: Resetting form fields');
      form.resetFields();
      setContent(undefined);
    }
  }, [card, form]);

  const handleSubmit = async (values: any) => {
    if (!content) {
      message.error('请输入卡片内容');
      return;
    }

    try {
      console.log('CardEditor: Submitting form with values:', values);
      if (card && card.id) {
        const cardId = typeof card.id === 'string' ? parseInt(card.id, 10) : card.id;
        console.log('CardEditor: Updating existing card:', cardId);
        
        if (isNaN(cardId)) {
          throw new Error('Invalid card ID');
        }

        const cardData = {
          title: values.title,
          content: content,
          tags: Array.isArray(values.tags) ? values.tags.map(tag => typeof tag === 'string' ? tag : tag.name) : []
        };
        
        console.log('CardEditor: Sending update with data:', cardData);
        const updatedCard = await updateCard(cardId, cardData);
        console.log('CardEditor: Card updated successfully:', updatedCard);
        message.success('Card updated successfully');
      } else {
        console.log('CardEditor: Creating new card');
        const newCard = await addCard({
          title: values.title,
          content: content,
          tags: Array.isArray(values.tags) ? values.tags.map(tag => typeof tag === 'string' ? tag : tag.name) : []
        });
        console.log('CardEditor: Card created successfully:', newCard);
        message.success('Card created successfully');
      }
      form.resetFields();
      setContent(undefined);
      onClose();
    } catch (error) {
      console.error('CardEditor: Error submitting form:', error);
      message.error(error instanceof Error ? error.message : 'Failed to save card');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card-editor-container">
      <Space style={{ marginBottom: 24 }}>
        <Button icon={<ArrowLeftOutlined />} onClick={onClose}>
          返回
        </Button>
        <h2 style={{ margin: 0 }}>{card ? '编辑卡片' : '新建卡片'}</h2>
      </Space>

      <Card>
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSubmit}
          style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}
        >
          <Form.Item
            name="title"
            label="标题"
            rules={[{ required: true, message: '请输入卡片标题' }]}
          >
            <Input.TextArea
              rows={2}
              placeholder="输入卡片标题"
              style={{ fontSize: '16px' }}
            />
          </Form.Item>

          <Form.Item
            name="tags"
            label="标签"
          >
            <Select
              mode="tags"
              style={{ width: '100%' }}
              placeholder="添加标签"
              open={false}
              tagRender={({ label, closable, onClose }) => {
                const color = getTagColor(label as string);
                return (
                  <Tag
                    color={color}
                    closable={closable}
                    onClose={onClose}
                    style={{
                      backgroundColor: color,
                      borderColor: color,
                      color: '#000000',
                      marginRight: 3
                    }}
                  >
                    {label}
                  </Tag>
                );
              }}
            />
          </Form.Item>

          <Form.Item
            label="内容"
          >
            <div data-color-mode="light">
              <MDEditor
                value={content}
                onChange={(value) => setContent(value)}
                height={400}
                preview="edit"
              />
            </div>
          </Form.Item>

          <Form.Item>
            <Button 
              type="primary" 
              htmlType="submit"
              loading={loading}
            >
              {card ? '更新卡片' : '保存卡片'}
            </Button>
          </Form.Item>
        </Form>
      </Card>
    </div>
  );
};

export default CardEditor;