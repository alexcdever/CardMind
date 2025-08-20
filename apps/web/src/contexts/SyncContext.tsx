// 同步上下文 - 管理实时协作
import React, { createContext, useContext, useEffect, useState } from 'react';
import { yjsManager } from '@cardmind/shared';
import type { Collaborator, SyncStatus } from '@cardmind/types';
import { useDocuments } from './DocumentContext';

interface SyncContextType {
  isOnline: boolean;
  collaborators: Collaborator[];
  syncStatus: SyncStatus;
  connectToDocument: (documentId: string) => void;
  disconnectFromDocument: (documentId: string) => void;
  setUserPresence: (user: { id: string; name: string; color: string }, cursor?: { x: number; y: number }) => void;
}

const SyncContext = createContext<SyncContextType | null>(null);

export function SyncProvider({ children }: { children: React.ReactNode }) {
  const [isOnline, setIsOnline] = useState(false);
  const [collaborators, setCollaborators] = useState<Collaborator[]>([]);
  const [syncStatus, setSyncStatus] = useState<SyncStatus>({ isOnline: false, pendingChanges: 0 });
  const { state } = useDocuments();

  // 更新协作状态
  const updateCollaborators = (newCollaborators: Collaborator[]) => {
    setCollaborators(newCollaborators);
  };

  // 连接到文档进行协作
  const connectToDocument = (documentId: string) => {
    yjsManager.connect(documentId, updateCollaborators);
    
    // 设置在线状态
    const interval = setInterval(() => {
      const status = yjsManager.getSyncStatus();
      setSyncStatus(status);
      setIsOnline(status.isOnline);
    }, 1000);

    return () => clearInterval(interval);
  };

  // 断开文档连接
  const disconnectFromDocument = (documentId: string) => {
    yjsManager.disconnect(documentId);
    setCollaborators([]);
    setIsOnline(false);
  };

  // 设置用户存在状态
  const setUserPresence = (user: { id: string; name: string; color: string }, cursor?: { x: number; y: number }) => {
    if (state.currentDocument) {
      yjsManager.setUserPresence(state.currentDocument.id, user, cursor);
    }
  };

  // 当当前文档变化时自动连接
  useEffect(() => {
    if (state.currentDocument) {
      const cleanup = connectToDocument(state.currentDocument.id);
      return cleanup;
    } else {
      // 如果没有当前文档，断开所有连接
      collaborators.forEach(() => {
        if (state.currentDocument) {
          yjsManager.disconnect(state.currentDocument.id);
        }
      });
      setCollaborators([]);
      setIsOnline(false);
    }
  }, [state.currentDocument]);

  const value: SyncContextType = {
    isOnline,
    collaborators,
    syncStatus,
    connectToDocument,
    disconnectFromDocument,
    setUserPresence
  };

  return (
    <SyncContext.Provider value={value}>
      {children}
    </SyncContext.Provider>
  );
}

export function useSync() {
  const context = useContext(SyncContext);
  if (!context) {
    throw new Error('useSync must be used within a SyncProvider');
  }
  return context;
}