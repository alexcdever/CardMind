import { useBlockManager, BlockManagerState } from '../stores/blockManager';
import { DocumentViewer } from './DocumentViewer';
import React, { useEffect, useState, useRef, useCallback } from 'react';
import { Modal } from 'antd';
import { BlockContentRenderer } from './BlockContentRenderer';
import { 
  UnifiedBlock, 
  BlockType, 
  DocBlockProperties, 
  TextBlockProperties 
} from '../types/block';
import '../styles/block-list.css';
import { Button, Card, message, Typography, Space } from 'antd';
import { AppstoreOutlined, UnorderedListOutlined, MenuOutlined } from '@ant-design/icons';

// 布局类型
type LayoutType = 'grid' | 'list-single' | 'list-double';

// 使用React.memo优化性能
export const DocumentGallery: React.FC = () => {
  // 使用zustand状态（优化版）
  const currentBlock = useBlockManager(state => state.currentBlock);
  const isOpening = useBlockManager(state => state.isOpening);
  const getAllBlocks = useBlockManager(state => state.getAllBlocks);
  const setCurrentBlock = useBlockManager(state => state.setCurrentBlock);
  const deleteBlock = useBlockManager(state => state.deleteBlock);
  const getCurrentBlock = useBlockManager(state => state.getCurrentBlock);

  const [viewerState, setViewerState] = useState<{
    blockId: string | null;
    visible: boolean;
  }>({ blockId: null, visible: false });

  const [blocks, setBlocks] = useState<UnifiedBlock[]>([]);
  const [loading, setLoading] = useState(false);
  const [layout, setLayout] = useState<LayoutType>('grid');
  const lastBlockIdRef = useRef<string | null>(null);

  // 直接处理文档打开
  const handleOpenDocument = useCallback(async (blockId: string) => {
    if (blockId !== lastBlockIdRef.current) {
      lastBlockIdRef.current = blockId;
      await setCurrentBlock(blockId);
    }
  }, [setCurrentBlock]);

  // 直接处理文档关闭
  const handleCloseDocument = useCallback(async () => {
    if (lastBlockIdRef.current) {
      await setCurrentBlock(null);
      lastBlockIdRef.current = null;
    }
  }, [setCurrentBlock]);

  // 处理打开弹窗
  const handleModalOpen = useCallback(async (blockId: string) => {
    if (viewerState.blockId === blockId && viewerState.visible) {
      return;
    }
    await handleOpenDocument(blockId);
    setViewerState({ blockId, visible: true });
  }, [viewerState, handleOpenDocument]);

  // 加载块数据
  const loadBlocks = useCallback(async () => {
    const loadedBlocks = await getAllBlocks();
    setBlocks(loadedBlocks);
  }, [getAllBlocks]);

  useEffect(() => {
    loadBlocks();
  }, [loadBlocks]);

  // 渲染卡片内容
  // 处理删除文档
  const handleDelete = useCallback(async (blockId: string) => {
      Modal.confirm({
        title: '确认删除',
        content: '确定要删除这个文档吗？',
        okText: '确认',
        cancelText: '取消',
      onOk: async () => {
        try {
          await deleteBlock(blockId);
          message.success('删除成功');
          const updatedBlocks = await getAllBlocks();
          setBlocks(updatedBlocks);
        } catch (error) {
          message.error('删除失败');
        }
      }
    });
  }, [deleteBlock, getAllBlocks, setBlocks]);

  // 处理编辑文档
  const handleEdit = useCallback((blockId: string) => {
    setViewerState({ blockId, visible: true });
  }, []);

  // 定义关闭回调
  const handleClose = useCallback(async () => {
    await handleCloseDocument();
    setViewerState({ blockId: null, visible: false });
  }, [handleCloseDocument]);

  const renderCardContent = useCallback((block: UnifiedBlock) => {
    // 安全访问属性
    const title = block.type === BlockType.DOC 
      ? (block.properties as DocBlockProperties)?.title || '无标题'
      : block.type === BlockType.TEXT
      ? (block.properties as TextBlockProperties)?.content?.substring(0, 30) || '无标题'
      : '无标题';
      
    const contentPreview = block.type === BlockType.DOC
      ? (block.properties as DocBlockProperties)?.content?.substring(0, 100) || '无内容'
      : block.type === BlockType.TEXT
      ? (block.properties as TextBlockProperties)?.content?.substring(0, 100) || '无内容'
      : '无内容';
      
    const previewText = contentPreview.length > 100 
      ? `${contentPreview.substring(0, 100)}...` 
      : contentPreview;
    
    return (
      <div>
        <Typography.Title level={4} style={{ marginBottom: 8 }}>{title}</Typography.Title>
        <Typography.Paragraph 
          ellipsis={{ rows: 3 }} 
          style={{ color: '#666', marginBottom: 8 }}
        >
          {previewText}
        </Typography.Paragraph>
        <Typography.Text type="secondary" style={{ fontSize: 12 }}>
          <Space size={16}>
            <span>创建: {new Date(block.createdAt).toLocaleString()}</span>
            <span>修改: {new Date(block.modifiedAt).toLocaleString()}</span>
          </Space>
        </Typography.Text>
        <div style={{ marginTop: 16, display: 'flex', justifyContent: 'flex-end' }}>
          <Button 
            type="text" 
            size="small" 
            onClick={(e) => {
              e.stopPropagation();
              handleEdit(block.id);
            }}
            style={{ marginRight: 8 }}
          >
            编辑
          </Button>
          <Button 
            type="text" 
            size="small" 
            danger
            onClick={(e) => {
              e.stopPropagation();
              handleDelete(block.id);
            }}
          >
            删除
          </Button>
        </div>
      </div>
    );
  }, [handleEdit, handleDelete]);

  return (
    <div className={`block-list ${layout}`}>
      <div className="layout-controls">
        <Button 
          type={layout === 'grid' ? 'primary' : 'default'}
          icon={<AppstoreOutlined />}
          onClick={() => setLayout('grid')}
        >
          平铺
        </Button>
        <Button 
          type={layout === 'list-single' ? 'primary' : 'default'}
          icon={<MenuOutlined />}
          onClick={() => setLayout('list-single')}
        >
          单列
        </Button>
        <Button 
          type={layout === 'list-double' ? 'primary' : 'default'}
          icon={<UnorderedListOutlined />}
          onClick={() => setLayout('list-double')}
        >
          双列
        </Button>
      </div>

      <div className="blocks-container">
        {blocks.map(block => (
          <Card 
            key={block.id} 
            className="block-card" 
            hoverable
            onClick={() => handleModalOpen(block.id)}  // 使用防抖处理打开弹窗
          >
            {renderCardContent(block)}
          </Card>
        ))}
      </div>

      {/* 文档详情弹窗 - 使用DocumentViewer组件 */}
      <Modal
        title={null}
        width={800}
        centered
        open={!!viewerState.blockId && viewerState.visible}
        onCancel={handleClose}
        footer={null}
        closable={false}
        maskClosable={false}
        keyboard={false}
        destroyOnClose
        styles={{
          content: {
            top: '10%',
            padding: 0,
            borderRadius: 8,
            overflow: 'hidden',
            maxHeight: '80vh',
            boxShadow: '0 3px 6px -4px rgba(0, 0, 0, 0.12), 0 6px 16px 0 rgba(0, 0, 0, 0.08)'
          },
          body: {
            padding: 0,
            height: '100%',
            display: 'flex',
            flexDirection: 'column'
          }
        }}
      >
        {viewerState.blockId && (
          <DocumentViewer
            key={viewerState.blockId}
            onClose={handleClose}
            currentBlock={currentBlock}
          >
            {currentBlock?.id === viewerState.blockId ? (
              <BlockContentRenderer key={`renderer-${viewerState.blockId}`} block={currentBlock} />
            ) : (
              <div style={{ 
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                height: '100%'
              }}>
                <div>
                  <div style={{ textAlign: 'center', marginBottom: 16 }}>
                    {isOpening ? '正在加载文档...' : '准备渲染文档...'}
                  </div>
                  <div style={{ textAlign: 'center' }}>文档ID: {viewerState.blockId}</div>
                </div>
              </div>
            )}
          </DocumentViewer>
        )}
      </Modal>
    </div>
  );
};
