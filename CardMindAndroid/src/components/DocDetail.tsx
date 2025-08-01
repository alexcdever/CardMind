import React from 'react';
import { Button, Typography, Spin } from 'antd';
import { useBlockManager } from '../stores/blockManager';
import { BlockType } from '../types/block';
import { UnifiedBlock } from '../types/block';

interface Props {
  children?: React.ReactNode;
  onClose: () => void;
  style?: React.CSSProperties;
  // currentBlock 现在从Zustand获取，不再需要作为prop传入
}

const { Title, Text, Paragraph } = Typography;

export const DocDetail: React.FC<Props> = ({ 
  children, 
  onClose, 
  style
}) => {
  // 从Zustand store获取当前块数据和加载状态
  const currentBlock = useBlockManager(state => state.currentBlock);
  const isOpening = useBlockManager(state => state.isOpening);
  const setCurrentBlock = useBlockManager(state => state.setCurrentBlock);
  
  const handleClose = () => {
    // 使用Zustand清理当前块状态
    setCurrentBlock(null);
    onClose?.();
  };

  // 渲染文档内容 - 仅用于标题区域
  const renderDocumentContent = () => {
    if (!currentBlock) {
      return <div style={{ textAlign: 'center', padding: 48 }}>文档不存在或已删除</div>;
    }

    return (
      <>
        <Title level={2} style={{ marginTop: 0, marginBottom: 8 }}>
          {(currentBlock.properties as any)?.title || '无标题文档'}
        </Title>
        <Text type="secondary" style={{ fontSize: 14 }}>
          文档ID: {currentBlock.id}
        </Text>
        <br />
        <Text type="secondary" style={{ fontSize: 12 }}>
          创建时间: {new Date(currentBlock.createdAt).toLocaleString()}
        </Text>
        <br />
        <Text type="secondary" style={{ fontSize: 12 }}>
          修改时间: {new Date(currentBlock.modifiedAt).toLocaleString()}
        </Text>
      </>
    );
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
      {/* 添加内联样式来美化滚动条 */}
      <style>{`
        .doc-detail-content::-webkit-scrollbar {
          width: 8px;
        }
        .doc-detail-content::-webkit-scrollbar-track {
          background: #f0f0f0;
          border-radius: 4px;
        }
        .doc-detail-content::-webkit-scrollbar-thumb {
          background: #bfbfbf;
          border-radius: 4px;
        }
        .doc-detail-content::-webkit-scrollbar-thumb:hover {
          background: #999;
        }
      `}</style>
      {/* 返回按钮 - 始终显示 */}
      <Button
        type="text"
        style={{ position: 'absolute', right: 16, top: 16, zIndex: 10 }}
        onClick={handleClose}
      >
        返回
      </Button>

      {/* 标题区域 - 固定不滚动 */}
      <div style={{
        padding: '24px 24px 16px',
        borderBottom: '1px solid #f0f0f0',
        backgroundColor: '#fff',
        zIndex: 5,
        flexShrink: 0
      }}>
        {currentBlock && (
          <>
            <Title level={2} style={{ marginTop: 0, marginBottom: 8 }}>
              {(currentBlock.properties as any)?.title || '无标题文档'}
            </Title>
            <Text type="secondary" style={{ fontSize: 14 }}>
              文档ID: {currentBlock.id}
            </Text>
            <br />
            <Text type="secondary" style={{ fontSize: 12 }}>
              创建时间: {new Date(currentBlock.createdAt).toLocaleString()}
            </Text>
            <br />
            <Text type="secondary" style={{ fontSize: 12 }}>
              修改时间: {new Date(currentBlock.modifiedAt).toLocaleString()}
            </Text>
          </>
        )}
      </div>

      {/* 内容区域 - 独立滚动 */}
      <div style={{ 
        flex: 1,
        overflowY: 'auto',
        overflowX: 'hidden',
        padding: '24px',
        minHeight: 0
      }}>
        {isOpening ? (
          <div style={{ 
            display: 'flex', 
            justifyContent: 'center', 
            alignItems: 'center', 
            height: '100%' 
          }}>
            <Spin size="large" tip="正在加载文档..." />
          </div>
        ) : (
          currentBlock && (
            <Paragraph style={{ 
              whiteSpace: 'pre-wrap', 
              marginBottom: 0,
              wordBreak: 'break-word',
              overflowWrap: 'break-word'
            }}>
              {(currentBlock.properties as any)?.content || '暂无内容'}
            </Paragraph>
          )
        )}
        
        {/* 保留children插槽，用于扩展功能 */}
        {children}
      </div>
    </div>
  );
};
