import React from 'react';
import { useBlockManager } from '../stores/blockManager';
import { UnifiedBlock, BlockType, DocBlockProperties, TextBlockProperties, MediaBlockProperties, CodeBlockProperties } from '../types/block';
import { Card, Typography } from 'antd';
const { Title, Paragraph } = Typography;

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

export const BlockContentRenderer: React.FC<Props> = ({ blockId }) => {
  console.log('BlockRenderer接收到的blockId:', blockId);
  const { openBlock } = useBlockManager();
  console.log('当前openBlock:', openBlock);

  if (!openBlock || openBlock.id !== blockId) {
    return null;
  }

  const renderContent = () => {
    if (isDocBlock(openBlock)) {
      return (
        <Card className="doc-block">
          <Title level={2}>{openBlock.properties.title}</Title>
          <Paragraph>{openBlock.properties.content}</Paragraph>
        </Card>
      );
    }

    if (isTextBlock(openBlock)) {
      return (
        <Card className="text-block">
          <Paragraph>{openBlock.properties.content}</Paragraph>
        </Card>
      );
    }

    if (isCodeBlock(openBlock)) {
      return (
        <Card className="code-block">
          <pre>
            <code>{openBlock.properties.code}</code>
          </pre>
        </Card>
      );
    }

    if (isMediaBlock(openBlock)) {
      return (
        <Card className="media-block">
          <img 
            src={openBlock.properties.filePath} 
            alt={openBlock.properties.fileName} 
            style={{ maxWidth: '100%' }}
          />
        </Card>
      );
    }

    return null;
  };

  return <div className="block-renderer">{renderContent()}</div>;
};
