import { useBlockManager } from '../stores/blockManager';
import { DocDetail } from './DocDetail';
import { DocEditor } from './DocEditor';
import React, { useEffect, useState, useRef, useCallback } from 'react';
import { Modal, Input } from 'antd';

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
export const DocList: React.FC = () => {
  // 使用zustand状态统一管理（完全统一版）
  const currentBlock = useBlockManager(state => state.currentBlock);
  const isOpening = useBlockManager(state => state.isOpening);
  const blocks = useBlockManager(state => state.blocks);
  const { getAllBlocks, setCurrentBlock, deleteBlock, updateBlock } = useBlockManager();

  const [viewerState, setViewerState] = useState<{
    blockId: string | null;
    visible: boolean;
  }>({ blockId: null, visible: false });

  // 编辑状态（本地临时状态，合理）
  const [editState, setEditState] = useState<{
    block: UnifiedBlock | null;
    visible: boolean;
  }>({ block: null, visible: false });
  const [editTitle, setEditTitle] = useState('');
  const [editContent, setEditContent] = useState('');
  
  // blocks现在直接从Zustand store获取，无需本地state
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

  // 加载块数据 - 现在由Zustand自动管理，无需手动设置
  useEffect(() => {
    getAllBlocks();
  }, [getAllBlocks]);

  // 渲染卡片内容
  // 处理删除文档 - Zustand自动刷新blocks数组
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
          // 无需手动刷新，Zustand会自动更新blocks数组
        } catch (error) {
          message.error('删除失败');
        }
      }
    });
  }, [deleteBlock]);

  // 处理编辑文档
  const handleEdit = useCallback(async (blockId: string) => {
    const block = blocks.find(b => b.id === blockId);
    if (block) {
      const docProps = block.properties as DocBlockProperties;
      setEditTitle(docProps.title || '');
      setEditContent(docProps.content || '');
      setEditState({ block, visible: true });
    }
  }, [blocks]);

  // 处理编辑完成 - Zustand自动刷新blocks数组
  const handleEditComplete = useCallback(() => {
    setEditState({ block: null, visible: false });
    setEditTitle('');
    setEditContent('');
    // 无需手动刷新，Zustand会自动更新blocks数组
  }, []);

  // 处理编辑提交
  const handleEditSubmit = async () => {
    if (!editState.block) return;
    
    try {
      // 先设置当前块，确保可以更新
      await setCurrentBlock(editState.block.id);
      
      // 然后更新块数据
      await updateBlock({
        ...editState.block,
        properties: {
          ...editState.block.properties,
          title: editTitle || '未命名文档',
          content: editContent
        },
        modifiedAt: new Date()
      });
      
      message.success('文档更新成功');
      handleEditComplete();
    } catch (error) {
      console.error('编辑失败:', error);
      message.error('文档更新失败');
    }
  };

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

      {/* 文档创建器 - Zustand自动刷新blocks数组，无需回调 */}
      <DocEditor />

      {/* 文档编辑器 - 直接使用Modal进行编辑 */}
      <Modal
        title="编辑文档"
        open={editState.visible}
        onOk={handleEditSubmit}
        onCancel={handleEditComplete}
        width={800}
        centered
        destroyOnClose
      >
        <Input
          value={editTitle}
          onChange={(e) => setEditTitle(e.target.value)}
          placeholder="文档标题"
          style={{ marginBottom: 16 }}
        />
        <Input.TextArea
          value={editContent}
          onChange={(e) => setEditContent(e.target.value)}
          placeholder="文档内容"
          rows={10}
        />
      </Modal>

      {/* 文档详情弹窗 - 使用DocDetail组件渲染完整内容 */}
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
            height: '70vh', // 添加固定高度确保滚动区域生效
            boxShadow: '0 3px 6px -4px rgba(0, 0, 0, 0.12), 0 6px 16px 0 rgba(0, 0, 0, 0.08)'
          },
          body: {
            padding: 0,
            height: '100%', // 确保body占满整个content区域
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden' // 防止内容溢出
          }
        }}
      >
        {viewerState.blockId && (
          <DocDetail
            key={viewerState.blockId}
            onClose={handleClose}
          />
        )}
      </Modal>
    </div>
  );
};
