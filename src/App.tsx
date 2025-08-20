import React, { useEffect } from 'react';
import { useBlockManager } from './stores/blockManager';
import { DocEditor } from './components/DocEditor';
import { DocList } from './components/DocList';

const App: React.FC = () => {
  const { getAllBlocks } = useBlockManager();

  useEffect(() => {
    getAllBlocks().catch(console.error);
  }, [getAllBlocks]);

  return (
    <div className="app">
      <>
        <DocEditor />
        <DocList />
      </>
    </div>
  );
};

export default App;
