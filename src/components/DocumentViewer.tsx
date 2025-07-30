import React from 'react';
import { Button } from 'antd';
import { BlockType } from '../types/block';
import { UnifiedBlock } from '../types/block';

interface Props {
  children?: React.ReactNode;
  onClose: () => void;
  style?: React.CSSProperties;
  currentBlock?: UnifiedBlock | null;
}

export const DocumentViewer: React.FC<Props> = ({ 
  children, 
  onClose, 
  style,
  currentBlock 
}) => {
  const blockId = currentBlock?.id || '';
  const handleClose = () => {
    onClose?.();
  };

  return (
    <div style={{ 
      padding: 24, 
      position: 'relative',
      height: '100%',
      display: 'flex',
      flexDirection: 'column',
      ...style 
    }}>
      {/* 返回按钮 - 始终显示 */}
      <Button
        type="text"
        style={{ position: 'absolute', right: 16, top: 16 }}
        onClick={handleClose}
      >
        返回
      </Button>

      {/* 标题区域 */}
      <div style={{ marginBottom: 16 }}>
        {currentBlock && currentBlock.id === blockId ? (
          <>
            <h2 style={{ marginTop: 0 }}>
              {currentBlock.type === BlockType.DOC
                ? (currentBlock.properties as any)?.title || '文档详情'
                : '文档详情'}
            </h2>
            <p>ID: {blockId}</p>
          </>
        ) : (
          <div style={{ padding: 24 }}>加载中...</div>
        )}
      </div>

      {/* 内容区域 - 添加滚动 */}
      <div style={{ 
        flex: 1,
        overflowY: 'auto',
        padding: '0 8px',
        margin: '0 -8px'
      }}>
        {children}
      </div>
    </div>
  );
};
