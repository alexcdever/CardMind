import React from 'react';
import { Empty, Button } from 'antd';
import { CompassOutlined } from '@ant-design/icons';

// 探索页面组件 - 占位符
const ExploreView: React.FC = () => {
  return (
    <div style={{ 
      padding: '40px 20px', 
      textAlign: 'center', 
      background: '#f5f5f5',
      minHeight: 'calc(100vh - 120px)'
    }}>
      <Empty
        image={<CompassOutlined style={{ fontSize: 64, color: '#1890ff' }} />}
        description={
          <div>
            <h2 style={{ color: '#666', marginBottom: 16 }}>探索功能开发中</h2>
            <p style={{ color: '#999', marginBottom: 24 }}>
              即将推出智能推荐、热门笔记、学习社区等功能
            </p>
            <Button type="primary" size="large">
              敬请期待
            </Button>
          </div>
        }
      />
    </div>
  );
};

export default ExploreView;