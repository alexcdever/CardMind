import React, { useState, useEffect } from 'react';
import { Modal, Form, Switch, Input, Button, Space, message } from 'antd';
import { SettingOutlined } from '@ant-design/icons';
import { yjsManager } from '@cardmind/shared';

// 中继服务配置接口
interface RelaySettings {
  enabled: boolean;
  ip: string;
  port: number;
  path: string;
}

// 应用设置接口
interface AppSettings {
  relay: RelaySettings;
}

const defaultSettings: AppSettings = {
  relay: {
    enabled: false,
    ip: 'localhost',
    port: 1234,
    path: '/sync'
  }
};

interface SettingsModalProps {
  visible: boolean;
  onClose: () => void;
}

export const SettingsModal: React.FC<SettingsModalProps> = ({ visible, onClose }) => {
  const [form] = Form.useForm();
  const [settings, setSettings] = useState<AppSettings>(defaultSettings);
  const [loading, setLoading] = useState(false);

  // 加载现有配置
  useEffect(() => {
    if (visible) {
      loadSettings();
    }
  }, [visible]);

  const loadSettings = async () => {
    try {
      const ydoc = yjsManager.getYDoc('settings');
      if (ydoc) {
        const settingsMap = ydoc.getMap('app-settings');
        const savedSettings = settingsMap.get('config') as AppSettings;
        if (savedSettings) {
          // 合并现有配置，避免覆盖
          const mergedSettings = {
            ...defaultSettings,
            ...savedSettings,
            relay: {
              ...defaultSettings.relay,
              ...savedSettings.relay
            }
          };
          setSettings(mergedSettings);
          form.setFieldsValue(mergedSettings);
        } else {
          form.setFieldsValue(defaultSettings);
        }
      }
    } catch (error) {
      console.error('加载设置失败:', error);
      form.setFieldsValue(defaultSettings);
    }
  };

  const handleSave = async (values: AppSettings) => {
    setLoading(true);
    try {
      const ydoc = yjsManager.getYDoc('settings');
      if (ydoc) {
        const settingsMap = ydoc.getMap('app-settings');
        settingsMap.set('config', values);
      }
      setSettings(values);
      message.success('设置已保存');
      onClose();
    } catch (error) {
      console.error('保存设置失败:', error);
      message.error('保存设置失败');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Modal
      title="应用设置"
      open={visible}
      onCancel={onClose}
      footer={null}
      width={600}
    >
      <Form
        form={form}
        layout="vertical"
        initialValues={settings}
        onFinish={handleSave}
      >
        <Form.Item
          label="中继服务"
          name={['relay', 'enabled']}
          valuePropName="checked"
        >
          <Switch />
        </Form.Item>

        <Form.Item
          noStyle
          shouldUpdate={(prev, curr) => prev?.relay?.enabled !== curr?.relay?.enabled}
        >
          {({ getFieldValue }) => {
            const enabled = getFieldValue(['relay', 'enabled']);
            return enabled ? (
              <>
                <Form.Item
                  label="服务器IP"
                  name={['relay', 'ip']}
                  rules={[{ required: true, message: '请输入服务器IP' }]}
                >
                  <Input placeholder="例如: localhost 或 192.168.1.100" />
                </Form.Item>

                <Form.Item
                  label="端口号"
                  name={['relay', 'port']}
                  rules={[
                    { required: true, message: '请输入端口号' },
                    { type: 'number', min: 1, max: 65535, message: '端口号必须在1-65535之间' }
                  ]}
                >
                  <Input type="number" placeholder="例如: 1234" />
                </Form.Item>

                <Form.Item
                  label="服务路径"
                  name={['relay', 'path']}
                  rules={[{ required: true, message: '请输入服务路径' }]}
                >
                  <Input placeholder="例如: /sync" />
                </Form.Item>
              </>
            ) : null;
          }}
        </Form.Item>

        <Form.Item>
          <Space style={{ width: '100%', justifyContent: 'flex-end' }}>
            <Button onClick={onClose}>取消</Button>
            <Button type="primary" htmlType="submit" loading={loading}>
              保存设置
            </Button>
          </Space>
        </Form.Item>
      </Form>
    </Modal>
  );
};

// 设置按钮组件
export const SettingsButton: React.FC = () => {
  const [visible, setVisible] = useState(false);

  return (
    <>
      <Button
        type="text"
        icon={<SettingOutlined />}
        onClick={() => setVisible(true)}
        title="应用设置"
      />
      <SettingsModal
        visible={visible}
        onClose={() => setVisible(false)}
      />
    </>
  );
};