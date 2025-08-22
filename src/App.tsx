import React, { useEffect } from 'react';
import { useBlockManager } from './stores/blockManager';
import { useSettingsManager } from './stores/settingsManager';
import { DocEditor } from './components/DocEditor';
import { DocList } from './components/DocList';
import { SettingsModal } from './components/SettingsModal';
import * as Y from 'yjs';

const App: React.FC = () => {
  const { getAllBlocks } = useBlockManager();
  const { initializeSettings } = useSettingsManager();

  useEffect(() => {
    // 初始化设置管理器
    const yDoc = new Y.Doc();
    initializeSettings(yDoc);
    
    // 加载卡片数据
    getAllBlocks().catch(console.error);
  }, [getAllBlocks, initializeSettings]);

  return (
    <div className="app">
      <div style={{ padding: '16px', borderBottom: '1px solid #eee', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1 style={{ margin: 0 }}>CardMind</h1>
        <SettingsModal />
      </div>
      <div style={{ padding: '16px' }}>
        <DocEditor />
        <DocList />
      </div>
    </div>
  );
};

export default App;
