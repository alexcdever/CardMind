import React, { useState, useEffect } from 'react';
import { Form, Input, Button, Card, message } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import { useCardStore } from '../store/cardStore';
import MDEditor from '@uiw/react-md-editor';
import { Card as CardType } from '../types/card';
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
      form.setFieldsValue({
        title: card.title,
      });
      setContent(card.content);
    }
  }, [card, form]);

  const handleSubmit = async (values: any) => {
    if (!content) {
      message.error('Please enter card content');
      return;
    }

    setLoading(true);
    try {
      const cardData = {
        title: values.title,
        content: content,
      };

      if (card) {
        await updateCard(card.id, cardData);
        message.success('Card updated successfully');
      } else {
        await addCard(cardData);
        message.success('Card created successfully');
      }
      onClose();
    } catch (error) {
      console.error('Error submitting form:', error);
      message.error(`Failed to ${card ? 'update' : 'create'} card: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Card className="card-editor">
      <div className="card-editor-header">
        <Button 
          type="text" 
          icon={<ArrowLeftOutlined />} 
          onClick={onClose}
        >
          Back
        </Button>
      </div>
      <Form
        form={form}
        onFinish={handleSubmit}
        layout="vertical"
        className="card-editor-form"
      >
        <Form.Item
          name="title"
          label="Title"
          rules={[{ required: true, message: 'Please enter a title' }]}
        >
          <Input placeholder="Enter card title" />
        </Form.Item>

        <Form.Item
          label="Content"
          required
          help="Support Markdown syntax"
        >
          <MDEditor
            value={content}
            onChange={value => setContent(value || '')}
            preview="edit"
          />
        </Form.Item>

        <Form.Item className="form-actions">
          <Button type="default" onClick={onClose}>
            Cancel
          </Button>
          <Button type="primary" htmlType="submit" loading={loading}>
            {card ? 'Update' : 'Create'}
          </Button>
        </Form.Item>
      </Form>
    </Card>
  );
};

export default CardEditor;