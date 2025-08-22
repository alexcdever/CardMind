// 文档编辑器组件
import React, { useState, useEffect } from 'react';

import { AnyBlock, TextBlock, DocBlock, MediaBlock, CodeBlock } from '@cardmind/types';
import { SettingsBlock } from './SettingsBlock';
import { Card, Button, Input, Space } from 'antd';
import { SettingOutlined, PlusOutlined } from '@ant-design/icons';
import './DocumentEditor.css';

interface DocumentEditorProps {
  documentId: string;
  onSave: (block: AnyBlock) => Promise<void>;
  onCancel: () => void;
  initialData: {
    title: string;
    content: string;
    tags: string[];
    blocks: AnyBlock[];
  };
}

// 文本块组件
const TextBlockComponent: React.FC<{
  block: TextBlock;
  onUpdate: (block: TextBlock) => void;
  onDelete: (blockId: string) => void;
}> = ({ block, onUpdate }) => {
  const [content, setContent] = useState(block.content || '');
  
  return (
    <Card size="small" className="block-card">
      <Input.TextArea
        value={content}
        onChange={(e) => setContent(e.target.value)}
        onBlur={() => {
          const updatedBlock = new TextBlock(
            block.id,
            block.parentId,
            content
          );
          updatedBlock.childrenIds = block.childrenIds;
          updatedBlock.createdAt = block.createdAt;
          updatedBlock.modifiedAt = new Date();
          updatedBlock.isDeleted = block.isDeleted;
          onUpdate(updatedBlock);
        }}
        placeholder="输入文本内容..."
        autoSize={{ minRows: 2, maxRows: 6 }}
        bordered={false}
      />
    </Card>
  );
};

// 图片块组件
const ImageBlockComponent: React.FC<{
  block: MediaBlock;
  onUpdate: (block: MediaBlock) => void;
  onDelete: (blockId: string) => void;
}> = ({ block }) => {
  return (
    <Card size="small" className="block-card">
      <div>
        <img 
          src={block.filePath} 
          alt="图片块" 
          style={{ maxWidth: '100%', maxHeight: '200px' }}
        />
      </div>
    </Card>
  );
};

// 代码块组件
const CodeBlockComponent: React.FC<{
  block: CodeBlock;
  onUpdate: (block: CodeBlock) => void;
  onDelete: (blockId: string) => void;
}> = ({ block, onUpdate }) => {
  const [code, setCode] = useState(block.code || '');
  
  return (
    <Card size="small" className="block-card">
      <Input.TextArea
        value={code}
        onChange={(e) => setCode(e.target.value)}
        onBlur={() => {
          const updatedBlock = new CodeBlock(
            block.id,
            block.parentId,
            code,
            block.language
          );
          updatedBlock.childrenIds = block.childrenIds;
          updatedBlock.createdAt = block.createdAt;
          updatedBlock.modifiedAt = new Date();
          updatedBlock.isDeleted = block.isDeleted;
          onUpdate(updatedBlock);
        }}
        placeholder="输入代码..."
        autoSize={{ minRows: 3, maxRows: 10 }}
        bordered={false}
      />
    </Card>
  );
};

export default function DocumentEditor({ initialData }: DocumentEditorProps) {
  const [title, setTitle] = useState('');
  const [editingTitle, setEditingTitle] = useState(false);

  // 同步标题
  useEffect(() => {
    if (initialData) {
      setTitle(initialData.title);
    } else {
      setTitle('');
    }
  }, [initialData]);

  // 使用传入的初始数据
  if (!initialData) {
    return (
      <div className="document-editor">
        <div className="empty-editor">
          <h2>选择一个文档开始编辑</h2>
          <p>或者创建一个新文档</p>
        </div>
      </div>
    );
  }

  // 处理标题更新
  const handleTitleChange = async (newTitle: string) => {
    if (initialData && newTitle !== initialData.title) {
      // 调用传入的保存回调
      // await onSave(/* appropriate parameters */);
      console.log('Title changed:', newTitle);
    }
  };

  // 处理标题失焦
  const handleTitleBlur = () => {
    setEditingTitle(false);
    handleTitleChange(title);
  };

  // 处理更新块
  const handleUpdateBlock = async (updatedBlock: AnyBlock) => {
    // 调用传入的保存回调
    // await onSave(updatedBlock);
    console.log('Update block:', updatedBlock);
  };

  // 处理删除块
  const handleDeleteBlock = async (blockId: string) => {
    // 实现删除逻辑或调用传入的回调
    console.log('Delete block:', blockId);
  };

  // 渲染块
  const renderBlock = (block: AnyBlock) => {
    // 使用instanceof进行类型检查
    if (block instanceof TextBlock) {
      // 检查是否为设置块（通过内容判断）
      if (block.content && block.content.includes('"relayEnabled"')) {
        return (
          <SettingsBlock 
            key={block.id} 
            block={block}
            onSave={handleUpdateBlock}
          />
        );
      }
      return (
        <TextBlockComponent
          key={block.id}
          block={block}
          onUpdate={handleUpdateBlock}
          onDelete={handleDeleteBlock}
        />
      );
    } else if (block instanceof MediaBlock) {
      return (
        <ImageBlockComponent
          key={block.id}
          block={block}
          onUpdate={handleUpdateBlock}
          onDelete={handleDeleteBlock}
        />
      );
    } else if (block instanceof CodeBlock) {
      return (
        <CodeBlockComponent
          key={block.id}
          block={block}
          onUpdate={handleUpdateBlock}
          onDelete={handleDeleteBlock}
        />
      );
    } else {
      return (
        <Card key={block.id} size="small" className="block-card">
          <div>未知块类型</div>
        </Card>
      );
    }
  };

  // 添加新块
  const handleAddBlock = (type: string) => {
    // 实现添加块逻辑或调用传入的回调
    console.log('Add block:', type);
  };

  // 插入设置块
  const handleInsertSettingsBlock = () => {
    // 实现插入设置块逻辑或调用传入的回调
    console.log('Insert settings block');
  };

  // 移除了对state.currentDocument的检查，因为现在使用initialData

  return (
    <div className="document-editor">
      <div className="editor-header">
        <div className="document-title">
          {editingTitle ? (
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              onBlur={handleTitleBlur}
              onPressEnter={handleTitleBlur}
              autoFocus
              bordered={false}
              style={{ fontSize: 24, fontWeight: 'bold' }}
            />
          ) : (
            <h1 onClick={() => setEditingTitle(true)} style={{ cursor: 'pointer' }}>
              {title || '无标题文档'}
            </h1>
          )}
        </div>
      </div>

      <div className="editor-toolbar">
        <Space>
          <Button 
            type="primary" 
            icon={<SettingOutlined />}
            onClick={handleInsertSettingsBlock}
          >
            添加设置
          </Button>
          <Button 
            icon={<PlusOutlined />}
            onClick={() => handleAddBlock('text')}
          >
            文本
          </Button>
          <Button 
            icon={<PlusOutlined />}
            onClick={() => handleAddBlock('image')}
          >
            图片
          </Button>
          <Button 
            icon={<PlusOutlined />}
            onClick={() => handleAddBlock('code')}
          >
            代码
          </Button>
          <Button 
            icon={<PlusOutlined />}
            onClick={() => handleAddBlock('text')}
          >
            文本
          </Button>
        </Space>
      </div>

      <div className="editor-content">
        <div className="blocks">
          {initialData.blocks.map((block: AnyBlock) => renderBlock(block))}
        </div>
      </div>
    </div>
  );
}