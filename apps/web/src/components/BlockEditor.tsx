// 块编辑器组件
import { useState } from 'react';
import { useDocuments } from '../contexts/DocumentContext';
import type { Block } from '@cardmind/types';
import './BlockEditor.css';

interface BlockEditorProps {
  block: Block;
  index: number;
}

export default function BlockEditor({ block }: BlockEditorProps) {
  const { updateBlock, deleteBlock } = useDocuments();
  const [isEditing, setIsEditing] = useState(false);
  const [content, setContent] = useState(block.content);

  const handleSave = async () => {
    if (content !== block.content) {
      await updateBlock({
        ...block,
        content
      });
    }
    setIsEditing(false);
  };

  const handleDelete = async () => {
    if (window.confirm('确定要删除这个块吗？')) {
      await deleteBlock(block.id, block.id);
    }
  };

  const renderBlockContent = () => {
    switch (block.type) {
      case 'text':
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

      case 'code':
        return isEditing ? (
          <textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            onBlur={handleSave}
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

      case 'todo':
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
                updateBlock({ ...block, content: newContent });
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

      case 'image':
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
            <button onClick={handleSave}>保存</button>
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

      default:
        return null;
    }
  };

  return (
    <div className={`block-editor block-${block.type}`}>
      <div className="block-header">
        <span className="block-type">{block.type}</span>
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