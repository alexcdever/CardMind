import React from 'react';
import { useBlockManager } from '../stores/blockManager';
import { UnifiedBlock, BlockType, DocBlockProperties, TextBlockProperties, MediaBlockProperties, CodeBlockProperties } from '../types/block';

// 类型守卫函数
function isDocBlock(block: UnifiedBlock): block is UnifiedBlock & { properties: DocBlockProperties } {
  return block.type === BlockType.DOC;
}

function isTextBlock(block: UnifiedBlock): block is UnifiedBlock & { properties: TextBlockProperties } {
  return block.type === BlockType.TEXT;
}

function isMediaBlock(block: UnifiedBlock): block is UnifiedBlock & { properties: MediaBlockProperties } {
  return block.type === BlockType.MEDIA;
}

function isCodeBlock(block: UnifiedBlock): block is UnifiedBlock & { properties: CodeBlockProperties } {
  return block.type === BlockType.CODE;
}

interface Props {
  blockId: string;
}

export const BlockRenderer: React.FC<Props> = ({ blockId }) => {
  console.log('BlockRenderer接收到的blockId:', blockId);
  const { openBlock } = useBlockManager();
  console.log('当前openBlock:', openBlock);

  if (!openBlock || openBlock.id !== blockId) {
    return null;
  }

  const renderContent = () => {
    if (isDocBlock(openBlock)) {
      return (
        <div className="doc-block">
          <h1>{openBlock.properties.title}</h1>
          <div>{openBlock.properties.content}</div>
        </div>
      );
    }

    if (isTextBlock(openBlock)) {
      return <div className="text-block">{openBlock.properties.content}</div>;
    }

    if (isCodeBlock(openBlock)) {
      return (
        <pre className="code-block">
          <code>{openBlock.properties.code}</code>
        </pre>
      );
    }

    if (isMediaBlock(openBlock)) {
      return (
        <div className="media-block">
          <img 
            src={openBlock.properties.filePath} 
            alt={openBlock.properties.fileName} 
          />
        </div>
      );
    }

    return null;
  };

  return <div className="block-renderer">{renderContent()}</div>;
};
