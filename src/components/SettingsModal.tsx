// 设置模态框组件
import React, { useState, useEffect } from 'react';
import { Modal, Form, Switch, Input, Button, Space, message } from 'antd';
import { SettingOutlined } from '@ant-design/icons';
import { useSettingsManager } from '../stores/settingsManager';
import * as Y from 'yjs';

const { Item } = Form;

export const SettingsModal: React.FC = () => {
  const [visible, setVisible] = useState(false);
  const { settings, updateRelaySettings, isInitialized } = useSettingsManager();
  const [form] = Form.useForm();

  // 当设置变更时更新表单
  useEffect(() => {
    if (visible && isInitialized) {
      form.setFieldsValue({
        relayEnabled: settings.relay.enabled,
        relayIp: settings.relay.ip,
        relayPort: settings.relay.port,
        relayPath: settings.relay.path
      });
    }
  }, [visible, settings, form, isInitialized]);

  // 处理表单提交
  const handleSubmit = async (values: any) => {
    try {
      updateRelaySettings({
        enabled: values.relayEnabled,
        ip: values.relayIp,
        port: values.relayPort,
        path: values.relayPath
      });
      
      message.success('设置已保存');
      setVisible(false);
    } catch (error) {
      console.error('保存设置失败:', error);
      message.error('保存设置失败');
    }
  };

  // 处理中继设置变更
  const handleRelayChange = (checked: boolean) => {
    form.setFieldsValue({ relayEnabled: checked });
  };

  return (
    <>
      <Button
        type="text"
        icon={<SettingOutlined />}
        onClick={() => setVisible(true)}
        style={{ marginRight: 8 }}
      >
        设置
      </Button>

      <Modal
        title="应用设置"
        open={visible}
        onCancel={() => setVisible(false)}
        footer={null}
        width={600}
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSubmit}
          initialValues={{
            relayEnabled: settings.relay.enabled,
            relayIp: settings.relay.ip,
            relayPort: settings.relay.port,
            relayPath: settings.relay.path
          }}
        >
          {/* 中继服务设置 */}
          <Item
            label="中继服务"
            name="relayEnabled"
            valuePropName="checked"
            help="开启后可以使用中继服务进行多端同步"
          >
            <Switch onChange={handleRelayChange} />
          </Item>

          {/* 中继服务详细配置 - 仅在启用时显示 */}
          {settings.relay.enabled && (
            <>
              <Item
                label="中继服务IP"
                name="relayIp"
                rules={[
                  { required: true, message: '请输入中继服务IP地址' },
                  { pattern: /^[a-zA-Z0-9.-]+$/, message: '请输入有效的IP地址或域名' }
                ]}
              >
                <Input placeholder="localhost" />
              </Item>

              <Item
                label="端口号"
                name="relayPort"
                rules={[
                  { required: true, message: '请输入端口号' },
                  { type: 'number', min: 1, max: 65535, message: '请输入1-65535之间的端口号' }
                ]}
              >
                <Input type="number" placeholder="8080" />
              </Item>

              <Item
                label="路径"
                name="relayPath"
                rules={[
                  { required: true, message: '请输入服务路径' },
                  { pattern: /^\//, message: '路径必须以/开头' }
                ]}
              >
                <Input placeholder="/relay" />
              </Item>
            </>
          )}

          <Item>
            <Space>
              <Button type="primary" htmlType="submit">
                保存设置
              </Button>
              <Button onClick={() => setVisible(false)}>
                取消
              </Button>
            </Space>
          </Item>
        </Form>

        {/* 显示当前配置摘要 */}
        {settings.relay.enabled && (
          <div style={{ marginTop: 24, padding: 16, background: '#f5f5f5', borderRadius: 4 }}>
            <h4>当前配置</h4>
            <p>中继地址: ws://{settings.relay.ip}:{settings.relay.port}{settings.relay.path}</p>
            <p>最后更新: {settings.lastUpdated.toLocaleString()}</p>
          </div>
        )}
      </Modal>
    </>
  );
};