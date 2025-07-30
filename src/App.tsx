import React from 'react';
import { useBlockManager } from './stores/blockManager';
import { DocEditor } from './components/DocEditor';
import { DocList } from './components/DocList';

const App: React.FC = () => {
  const { getAllBlocks } = useBlockManager();

  React.useEffect(() => {
    getAllBlocks();
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
