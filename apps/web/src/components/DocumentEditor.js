import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
// 文档编辑器组件
import { useState, useEffect } from 'react';
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
        }
        else {
            setTitle('');
        }
    }, [state.currentDocument]);
    // 处理标题更新
    const handleTitleChange = async (newTitle) => {
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
    const handleAddBlock = (type) => {
        if (state.currentDocument) {
            addBlock({
                type: type,
                content: '',
                position: { x: 0, y: 0 }
            });
        }
    };
    // 处理鼠标移动更新光标位置
    const handleMouseMove = (e) => {
        if (state.currentDocument) {
            const rect = e.currentTarget.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            setUserPresence(currentUser, { x, y });
        }
    };
    if (!state.currentDocument) {
        return (_jsx("div", { className: "document-editor", children: _jsxs("div", { className: "empty-editor", children: [_jsx("h2", { children: "\u9009\u62E9\u4E00\u4E2A\u6587\u6863\u5F00\u59CB\u7F16\u8F91" }), _jsx("p", { children: "\u6216\u8005\u521B\u5EFA\u4E00\u4E2A\u65B0\u6587\u6863" })] }) }));
    }
    return (_jsxs("div", { className: "document-editor", onMouseMove: handleMouseMove, children: [_jsxs("div", { className: "editor-header", children: [_jsx("div", { className: "document-title", children: editingTitle ? (_jsx("input", { type: "text", value: title, onChange: (e) => setTitle(e.target.value), onBlur: handleTitleBlur, onKeyPress: (e) => e.key === 'Enter' && handleTitleBlur(), autoFocus: true })) : (_jsx("h1", { onClick: () => setEditingTitle(true), children: title || '无标题文档' })) }), _jsx("div", { className: "collaborators", children: _jsx(CollaboratorCursors, { collaborators: collaborators }) })] }), _jsxs("div", { className: "editor-content", children: [_jsx("div", { className: "blocks", children: state.currentDocument.blocks.map((block, index) => (_jsx(BlockEditor, { block: block, index: index }, block.id))) }), _jsxs("div", { className: "add-block", children: [_jsx("button", { onClick: () => handleAddBlock('text'), children: "+ \u6587\u672C" }), _jsx("button", { onClick: () => handleAddBlock('image'), children: "+ \u56FE\u7247" }), _jsx("button", { onClick: () => handleAddBlock('code'), children: "+ \u4EE3\u7801" }), _jsx("button", { onClick: () => handleAddBlock('todo'), children: "+ \u5F85\u529E" })] })] })] }));
}
//# sourceMappingURL=DocumentEditor.js.map