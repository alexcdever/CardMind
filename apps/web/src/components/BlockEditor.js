import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
// 块编辑器组件
import { useState } from 'react';
import { useDocuments } from '../contexts/DocumentContext';
import './BlockEditor.css';
export default function BlockEditor({ block, index }) {
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
                return isEditing ? (_jsx("textarea", { value: content, onChange: (e) => setContent(e.target.value), onBlur: handleSave, onKeyPress: (e) => e.key === 'Enter' && e.shiftKey === false && handleSave(), autoFocus: true, className: "text-editor", placeholder: "\u8F93\u5165\u6587\u672C..." })) : (_jsx("div", { className: "text-display", onClick: () => setIsEditing(true), dangerouslySetInnerHTML: { __html: content.replace(/\n/g, '<br/>') || '<em>点击编辑文本</em>' } }));
            case 'code':
                return isEditing ? (_jsx("textarea", { value: content, onChange: (e) => setContent(e.target.value), onBlur: handleSave, onKeyPress: (e) => {
                        // 对于代码块，只在Ctrl+Enter或Cmd+Enter时保存，允许换行输入
                        if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
                            e.preventDefault();
                            handleSave();
                        }
                    }, autoFocus: true, className: "code-editor", placeholder: "\u8F93\u5165\u4EE3\u7801..." })) : (_jsx("pre", { className: "code-display", onClick: () => setIsEditing(true), children: content || _jsx("em", { children: "\u70B9\u51FB\u7F16\u8F91\u4EE3\u7801" }) }));
            case 'todo':
                const isChecked = content.startsWith('[x] ');
                const todoText = content.replace(/^\[x\] |^\[ \] /, '');
                return (_jsxs("div", { className: "todo-block", children: [_jsx("input", { type: "checkbox", checked: isChecked, onChange: async (e) => {
                                const newContent = e.target.checked ? `[x] ${todoText}` : `[ ] ${todoText}`;
                                setContent(newContent);
                                await updateBlock({ ...block, content: newContent });
                            } }), isEditing ? (_jsx("input", { type: "text", value: todoText, onChange: (e) => setContent(`[${isChecked ? 'x' : ' '}] ${e.target.value}`), onBlur: handleSave, onKeyPress: (e) => e.key === 'Enter' && handleSave(), autoFocus: true, className: "todo-editor", placeholder: "\u8F93\u5165\u5F85\u529E\u4E8B\u9879..." })) : (_jsx("span", { className: `todo-text ${isChecked ? 'completed' : ''}`, onClick: () => setIsEditing(true), children: todoText || _jsx("em", { children: "\u70B9\u51FB\u7F16\u8F91\u5F85\u529E" }) }))] }));
            case 'image':
                return isEditing ? (_jsxs("div", { className: "image-editor", children: [_jsx("input", { type: "text", value: content, onChange: (e) => setContent(e.target.value), onBlur: handleSave, onKeyPress: (e) => e.key === 'Enter' && handleSave(), autoFocus: true, placeholder: "\u8F93\u5165\u56FE\u7247URL..." })] })) : content ? (_jsx("img", { src: content, alt: "\u7528\u6237\u4E0A\u4F20\u7684\u56FE\u7247", className: "image-display", onClick: () => setIsEditing(true) })) : (_jsx("div", { className: "image-placeholder", onClick: () => setIsEditing(true), children: _jsx("span", { children: "\u70B9\u51FB\u6DFB\u52A0\u56FE\u7247URL" }) }));
            default:
                return null;
        }
    };
    return (_jsxs("div", { className: `block-editor block-${block.type}`, children: [_jsxs("div", { className: "block-header", children: [_jsx("span", { className: "block-type", children: block.type }), _jsxs("div", { className: "block-actions", children: [_jsx("button", { onClick: () => setIsEditing(!isEditing), children: isEditing ? '保存' : '编辑' }), _jsx("button", { onClick: handleDelete, className: "delete-btn", children: "\u5220\u9664" })] })] }), _jsx("div", { className: "block-content", children: renderBlockContent() })] }));
}
//# sourceMappingURL=BlockEditor.js.map