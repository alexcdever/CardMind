import React, { useRef } from 'react';

// 主页面组件 - 管理整体布局
const MainPage: React.FC = () => {
  const cardListRef = useRef<{ addNewCard: () => void }>(null);

  // 渲染当前激活的视图内容
  const renderContent = () => {
    switch ('list') {
      case 'list':
        return (
          <div style={{ 
            background: 'white', 
            padding: '20px', 
            borderRadius: '8px',
            minHeight: '200px'
          }}>
            <h3>📋 笔记列表页面</h3>
            <p>这里应该显示卡片列表...</p>
            <div style={{ marginTop: '20px' }}>
              <button 
                onClick={() => cardListRef.current?.addNewCard?.()} 
                style={{
                  background: '#1890ff',
                  color: 'white',
                  border: 'none',
                  padding: '10px 20px',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                测试添加卡片功能
              </button>
            </div>
          </div>
        );
      case 'explore' as any:
        return (
          <div style={{ 
            background: 'white', 
            padding: '20px', 
            borderRadius: '8px',
            minHeight: '200px'
          }}>
            <h3>🔍 探索页面</h3>
            <p>探索功能开发中...</p>
          </div>
        );
      case 'settings' as any:
        return (
          <div style={{ 
            background: 'white', 
            padding: '20px', 
            borderRadius: '8px',
            minHeight: '200px'
          }}>
            <h3>⚙️ 设置页面</h3>
            <p>设置功能开发中...</p>
          </div>
        );
      default:
        return (
          <div style={{ 
            background: 'white', 
            padding: '20px', 
            borderRadius: '8px',
            minHeight: '200px'
          }}>
            <h3>🏠 首页内容</h3>
            <p>欢迎来到CardMind！</p>
          </div>
        );
    }
  };



  return (
    <div style={{ 
      height: '100vh', 
      display: 'flex', 
      flexDirection: 'column',
      background: '#f5f5f5'
    }}>
      {/* 顶部标题区域 */}
      <div style={{
        background: 'red', // 明显的红色背景用于调试
        padding: '16px 20px',
        textAlign: 'center',
        color: 'white',
        fontWeight: 'bold'
      }}>
        🔍 调试模式 - 顶部标题栏
      </div>

      {/* 主内容区域 */}
      <div style={{ 
        flex: 1,
        overflow: 'auto',
        padding: '20px',
        background: '#e6f7ff' // 浅蓝色背景便于观察
      }}>
        <div style={{ 
          background: 'white', 
          padding: '20px', 
          borderRadius: '8px',
          marginBottom: '20px'
        }}>
          <h2>当前激活标签: {'list'}</h2>
          <p>如果看到底部有红色/蓝色条，说明导航栏已渲染</p>
        </div>
        {renderContent()}
      </div>

      {/* 简化的底部导航栏 - 确保绝对可见 */}
      <div style={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        height: '60px',
        background: '#ff4d4f', // 鲜红色背景
        color: 'white',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: '18px',
        fontWeight: 'bold',
        zIndex: 9999,
        borderTop: '3px solid #ff7875'
      }}>
        🚀 底部导航栏在这里！
      </div>
    </div>
  );
};

export default MainPage;