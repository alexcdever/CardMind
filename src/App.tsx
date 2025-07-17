import React from 'react';
import { useBlockManager } from './stores/blockManager';
import { BlockPage } from './components/BlockPage';
import { BlockRenderer } from './components/BlockRenderer';
import { BlockCreator } from './components/BlockCreator';
import { BlockListView } from './components/BlockListView';

const App: React.FC = () => {
  const { openBlockId, fetchAllBlocks } = useBlockManager();

  React.useEffect(() => {
    fetchAllBlocks();
  }, [fetchAllBlocks]);

  return (
    <div className="app">
      {openBlockId ? (
        <BlockPage blockId={openBlockId}>
          <BlockRenderer blockId={openBlockId} />
        </BlockPage>
      ) : (
        <>
          <BlockCreator />
          <BlockListView />
        </>
      )}
    </div>
  );
};

export default App;
