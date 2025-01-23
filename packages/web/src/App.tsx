import React, { useState, useCallback } from 'react';
import { FloatButton } from 'antd';
import { PlusOutlined } from '@ant-design/icons';
import CardList from './components/CardList';
import CardEditor from './components/CardEditor';
import { Card } from './types/electron';

const App: React.FC = () => {
  const [editorVisible, setEditorVisible] = useState(false);
  const [selectedCard, setSelectedCard] = useState<Card | null>(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  const handleAddCard = useCallback(() => {
    console.log('App: Opening editor for new card');
    setSelectedCard(null);
    setEditorVisible(true);
  }, []);

  const handleEditCard = useCallback((card: Card) => {
    console.log('App: Opening editor for existing card:', card);
    setSelectedCard(card);
    setEditorVisible(true);
  }, []);

  const handleEditorClose = useCallback(() => {
    console.log('App: Closing editor');
    setSelectedCard(null);
    setEditorVisible(false);
    // 使用函数式更新，确保拿到最新的值
    setRefreshTrigger(prev => prev + 1);
  }, []);

  const refreshCards = useCallback(() => {
    console.log('App: Triggering card refresh');
    setRefreshTrigger(prev => prev + 1);
  }, []);

  return (
    <div className="App">
      {editorVisible ? (
        <CardEditor onClose={handleEditorClose} card={selectedCard} />
      ) : (
        <CardList onEditCard={handleEditCard} refreshTrigger={refreshTrigger} />
      )}
      {!editorVisible && (
        <FloatButton
          icon={<PlusOutlined />}
          type="primary"
          style={{ 
            position: 'fixed',
            left: '50%',
            transform: 'translateX(-50%)',
            bottom: 24
          }}
          onClick={handleAddCard}
        />
      )}
    </div>
  );
};

export default App;