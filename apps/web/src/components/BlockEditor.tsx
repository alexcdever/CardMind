// 块编辑器组件 - 使用统一块类型以保持兼容性
import React, { useState } from 'react';
import { useDocuments } from '../contexts/DocumentContext';
import { AnyBlock, BlockType } from '@cardmind/types';
import './BlockEditor.css';

interface BlockEditorProps {
  block: AnyBlock;
  onSave: (block: AnyBlock) => void;
  onCancel: () => void;
}

export default function BlockEditor({ block }: BlockEditorProps) {
  const { state, updateBlock, deleteBlock } = useDocuments();
  const { currentDocument } = state;
  const [isEditing, setIsEditing] = useState(false);
  
  // 根据块类型初始化内容
  const [content, setContent] = useState(() => {
    switch (block.type) {
      case BlockType.DOC:
        return block.properties.content || '';
      case BlockType.TEXT:
        return block.properties.content || '';
      case BlockType.CODE:
        return block.properties.code || '';
      case BlockType.MEDIA:
        return block.properties.filePath || '';
      default:
        return '';
    }
  });

  // 为DocBlock单独处理标题
  const [title, setTitle] = useState(() => {
    return block.type === BlockType.DOC ? (block.properties.title || '') : '';
  });

  const handleSave = async () => {
    // 获取当前内容值
    let currentContent = '';
    let hasChanges = false;
    
    switch (block.type) {
      case BlockType.DOC:
        currentContent = block.properties.content || '';
        hasChanges = content !== currentContent || title !== (block.properties.title || '');
        break;
      case BlockType.TEXT:
        currentContent = block.properties.content || '';
        hasChanges = content !== currentContent;
        break;
      case BlockType.CODE:
        currentContent = block.properties.code || '';
        hasChanges = content !== currentContent;
        break;
      case BlockType.MEDIA:
        currentContent = block.properties.filePath || '';
        hasChanges = content !== currentContent;
        break;
    }

    if (hasChanges) {
      // 创建更新后的块
      const updatedBlock: AnyBlock = {
        ...block,
        properties: {
          ...block.properties,
          content: block.type === BlockType.DOC || block.type === BlockType.TEXT ? content : block.properties.content,
          title: block.type === BlockType.DOC ? title : block.properties.title,
          code: block.type === BlockType.CODE ? content : block.properties.code,
          filePath: block.type === BlockType.MEDIA ? content : block.properties.filePath,
          language: block.type === BlockType.CODE ? language : block.properties.language,
          fileName: block.type === BlockType.MEDIA ? fileName : block.properties.fileName
        },
        modifiedAt: new Date()
      };
      
      await updateBlock(updatedBlock);
    }
    setIsEditing(false);
  };

  const handleDelete = async () => {
    if (window.confirm('确定要删除这个块吗？')) {
      // 需要从上下文获取当前文档ID
      if (currentDocument) {
        await deleteBlock(currentDocument.id, block.id);
      }
    }
  };

  // 所有块类型共享的状态
  const [language, setLanguage] = useState(() => 
    block.type === BlockType.CODE ? (block.properties.language || 'javascript') : ''
  );
  const [fileName, setFileName] = useState(() => 
    block.type === BlockType.MEDIA ? (block.properties.fileName || '') : ''
  );

  const renderDocBlock = () => (
    isEditing ? (
      <div>
        <input
          type="text"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          onBlur={handleSave}
          onKeyPress={(e) => e.key === 'Enter' && handleSave()}
          autoFocus
          className="title-editor"
          placeholder="输入标题..."
        />
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          onBlur={handleSave}
          onKeyPress={(e) => e.key === 'Enter' && e.shiftKey === false && handleSave()}
          className="content-editor"
          placeholder="输入文档内容..."
        />
      </div>
    ) : (
      <div>
        <h3>{title}</h3>
        <div 
          className="content-display"
          onClick={() => setIsEditing(true)}
          dangerouslySetInnerHTML={{ __html: content.replace(/\n/g, '<br/>') || '<em>点击编辑内容</em>' }}
        />
      </div>
    )
  );

  const renderTextBlock = () => (
    isEditing ? (
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
    )
  );

  const renderCodeBlock = () => (
    isEditing ? (
      <div>
        <input
          type="text"
          value={language}
          onChange={(e) => setLanguage(e.target.value)}
          onBlur={handleSave}
          className="language-editor"
          placeholder="输入语言..."
        />
        <textarea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          onBlur={handleSave}
          onKeyPress={(e) => {
            if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
              e.preventDefault();
              handleSave();
            }
          }}
          autoFocus
          className="code-editor"
          placeholder="输入代码..."
        />
      </div>
    ) : (
      <div>
        <span className="code-language">{language}</span>
        <pre 
          className="code-display"
          onClick={() => setIsEditing(true)}
        >
          {content || <em>点击编辑代码</em>}
        </pre>
      </div>
    )
  );

  const renderMediaBlock = () => (
    isEditing ? (
      <div>
        <input
          type="text"
          value={content}
          onChange={(e) => setContent(e.target.value)}
          onBlur={handleSave}
          onKeyPress={(e) => e.key === 'Enter' && handleSave()}
          autoFocus
          className="file-path-editor"
          placeholder="输入文件路径..."
        />
        <input
          type="text"
          value={fileName}
          onChange={(e) => setFileName(e.target.value)}
          onBlur={handleSave}
          className="file-name-editor"
          placeholder="输入文件名..."
        />
      </div>
    ) : (
      <div>
        <div className="media-preview">
          {block.properties.thumbnailPath ? (
            <img src={block.properties.thumbnailPath} alt={fileName || '媒体文件'} />
          ) : (
            <div className="media-placeholder">
              <span>{fileName || '媒体文件'}</span>
            </div>
          )}
        </div>
        <p>文件路径: {content}</p>
      </div>
    )
  );

  const renderBlockContent = () => {
    switch (block.type) {
      case BlockType.DOC:
        return renderDocBlock();
      case BlockType.TEXT:
        return renderTextBlock();
      case BlockType.CODE:
        return renderCodeBlock();
      case BlockType.MEDIA:
        return renderMediaBlock();
      default:
        return null;
    }
  };

  return (
    <div className={`block-editor block-${block.type}`}>
      <div className="block-header">
        <span className="block-type">{block.type}</span>
        <div className="block-actions">
          <button onClick={() => setIsEditing(!isEditing)} className="btn btn-sm">
            {isEditing ? '保存' : '编辑'}
          </button>
          <button onClick={handleDelete} className="btn btn-sm btn-danger">
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