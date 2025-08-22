import React, { useState, useCallback, useEffect } from 'react';
import { useDocuments } from '../contexts/DocumentContext';
import { useSync } from '../contexts/SyncContext';
import { AnyBlock, DocBlock } from '@cardmind/types';
import { Card, Button, Modal, Input, Typography, Space, message } from 'antd';
import { EditOutlined, DeleteOutlined, FileAddOutlined } from '@ant-design/icons';

const { Title, Paragraph } = Typography;

interface EditState {
  visible: boolean;
  block: AnyBlock | null;
}

export const DocumentList: React.FC = () => {
  const { state, createDocument, updateDocument, deleteDocument } = useDocuments();
  const blocks = state.documents || [];
  const { syncStatus } = useSync();
  
  const [editState, setEditState] = useState<EditState>({ visible: false, block: null });
  const [editTitle, setEditTitle] = useState('');
  const [editContent, setEditContent] = useState('');
  const [relayStatus, setRelayStatus] = useState<string>('');

  // 显示中继服务状态
  useEffect(() => {
    const checkRelayStatus = () => {
      try {
        // 从syncStatus获取中继状态
        if (syncStatus.isOnline) {
          setRelayStatus('中继服务: 已连接');
        } else {
          setRelayStatus('中继服务: 未连接');
        }
      } catch (error) {
        setRelayStatus('中继服务: 未配置');
      }
    };

    checkRelayStatus();
    // 监听设置变化
    const interval = setInterval(checkRelayStatus, 5000);
    return () => clearInterval(interval);
  }, [syncStatus]);

  const handleCreate = useCallback(async () => {
    await createDocument('新文档');
    message.success('文档创建成功');
  }, [createDocument]);

  const handleEdit = useCallback((block: AnyBlock) => {
    setEditState({ visible: true, block });
    if (block instanceof DocBlock) {
      setEditTitle(block.title || '');
      setEditContent(block.content || '');
    } else {
      setEditTitle('');
      setEditContent('');
    }
  }, []);

  const handleEditComplete = useCallback(async () => {
    if (!editState.block) return;
    
    try {
      if (editState.block instanceof DocBlock) {
        editState.block.title = editTitle;
        editState.block.content = editContent;
        editState.block.modifiedAt = new Date();
      }
      await updateDocument(editState.block.id, editState.block);
      message.success('文档更新成功');
      setEditState({ visible: false, block: null });
    } catch (error) {
      message.error('更新失败');
    }
  }, [editState.block, editTitle, editContent, updateDocument]);

  const handleDelete = useCallback(async (id: string) => {
    try {
      await deleteDocument(id);
      message.success('文档删除成功');
    } catch (error) {
      message.error('删除失败');
    }
  }, [deleteDocument]);

  return (
    <div className="document-list">
      <div className="list-header">
        <h3>文档列表</h3>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
          <Button type="primary" icon={<FileAddOutlined />} onClick={handleCreate}>
            新建文档
          </Button>
          <span style={{ fontSize: 12, color: '#666' }}>{relayStatus}</span>
        </div>
      </div>

      <div className="documents-container">
        {blocks.map((block: any) => (
          <Card
            key={block.id}
            className="document-card"
            title={
              <Title level={4} style={{ margin: 0 }}>
                {block.title || '无标题文档'}
              </Title>
            }
            extra={
              <Space>
                <Button
                  type="text"
                  icon={<EditOutlined />}
                  onClick={(e) => {
                    e.stopPropagation();
                    handleEdit(block);
                  }}
                />
                <Button
                  type="text"
                  icon={<DeleteOutlined />}
                  danger
                  onClick={(e) => {
                    e.stopPropagation();
                    handleDelete(block.id);
                  }}
                />
              </Space>
            }
          >
            <Paragraph
              ellipsis={{ rows: 3 }}
              style={{ color: '#666' }}
            >
              {block.content || '暂无内容'}
            </Paragraph>
            <div style={{ fontSize: 12, color: '#999' }}>
              创建: {new Date(block.createdAt).toLocaleString()}
            </div>
          </Card>
        ))}
      </div>

      <Modal
        title="编辑文档"
        open={editState.visible}
        onCancel={() => setEditState({ visible: false, block: null })}
        onOk={handleEditComplete}
        width={600}
      >
        <Space direction="vertical" style={{ width: '100%' }}>
          <Input
            placeholder="文档标题"
            value={editTitle}
            onChange={(e) => setEditTitle(e.target.value)}
          />
          <Input.TextArea
            placeholder="文档内容"
            value={editContent}
            onChange={(e) => setEditContent(e.target.value)}
            rows={10}
          />
        </Space>
      </Modal>
    </div>
  );
};