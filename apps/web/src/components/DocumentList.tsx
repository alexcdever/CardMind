// 文档列表组件
import React, { useState } from 'react';
import { useDocuments } from '../contexts/DocumentContext';
import { useSync } from '../contexts/SyncContext';
import './DocumentList.css';

export default function DocumentList() {
  const { state, createDocument, loadDocument, deleteDocument } = useDocuments();
  const { collaborators, isOnline } = useSync();
  const [newDocTitle, setNewDocTitle] = useState('');

  const handleCreateDocument = async () => {
    if (newDocTitle.trim()) {
      await createDocument(newDocTitle.trim());
      setNewDocTitle('');
    }
  };

  const handleSelectDocument = (id: string) => {
    loadDocument(id);
  };

  const handleDeleteDocument = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (window.confirm('确定要删除这个文档吗？')) {
      await deleteDocument(id);
    }
  };

  return (
    <div className="document-list">
      <div className="document-list-header">
        <h2>我的文档</h2>
        <div className="sync-status">
          <span className={`status-indicator ${isOnline ? 'online' : 'offline'}`}>
            {isOnline ? '在线' : '离线'}
          </span>
          {collaborators.length > 0 && (
            <span className="collaborators-count">
              {collaborators.length} 人在线
            </span>
          )}
        </div>
      </div>

      <div className="new-document">
        <input
          type="text"
          placeholder="新建文档..."
          value={newDocTitle}
          onChange={(e) => setNewDocTitle(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && handleCreateDocument()}
        />
        <button onClick={handleCreateDocument}>创建</button>
      </div>

      <div className="documents">
        {state.isLoading ? (
          <div className="loading">加载中...</div>
        ) : state.documents.length === 0 ? (
          <div className="empty">还没有文档，创建一个吧！</div>
        ) : (
          state.documents.map(doc => (
            <div
              key={doc.id}
              className={`document-item ${state.currentDocument?.id === doc.id ? 'active' : ''}`}
              onClick={() => handleSelectDocument(doc.id)}
            >
              <div className="document-info">
                <h3>{doc.title || '无标题'}</h3>
                <p>{doc.blocks.length} 个块</p>
                <time>{new Date(doc.updatedAt).toLocaleDateString()}</time>
              </div>
              <button
                className="delete-btn"
                onClick={(e) => handleDeleteDocument(doc.id, e)}
              >
                删除
              </button>
            </div>
          ))
        )}
      </div>
    </div>
  );
}