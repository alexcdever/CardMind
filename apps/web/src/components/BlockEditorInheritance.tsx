import React, { useState, useEffect, useRef } from 'react';
import { AnyBlock } from '@cardmind/types';
import { useDocumentContext } from '../contexts/DocumentContext';
import { BlockRenderer } from './BlockRenderer';
import { BlockToolbar } from './BlockToolbar';

interface BlockEditorProps {
  block: Block; // 使用新的Block基类类型
}

export default function BlockEditor({ block }: BlockEditorProps) {
  const { updateBlock } = useDocuments();
  const [isEditing, setIsEditing] = useState(false);
  
  // 根据块类型初始化内容
  const [content, setContent] = useState(() => {
    if (isDocBlock(block)) {
      return block.content;
    } else if (isTextBlock(block)) {
      return block.content;
    } else if (isCodeBlock(block)) {
      return block.code;
    } else if (isMediaBlock(block)) {
      // 对于媒体块，我们存储内容在filePath属性中
      return block.filePath || '';
    }
    return '';
  });

  const handleSave = async () => {
    // 根据块类型创建更新后的块实例
    let updatedBlock: Block;
    
    if (isDocBlock(block)) {
      updatedBlock = new class extends block.constructor {
        constructor() {
          super(block.id, block.parentId, block.title, content);
          // 复制其他属性
          this.childrenIds = block.childrenIds;
          this.createdAt = block.createdAt;
          this.modifiedAt = new Date();
          this.isDeleted = block.isDeleted;
        }
      }();
    } else if (isTextBlock(block)) {
      updatedBlock = new class extends block.constructor {
        constructor() {
          super(block.id, block.parentId, content);
          // 复制其他属性
          this.childrenIds = block.childrenIds;
          this.createdAt = block.createdAt;
          this.modifiedAt = new Date();
          this.isDeleted = block.isDeleted;
        }
      }();
    } else if (isCodeBlock(block)) {
      updatedBlock = new class extends block.constructor {
        constructor() {
          super(block.id, block.parentId, content, block.language);
          // 复制其他属性
          this.childrenIds = block.childrenIds;
          this.createdAt = block.createdAt;
          this.modifiedAt = new Date();
          this.isDeleted = block.isDeleted;
        }
      }();
    } else if (isMediaBlock(block)) {
      updatedBlock = new class extends block.constructor {
        constructor() {
          super(block.id, block.parentId, content, block.fileHash, block.fileName, block.thumbnailPath);
          // 复制其他属性
          this.childrenIds = block.childrenIds;
          this.createdAt = block.createdAt;
          this.modifiedAt = new Date();
          this.isDeleted = block.isDeleted;
        }
      }();
    } else {
      // 如果是未知类型，直接返回原块
      updatedBlock = block;
    }
    
    // 更新块
    await updateBlock(updatedBlock);
    setIsEditing(false);
  };

  const handleDelete = async () => {
    if (window.confirm('确定要删除这个块吗？')) {
      // 需要传递documentId和blockId两个参数
      // await deleteBlock(documentId, block.id);
      console.log('Delete block:', block.id);
    }
  };

  const renderBlockContent = () => {
    // 使用类型守卫函数进行类型检查
    if (isDocBlock(block)) {
      return isEditing ? (
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          onBlur={handleSave}
          onKeyPress={(e) => e.key === 'Enter' && e.shiftKey === false && handleSave()}
          autoFocus
          className="text-editor"
          placeholder="输入文档内容..."
        />
      ) : (
        <div 
          className="text-display"
          onClick={() => setIsEditing(true)}
          dangerouslySetInnerHTML={{ __html: content.replace(/\n/g, '<br/>') || '<em>点击编辑文档</em>' }}
        />
      );
    } else if (isTextBlock(block)) {
      return isEditing ? (
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          onBlur={handleSave}
          onKeyPress={(e) => e.key === 'Enter' && e.shiftKey === false && handleSave()}
          autoFocus
          className="text-editor"
          placeholder="输入文本..."
        />
      ) : (
        <div 
          className="text-display"
          onClick={() => setIsEditing(true)}
          dangerouslySetInnerHTML={{ __html: content.replace(/\n/g, '<br/>') || '<em>点击编辑文本</em>' }}
        />
      );
    } else if (isCodeBlock(block)) {
      return isEditing ? (
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          onBlur={handleSave}
          onKeyPress={(e) => {
            // 对于代码块，只在Ctrl+Enter或Cmd+Enter时保存，允许换行输入
            if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
              e.preventDefault();
              handleSave();
            }
          }}
          autoFocus
          className="code-editor"
          placeholder="输入代码..."
        />
      ) : (
        <pre 
          className="code-display"
          onClick={() => setIsEditing(true)}
        >
          {content || <em>点击编辑代码</em>}
        </pre>
      );
    } else if (isMediaBlock(block)) {
      // 检查是否为待办事项
      const isTodo = block.fileName === 'todo';
      
      if (isTodo) {
        const isChecked = content.startsWith('[x] ');
        const todoText = content.replace(/^\[x\] |^\[ \] /, '');
        
        return (
          <div className="todo-block">
            <input
              type="checkbox"
              checked={isChecked}
              onChange={(e) => {
                const newContent = e.target.checked ? `[x] ${todoText}` : `[ ] ${todoText}`;
                setContent(newContent);
                // 创建更新后的块实例
                const updatedBlock = new class extends block.constructor {
                  constructor() {
                    super(block.id, block.parentId, newContent, block.fileHash, 'todo', block.thumbnailPath);
                    // 复制其他属性
                    this.childrenIds = block.childrenIds;
                    this.createdAt = block.createdAt;
                    this.modifiedAt = new Date();
                    this.isDeleted = block.isDeleted;
                  }
                }();
                updateBlock(updatedBlock);
              }}
            />
            {isEditing ? (
              <input
                type="text"
                value={todoText}
                onChange={(e) => setContent(`[${isChecked ? 'x' : ' '}] ${e.target.value}`)}
                onBlur={handleSave}
                onKeyPress={(e) => e.key === 'Enter' && handleSave()}
                autoFocus
                className="todo-editor"
                placeholder="输入待办事项..."
              />
            ) : (
              <span 
                className={`todo-text ${isChecked ? 'completed' : ''}`}
                onClick={() => setIsEditing(true)}
              >
                {todoText || <em>点击编辑待办</em>}
              </span>
            )}
          </div>
        );
      } else {
        // 处理图片
        return isEditing ? (
          <div className="image-editor">
            <input
              type="text"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              onBlur={handleSave}
              onKeyPress={(e) => e.key === 'Enter' && handleSave()}
              autoFocus
              placeholder="输入图片URL..."
            />
            {/* 移除重复的保存按钮，避免重复触发handleSave */}
          </div>
        ) : content ? (
          <img 
            src={content} 
            alt="用户上传的图片"
            className="image-display"
            onClick={() => setIsEditing(true)}
          />
        ) : (
          <div 
            className="image-placeholder"
            onClick={() => setIsEditing(true)}
          >
            <span>点击添加图片URL</span>
          </div>
        );
      }
    } else {
      // 处理其他类型的块或默认情况
      return (
        <div>
          <p>未知块类型</p>
          <pre>{JSON.stringify(block, null, 2)}</pre>
        </div>
      );
    }
  };

  // 获取块类型显示名称
  const getBlockTypeDisplayName = () => {
    if (isDocBlock(block)) return '文档';
    if (isTextBlock(block)) return '文本';
    if (isMediaBlock(block)) return '媒体';
    if (isCodeBlock(block)) return '代码';
    return '未知';
  };

  return (
    <div className={`block-editor block-${getBlockTypeDisplayName().toLowerCase()}`}>
      <div className="block-header">
        <span className="block-type">{getBlockTypeDisplayName()}</span>
        <div className="block-actions">
          <button onClick={() => setIsEditing(!isEditing)}>
            {isEditing ? '保存' : '编辑'}
          </button>
          <button onClick={handleDelete} className="delete-btn">
            删除
          </button>
        </div>
      </div>
      <div className="block-content">
        {renderBlockContent()}
      </div>
    </div>
  );
}