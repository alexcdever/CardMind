import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
// 文档列表组件
import { useState } from 'react';
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
    const handleSelectDocument = (id) => {
        loadDocument(id);
    };
    const handleDeleteDocument = async (id, e) => {
        e.stopPropagation();
        if (window.confirm('确定要删除这个文档吗？')) {
            await deleteDocument(id);
        }
    };
    return (_jsxs("div", { className: "document-list", children: [_jsxs("div", { className: "document-list-header", children: [_jsx("h2", { children: "\u6211\u7684\u6587\u6863" }), _jsxs("div", { className: "sync-status", children: [_jsx("span", { className: `status-indicator ${isOnline ? 'online' : 'offline'}`, children: isOnline ? '在线' : '离线' }), collaborators.length > 0 && (_jsxs("span", { className: "collaborators-count", children: [collaborators.length, " \u4EBA\u5728\u7EBF"] }))] })] }), _jsxs("div", { className: "new-document", children: [_jsx("input", { type: "text", placeholder: "\u65B0\u5EFA\u6587\u6863...", value: newDocTitle, onChange: (e) => setNewDocTitle(e.target.value), onKeyPress: (e) => e.key === 'Enter' && handleCreateDocument() }), _jsx("button", { onClick: handleCreateDocument, children: "\u521B\u5EFA" })] }), _jsx("div", { className: "documents", children: state.isLoading ? (_jsx("div", { className: "loading", children: "\u52A0\u8F7D\u4E2D..." })) : state.documents.length === 0 ? (_jsx("div", { className: "empty", children: "\u8FD8\u6CA1\u6709\u6587\u6863\uFF0C\u521B\u5EFA\u4E00\u4E2A\u5427\uFF01" })) : (state.documents.map(doc => (_jsxs("div", { className: `document-item ${state.currentDocument?.id === doc.id ? 'active' : ''}`, onClick: () => handleSelectDocument(doc.id), children: [_jsxs("div", { className: "document-info", children: [_jsx("h3", { children: doc.title || '无标题' }), _jsxs("p", { children: [doc.blocks.length, " \u4E2A\u5757"] }), _jsx("time", { children: new Date(doc.updatedAt).toLocaleDateString() })] }), _jsx("button", { className: "delete-btn", onClick: (e) => handleDeleteDocument(doc.id, e), children: "\u5220\u9664" })] }, doc.id)))) })] }));
}
//# sourceMappingURL=DocumentList.js.map