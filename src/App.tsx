import React from 'react';
import { useBlockManager } from './stores/blockManager';
import { DocEditor } from './components/DocEditor';
import { DocumentGallery } from './components/DocumentGallery';

const App: React.FC = () => {
  const { getAllBlocks } = useBlockManager();

  React.useEffect(() => {
    getAllBlocks();
  }, [getAllBlocks]);

  return (
    <div className="app">
      <>
        <DocEditor />
        <DocumentGallery />
      </>
    </div>
  );
};

export default App;
