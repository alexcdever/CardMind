// 导入必要的依赖
import React, { useState, useCallback } from 'react';
import { FloatButton } from 'antd';
import { PlusOutlined } from '@ant-design/icons';
import CardList from './components/CardList';
import CardEditor from './components/CardEditor';

// 应用主组件
const App: React.FC = () => {
  // 状态管理
  const [editorVisible, setEditorVisible] = useState(false);  // 编辑器显示状态
  const [selectedCard, setSelectedCard] = useState<Card | null>(null);  // 当前选中的卡片
  const [refreshTrigger, setRefreshTrigger] = useState(0);  // 刷新触发器

  // 处理添加新卡片
  const handleAddCard = useCallback(() => {
    console.log('App: 打开编辑器创建新卡片');
    setSelectedCard(null);
    setEditorVisible(true);
  }, []);

  // 处理编辑现有卡片
  const handleEditCard = useCallback((card: Card) => {
    console.log('App: 打开编辑器修改卡片:', card);
    setSelectedCard(card);
    setEditorVisible(true);
  }, []);

  // 处理编辑器关闭
  const handleEditorClose = useCallback(() => {
    console.log('App: 关闭编辑器');
    setSelectedCard(null);
    setEditorVisible(false);
    // 使用函数式更新，确保拿到最新的值
    setRefreshTrigger(prev => prev + 1);
  }, []);

  // 刷新卡片列表
  const refreshCards = useCallback(() => {
    console.log('App: 触发卡片列表刷新');
    setRefreshTrigger(prev => prev + 1);
  }, []);

  // 渲染UI
  return (
    <div className="App">
      {/* 根据编辑器状态显示编辑器或卡片列表 */}
      {editorVisible ? (
        <CardEditor onClose={handleEditorClose} card={selectedCard} />
      ) : (
        <CardList onEditCard={handleEditCard} refreshTrigger={refreshTrigger} />
      )}
      {/* 添加新卡片的悬浮按钮 */}
      {!editorVisible && (
        <FloatButton
          icon={<PlusOutlined />}
          type="primary"
          style={{ 
            position: 'fixed',
            left: '50%',
            bottom: '24px',
            transform: 'translateX(-50%)',
          }}
          onClick={handleAddCard}
        />
      )}
    </div>
  );
};

export default App;