import React from 'react';
import { PlusOutlined, UnorderedListOutlined, CompassOutlined, SettingOutlined } from '@ant-design/icons';
import { FloatButton, Button } from 'antd';
import './BottomNavigation.css';

interface BottomNavigationProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
  onAddClick: () => void;
}

const BottomNavigation: React.FC<BottomNavigationProps> = ({ 
  activeTab, 
  onTabChange, 
  onAddClick 
}) => {
  const tabs = [
    { key: 'list', label: '列表', icon: <UnorderedListOutlined /> },
    { key: 'explore', label: '探索', icon: <CompassOutlined /> },
    { key: 'settings', label: '设置', icon: <SettingOutlined /> }
  ];

  return (
    <>
      {/* 添加按钮 - 悬浮在右下角 */}
      <FloatButton
        icon={<PlusOutlined />}
        type="primary"
        style={{
          right: 24,
          bottom: 100,
          width: 56,
          height: 56,
          boxShadow: '0 4px 12px rgba(0,0,0,0.3)',
          zIndex: 1001
        }}
        onClick={onAddClick}
      />

      {/* 底部导航栏 - 添加背景色调试用 */}
      <div 
        className="bottom-nav"
        style={{
          background: '#1890ff', // 临时调试用蓝色背景
          color: 'white',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: '16px',
          fontWeight: 'bold'
        }}
      >
        <div className="bottom-nav-content">
          {tabs.map(tab => (
            <Button
              key={tab.key}
              type="text"
              className={`nav-item ${activeTab === tab.key ? 'active' : ''}`}
              icon={tab.icon}
              onClick={() => onTabChange(tab.key)}
              style={{ color: 'white' }}
            >
              {tab.label}
            </Button>
          ))}
        </div>
      </div>
    </>
  );
};

export default BottomNavigation;