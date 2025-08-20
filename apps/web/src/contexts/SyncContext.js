import { jsx as _jsx } from "react/jsx-runtime";
// 同步上下文 - 管理实时协作
import { createContext, useContext, useEffect, useState } from 'react';
import { yjsManager } from '@cardmind/shared';
import { useDocuments } from './DocumentContext';
const SyncContext = createContext(null);
export function SyncProvider({ children }) {
    const [isOnline, setIsOnline] = useState(false);
    const [collaborators, setCollaborators] = useState([]);
    const [syncStatus, setSyncStatus] = useState({ isOnline: false, pendingChanges: 0 });
    const { state } = useDocuments();
    // 更新协作状态
    const updateCollaborators = (newCollaborators) => {
        setCollaborators(newCollaborators);
    };
    // 连接到文档进行协作
    const connectToDocument = (documentId) => {
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
    const disconnectFromDocument = (documentId) => {
        yjsManager.disconnect(documentId);
        setCollaborators([]);
        setIsOnline(false);
    };
    // 设置用户存在状态
    const setUserPresence = (user, cursor) => {
        if (state.currentDocument) {
            yjsManager.setUserPresence(state.currentDocument.id, user, cursor);
        }
    };
    // 当当前文档变化时自动连接
    useEffect(() => {
        if (state.currentDocument) {
            const cleanup = connectToDocument(state.currentDocument.id);
            return cleanup;
        }
        else {
            // 如果没有当前文档，断开所有连接
            collaborators.forEach(collab => {
                if (state.currentDocument) {
                    yjsManager.disconnect(state.currentDocument.id);
                }
            });
            setCollaborators([]);
            setIsOnline(false);
        }
    }, [state.currentDocument]);
    const value = {
        isOnline,
        collaborators,
        syncStatus,
        connectToDocument,
        disconnectFromDocument,
        setUserPresence
    };
    return (_jsx(SyncContext.Provider, { value: value, children: children }));
}
export function useSync() {
    const context = useContext(SyncContext);
    if (!context) {
        throw new Error('useSync must be used within a SyncProvider');
    }
    return context;
}
//# sourceMappingURL=SyncContext.js.map