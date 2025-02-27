// 导入必要的依赖
import React, { useState, useEffect } from 'react';
import { Form, Input, Button, Card, message } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import { useCardStore } from '../store/cardStore';
import MDEditor from '@uiw/react-md-editor';
import { Card as CardType } from '../types/card';
import './CardEditor.css';

// 组件属性接口定义
interface CardEditorProps {
  onClose: () => void;      // 关闭编辑器的回调函数
  card?: CardType | null;   // 要编辑的卡片（如果是新建则为null）
}

// 卡片编辑器组件
const CardEditor: React.FC<CardEditorProps> = ({ onClose, card }) => {
  // 表单和状态管理
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);  // 加载状态
  const [content, setContent] = useState<string | undefined>(card?.content);  // Markdown内容
  
  // 从全局状态获取操作函数
  const addCard = useCardStore(state => state.addCard);
  const updateCard = useCardStore(state => state.updateCard);

  // 当编辑现有卡片时，初始化表单数据
  useEffect(() => {
    if (card) {
      form.setFieldsValue({
        title: card.title,
      });
      setContent(card.content);
    }
  }, [card, form]);

  // 处理表单提交
  const handleSubmit = async (values: any) => {
    // 验证内容不能为空
    if (!content) {
      message.error('请输入卡片内容');
      return;
    }

    setLoading(true);
    try {
      const cardData = {
        title: values.title,
        content: content,
      };

      // 根据是否有现有卡片来决定是更新还是创建
      if (card) {
        await updateCard(card.id, cardData);
        message.success('卡片更新成功');
      } else {
        await addCard(cardData);
        message.success('卡片创建成功');
      }
      onClose();
    } catch (error) {
      console.error('表单提交错误:', error);
      message.error(`${card ? '更新' : '创建'}卡片失败: ${error instanceof Error ? error.message : String(error)}`);
    } finally {
      setLoading(false);
    }
  };

  // 渲染UI
  return (
    <Card className="card-editor">
      {/* 顶部导航栏 */}
      <div className="card-editor-header">
        <Button 
          type="text" 
          icon={<ArrowLeftOutlined />} 
          onClick={onClose}
        >
          返回
        </Button>
      </div>

      {/* 编辑表单 */}
      <Form
        form={form}
        onFinish={handleSubmit}
        layout="vertical"
        className="card-editor-form"
      >
        {/* 标题输入框 */}
        <Form.Item
          name="title"
          label="标题"
          rules={[{ required: true, message: '请输入标题' }]}
        >
          <Input placeholder="输入卡片标题" />
        </Form.Item>

        {/* Markdown编辑器 */}
        <Form.Item
          label="内容"
          required
          help="支持Markdown语法"
        >
          <MDEditor
            value={content}
            onChange={value => setContent(value || '')}
            preview="edit"
          />
        </Form.Item>

        {/* 操作按钮 */}
        <Form.Item className="form-actions">
          <Button type="default" onClick={onClose}>
            取消
          </Button>
          <Button type="primary" htmlType="submit" loading={loading}>
            {card ? '更新' : '创建'}
          </Button>
        </Form.Item>
      </Form>
    </Card>
  );
};

export default CardEditor;