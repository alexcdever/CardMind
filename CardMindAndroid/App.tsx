import React from 'react';
import { useBlockManager } from './src/stores/blockManager';
import { DocEditor } from './src/components/DocEditor';
import { DocList } from './src/components/DocList';

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
