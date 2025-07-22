import React from 'react';
import { useBlockManager } from './stores/blockManager';
import { DocumentViewer } from './components/DocumentViewer';
import { BlockContentRenderer } from './components/BlockContentRenderer';
import { DocumentCreator } from './components/DocumentCreator';
import { DocumentGallery } from './components/DocumentGallery';

const App: React.FC = () => {
  const { openBlockId, fetchAllBlocks } = useBlockManager();

  React.useEffect(() => {
    fetchAllBlocks();
  }, [fetchAllBlocks]);

  return (
    <div className="app">
      {openBlockId ? (
        <DocumentViewer blockId={openBlockId}>
          <BlockContentRenderer blockId={openBlockId} />
        </DocumentViewer>
      ) : (
        <>
          <DocumentCreator />
          <DocumentGallery />
        </>
      )}
    </div>
  );
};

export default App;
