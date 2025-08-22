import React from 'react';
import { Card, Typography, Space, Switch, Button } from 'antd';
import { SettingOutlined, UserOutlined, BellOutlined, FormatPainterOutlined } from '@ant-design/icons';

const { Title, Text } = Typography;

// 设置页面组件
const SettingsView: React.FC = () => {
  return (
    <div style={{ 
      padding: '40px 20px', 
      maxWidth: 800, 
      margin: '0 auto',
      background: '#f5f5f5',
      minHeight: 'calc(100vh - 120px)'
    }}>
      <Title level={2} style={{ textAlign: 'center', marginBottom: 32 }}>
        <SettingOutlined /> 设置
      </Title>

      <Space direction="vertical" size="large" style={{ width: '100%' }}>
        {/* 账户设置 */}
        <Card title={<><UserOutlined /> 账户设置</>}>
          <Space direction="vertical" style={{ width: '100%' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Text>用户名</Text>
              <Text type="secondary">当前用户</Text>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Text>邮箱</Text>
              <Text type="secondary">user@example.com</Text>
            </div>
          </Space>
        </Card>

        {/* 通知设置 */}
        <Card title={<><BellOutlined /> 通知设置</>}>
          <Space direction="vertical" style={{ width: '100%' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Text>新笔记提醒</Text>
              <Switch defaultChecked />
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Text>学习提醒</Text>
              <Switch />
            </div>
          </Space>
        </Card>

        {/* 外观设置 */}
        <Card title={<><FormatPainterOutlined /> 外观设置</>}>
          <Space direction="vertical" style={{ width: '100%' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Text>深色模式</Text>
              <Switch />
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <Text>紧凑模式</Text>
              <Switch />
            </div>
          </Space>
        </Card>

        {/* 关于 */}
        <Card title="关于">
          <Space direction="vertical" style={{ width: '100%' }}>
            <Text>版本: 1.0.0</Text>
            <Text>CardMind - 你的知识卡片库</Text>
            <Button type="link">查看帮助文档</Button>
          </Space>
        </Card>
      </Space>
    </div>
  );
};

export default SettingsView;