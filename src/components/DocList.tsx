import React, { useState, useCallback } from 'react';
import { useBlockManager } from '../stores/blockManager';
import { UnifiedBlock, BlockType, DocBlockProperties, TextBlockProperties } from '../types/block';
import { Card, Button, Modal, Input, Typography, Space, message } from 'antd';
import { AppstoreOutlined, MenuOutlined, UnorderedListOutlined } from '@ant-design/icons';
import { DocEditor } from './DocEditor';
import { DocDetail } from './DocDetail';

const { Title, Paragraph, Text } = Typography;

interface EditState {
  visible: boolean;
  block: UnifiedBlock | null;
}

interface ViewerState {
  blockId: string | null;
  visible: boolean;
}

export const DocList: React.FC = () => {
  const { blocks, updateBlock, deleteBlock, setCurrentBlock } = useBlockManager();
  
  const [layout, setLayout] = useState<'grid' | 'list-single' | 'list-double'>('grid');
  const [editState, setEditState] = useState<EditState>({ visible: false, block: null });
  const [viewerState, setViewerState] = useState<ViewerState>({ blockId: null, visible: false });
  const [editTitle, setEditTitle] = useState('');
  const [editContent, setEditContent] = useState('');

  const handleEdit = useCallback((id: string) => {
    const block = blocks.find(b => b.id === id);
    if (block) {
      setEditState({ visible: true, block });
      setEditTitle((block.properties as DocBlockProperties)?.title || '');
      setEditContent((block.properties as DocBlockProperties)?.content || '');
    }
  }, [blocks]);

  const handleEditComplete = useCallback(() => {
    setEditState({ visible: false, block: null });
    setEditTitle('');
    setEditContent('');
  }, []);

  const handleDelete = useCallback(async (id: string) => {
    try {
      await deleteBlock(id);
      message.success('文档删除成功');
    } catch (error) {
      console.error('删除失败:', error);
      message.error('文档删除失败');
    }
  }, [deleteBlock]);

  const handleModalOpen = useCallback(async (blockId: string) => {
    try {
      await setCurrentBlock(blockId);
      setViewerState({ blockId, visible: true });
    } catch (error) {
      console.error('打开文档失败:', error);
    }
  }, [setCurrentBlock]);

  const handleCloseDocument = useCallback(async () => {
    await setCurrentBlock(null);
    setViewerState({ blockId: null, visible: false });
  }, [setCurrentBlock]);

  const handleEditSubmit = useCallback(async () => {
    if (!editState.block) return;
    
    try {
      await setCurrentBlock(editState.block.id);
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
  }, [editState.block, editTitle, editContent, setCurrentBlock, updateBlock, handleEditComplete]);

  const renderCardContent = useCallback((block: UnifiedBlock) => {
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
        <Title level={4} style={{ marginBottom: 8 }}>{title}</Title>
        <Paragraph
          ellipsis={{ rows: 3 }}
          style={{ color: '#666', marginBottom: 8 }}
        >
          {previewText}
        </Paragraph>
        <Text type="secondary" style={{ fontSize: 12 }}>
          <Space size={16}>
            <span>创建: {new Date(block.createdAt).toLocaleString()}</span>
            <span>修改: {new Date(block.modifiedAt).toLocaleString()}</span>
          </Space>
        </Text>
        <div style={{ marginTop: 16, display: 'flex', justifyContent: 'flex-end' }}>
          <Button
            type="text"
            size="small"
            onClick={(e: React.MouseEvent) => {
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
            onClick={(e: React.MouseEvent) => {
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
        {blocks.map((block: UnifiedBlock) => (
          <Card
            key={block.id}
            className="block-card"
            hoverable
            onClick={() => handleModalOpen(block.id)}
          >
            {renderCardContent(block)}
          </Card>
        ))}
      </div>

      <DocEditor />

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
          onChange={(e: React.ChangeEvent<HTMLInputElement>) => setEditTitle(e.target.value)}
          placeholder="文档标题"
          style={{ marginBottom: 16 }}
        />
        <Input.TextArea
          value={editContent}
          onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setEditContent(e.target.value)}
          placeholder="文档内容"
          rows={10}
        />
      </Modal>

      <Modal
        title={null}
        width={800}
        centered
        open={!!viewerState.blockId && viewerState.visible}
        onCancel={handleCloseDocument}
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
            height: '70vh',
            boxShadow: '0 3px 6px -4px rgba(0, 0, 0, 0.12), 0 6px 16px 0 rgba(0, 0, 0, 0.08)'
          },
          body: {
            padding: 0,
            height: '100%',
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden'
          }
        }}
      >
        {viewerState.blockId && (
          <DocDetail
            key={viewerState.blockId}
            onClose={handleCloseDocument}
          />
        )}
      </Modal>
    </div>
  );
};
