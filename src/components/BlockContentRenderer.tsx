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
  block: UnifiedBlock;
}

export const BlockContentRenderer: React.FC<Props> = ({ block }) => {
  console.log('BlockRenderer接收到的block:', block);
  console.log('Block类型:', block?.type);
  console.log('Block属性:', block?.properties);

  if (!block || !block.properties) {
    console.log('Block数据不完整，显示加载状态');
    return <div>加载中...</div>;
  }

  const renderContent = () => {
    console.log('开始渲染内容，block类型:', block.type);
    
    if (isDocBlock(block)) {
      console.log('渲染DOC类型块');
      return (
        <Card className="doc-block">
          <Title level={2}>{block.properties.title || '无标题'}</Title>
          <Paragraph>{block.properties.content || '无内容'}</Paragraph>
        </Card>
      );
    }

    if (isTextBlock(block)) {
      return (
        <Card className="text-block">
          <Paragraph>{block.properties.content}</Paragraph>
        </Card>
      );
    }

    if (isCodeBlock(block)) {
      return (
        <Card className="code-block">
          <pre>
            <code>{block.properties.code}</code>
          </pre>
        </Card>
      );
    }

    if (isMediaBlock(block)) {
      return (
        <Card className="media-block">
          <img 
            src={block.properties.filePath} 
            alt={block.properties.fileName} 
            style={{ maxWidth: '100%' }}
          />
        </Card>
      );
    }

    return null;
  };

  return <div className="block-renderer">{renderContent()}</div>;
};
