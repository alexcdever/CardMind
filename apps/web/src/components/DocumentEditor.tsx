// 文档编辑器组件
import React, { useState, useEffect } from 'react';
import { useDocuments } from '../contexts/DocumentContext';
import { useSync } from '../contexts/SyncContext';
import BlockEditor from './BlockEditor';
import CollaboratorCursors from './CollaboratorCursors';
import './DocumentEditor.css';

export default function DocumentEditor() {
  const { state, updateDocument, addBlock } = useDocuments();
  const { collaborators, setUserPresence } = useSync();
  const [title, setTitle] = useState('');
  const [editingTitle, setEditingTitle] = useState(false);

  // 当前用户信息
  const currentUser = {
    id: 'user-' + Math.random().toString(36).substr(2, 9),
    name: '我',
    color: '#1890ff'
  };

  // 同步标题
  useEffect(() => {
    if (state.currentDocument) {
      setTitle(state.currentDocument.title);
    } else {
      setTitle('');
    }
  }, [state.currentDocument]);

  // 处理标题更新
  const handleTitleChange = async (newTitle: string) => {
    if (state.currentDocument && newTitle !== state.currentDocument.title) {
      await updateDocument(state.currentDocument.id, { title: newTitle });
    }
  };

  // 处理标题失焦
  const handleTitleBlur = () => {
    setEditingTitle(false);
    handleTitleChange(title);
  };

  // 添加新块
  const handleAddBlock = (type: string) => {
    if (state.currentDocument) {
      addBlock({
        type: type as any,
        content: '',
        position: { x: 0, y: 0 }
      });
    }
  };

  // 处理鼠标移动更新光标位置
  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (state.currentDocument) {
      const rect = e.currentTarget.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      setUserPresence(currentUser, { x, y });
    }
  };

  if (!state.currentDocument) {
    return (
      <div className="document-editor">
        <div className="empty-editor">
          <h2>选择一个文档开始编辑</h2>
          <p>或者创建一个新文档</p>
        </div>
      </div>
    );
  }

  return (
    <div 
      className="document-editor"
      onMouseMove={handleMouseMove}
    >
      <div className="editor-header">
        <div className="document-title">
          {editingTitle ? (
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              onBlur={handleTitleBlur}
              onKeyPress={(e) => e.key === 'Enter' && handleTitleBlur()}
              autoFocus
            />
          ) : (
            <h1 onClick={() => setEditingTitle(true)}>{title || '无标题文档'}</h1>
          )}
        </div>
        
        <div className="collaborators">
          <CollaboratorCursors collaborators={collaborators} />
        </div>
      </div>

      <div className="editor-content">
        <div className="blocks">
          {state.currentDocument.blocks.map((block, index) => (
            <BlockEditor
              key={block.id}
              block={block}
              index={index}
            />
          ))}
        </div>

        <div className="add-block">
          <button onClick={() => handleAddBlock('text')}>+ 文本</button>
          <button onClick={() => handleAddBlock('image')}>+ 图片</button>
          <button onClick={() => handleAddBlock('code')}>+ 代码</button>
          <button onClick={() => handleAddBlock('todo')}>+ 待办</button>
        </div>
      </div>
    </div>
  );
}