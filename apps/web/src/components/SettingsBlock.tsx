import React, { useState, useEffect } from 'react';
import { useDocuments } from '../contexts/DocumentContext';
import { AnyBlock, TextBlock } from '@cardmind/types';
import { Input, Switch, Button, Form, Space, Card, Typography, message } from 'antd';
import { SettingOutlined, SaveOutlined } from '@ant-design/icons';

const { Title } = Typography;

// 设置块数据结构
interface SettingsBlockData {
  relayEnabled: boolean;
  relayIp: string;
  relayPort: number;
  relayPath: string;
  autoSave: boolean;
  theme: 'light' | 'dark' | 'auto';
  language: string;
}

// 默认设置
const defaultSettings: SettingsBlockData = {
  relayEnabled: false,
  relayIp: 'localhost',
  relayPort: 1234,
  relayPath: '/relay',
  autoSave: true,
  theme: 'auto',
  language: 'zh-CN'
};

// 将组件props中的UnifiedBlock替换为AnyBlock
export const SettingsBlock: React.FC<{ 
  block?: AnyBlock;
  onSave?: (updatedBlock: AnyBlock) => void;
}> = ({ block, onSave }) => {
  const { state, updateBlock } = useDocuments();
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);

  // 从块中解析设置数据 - 更新为AnyBlock
  const getSettingsFromBlock = (block?: AnyBlock): SettingsBlockData => {
    if (!block) return defaultSettings;
    
    // 检查是否为文本块
    if (block instanceof TextBlock && block.content) {
      try {
        const parsed = JSON.parse(block.content);
        return { ...defaultSettings, ...parsed };
      } catch {
        return defaultSettings;
      }
    }
    
    return defaultSettings;
  };

  // 将设置数据保存到块 - 更新为AnyBlock
  const saveSettingsToBlock = (settings: SettingsBlockData): AnyBlock => {
    const content = JSON.stringify(settings, null, 2);
    const now = new Date();
    
    if (block && block instanceof TextBlock) {
      // 更新现有的文本块
      block.content = content;
      block.modifiedAt = now;
      return block;
    } else {
      // 创建新的文本块
      return new TextBlock(
        `settings-${now.getTime()}`,
        null,
        content
      );
    }
  };

  // 加载设置到表单
  useEffect(() => {
    const settings = getSettingsFromBlock(block);
    form.setFieldsValue(settings);
  }, [block, form]);

  // 处理保存设置
  const handleSaveSettings = async (values: SettingsBlockData) => {
    setLoading(true);
    try {
      const settingsBlock = saveSettingsToBlock(values);
      
      if (block) {
        // 更新现有设置块
        await updateBlock(settingsBlock);
      } else if (state.currentDocument) {
        // 添加新的设置块到当前文档
        await updateBlock(settingsBlock);
      }
      
      onSave?.(settingsBlock);
      message.success('设置已保存');
    } catch (error) {
      message.error('保存设置失败');
    } finally {
      setLoading(false);
    }
  };

  // 设置块渲染为可视化表单
  return (
    <Card 
      title={
        <Space>
          <SettingOutlined />
          <Title level={4} style={{ margin: 0 }}>应用设置</Title>
        </Space>
      }
      style={{ maxWidth: 600, margin: '0 auto' }}
    >
      <Form
        form={form}
        layout="vertical"
        onFinish={handleSaveSettings}
        initialValues={getSettingsFromBlock(block)}
      >
        {/* 中继服务设置 */}
        <Card title="中继服务配置" size="small" style={{ marginBottom: 16 }}>
          <Form.Item
            label="启用中继服务"
            name="relayEnabled"
            valuePropName="checked"
          >
            <Switch />
          </Form.Item>

          <Form.Item
            label="服务器IP"
            name="relayIp"
            rules={[{ required: true, message: '请输入服务器IP' }]}
          >
            <Input placeholder="localhost" />
          </Form.Item>

          <Form.Item
            label="端口"
            name="relayPort"
            rules={[{ required: true, message: '请输入端口号' }]}
          >
            <Input type="number" placeholder="1234" />
          </Form.Item>

          <Form.Item
            label="路径"
            name="relayPath"
            rules={[{ required: true, message: '请输入路径' }]}
          >
            <Input placeholder="/relay" />
          </Form.Item>
        </Card>

        {/* 应用设置 */}
        <Card title="应用偏好" size="small" style={{ marginBottom: 16 }}>
          <Form.Item
            label="自动保存"
            name="autoSave"
            valuePropName="checked"
          >
            <Switch />
          </Form.Item>

          <Form.Item
            label="主题"
            name="theme"
            rules={[{ required: true, message: '请选择主题' }]}
          >
            <Input placeholder="auto" />
          </Form.Item>

          <Form.Item
            label="语言"
            name="language"
            rules={[{ required: true, message: '请选择语言' }]}
          >
            <Input placeholder="zh-CN" />
          </Form.Item>
        </Card>

        <Form.Item>
          <Space>
            <Button 
              type="primary" 
              htmlType="submit" 
              loading={loading}
              icon={<SaveOutlined />}
            >
              保存设置
            </Button>
            <Button onClick={() => form.resetFields()}>
              重置
            </Button>
          </Space>
        </Form.Item>
      </Form>
    </Card>
  );
};

// 设置工具函数 - 用于在其他组件中获取和更新设置
export const SettingsUtils = {
  // 从文档中查找设置块
  findSettingsBlock: (blocks: AnyBlock[]): AnyBlock | undefined => {
    return blocks.find(block => {
      // 根据块类型和内容查找设置块
      if (block instanceof TextBlock && block.content) {
        return block.content.includes('"relayEnabled"');
      }
      return false;
    });
  },

  // 解析设置数据
  parseSettings: (block?: AnyBlock): SettingsBlockData => {
    if (!block) return {
      relayEnabled: false,
      relayIp: 'localhost',
      relayPort: 1234,
      relayPath: '/relay',
      autoSave: true,
      theme: 'auto',
      language: 'zh-CN'
    };
    
    if (block instanceof TextBlock && block.content) {
      try {
        return JSON.parse(block.content);
      } catch {
        return {
          relayEnabled: false,
          relayIp: 'localhost',
          relayPort: 1234,
          relayPath: '/relay',
          autoSave: true,
          theme: 'auto',
          language: 'zh-CN'
        };
      }
    }
    
    return {
      relayEnabled: false,
      relayIp: 'localhost',
      relayPort: 1234,
      relayPath: '/relay',
      autoSave: true,
      theme: 'auto',
      language: 'zh-CN'
    };
  },

  // 创建默认设置块
  createDefaultSettingsBlock: (): AnyBlock => {
    const settings: SettingsBlockData = {
      relayEnabled: false,
      relayIp: 'localhost',
      relayPort: 1234,
      relayPath: '/relay',
      autoSave: true,
      theme: 'auto',
      language: 'zh-CN'
    };

    return new TextBlock(
      `settings-${Date.now()}`,
      null,
      JSON.stringify(settings, null, 2)
    );
  }
};