// 使用继承方式的块编辑器组件示例
import { useState } from 'react';
import { Block } from '../src/types/block-inheritance';
import { isDocBlock, isTextBlock, isMediaBlock, isCodeBlock } from '../src/types/block-inheritance';
import './BlockEditor.css';

interface BlockEditorProps {
  block: Block; // 使用新的Block基类类型
}

export default function BlockEditor({ block }: BlockEditorProps) {
  // 注意：在实际应用中，我们需要一个更新块的函数
  // 这里只是一个示例，所以使用一个空函数
  const updateBlock = async (updatedBlock: Block) => {
    console.log('更新块:', updatedBlock);
  };
  
  const [isEditing, setIsEditing] = useState(false);
  
  // 根据块类型初始化内容
  const [content, setContent] = useState(() => {
    if (isDocBlock(block)) {
      return block.content;
    } else if (isTextBlock(block)) {
      return block.content;
    } else if (isMediaBlock(block)) {
      return '';
    } else if (isCodeBlock(block)) {
      return block.code;
    }
    return '';
  });

  const handleSave = async () => {
    // 注意：在实际应用中，我们需要根据块类型创建更新后的块实例
    // 这里只是一个示例，所以直接输出日志
    console.log('保存块:', block.id, content);
    setIsEditing(false);
  };

  const handleDelete = async () => {
    if (window.confirm('确定要删除这个块吗？')) {
      console.log('删除块:', block.id);
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
          onKeyPress={(e) => e.key === 'Enter' && e.shiftKey === false && handleSave()}
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
              // 在实际应用中，我们需要更新块
              // updateBlock(new MediaBlock(block.id, block.parentId, block.filePath, block.fileHash, block.fileName, block.thumbnailPath));
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