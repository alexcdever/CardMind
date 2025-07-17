import React, { useEffect } from 'react';
import { useBlockManager } from '../stores/blockManager';

interface Props {
  blockId: string;
  children?: React.ReactNode;
}

export const BlockPage: React.FC<Props> = ({ blockId, children }) => {
  const { openBlockDoc, closeBlockDoc, openBlock } = useBlockManager();

  // 打开块文档
  useEffect(() => {
    openBlockDoc(blockId);
    return () => closeBlockDoc();
  }, [blockId]);

  // 渲染块内容
  return (
    <div className="block-page">
      {openBlock?.id === blockId && children}
    </div>
  );
};
