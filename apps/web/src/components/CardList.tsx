import React, { useState, forwardRef, useImperativeHandle } from 'react';
import { Row, Col, Empty, Spin, Button } from 'antd';
import { PlusOutlined } from '@ant-design/icons';
import { AnyBlock, DocBlock, TextBlock } from '@cardmind/types';
import { useDocuments } from '../contexts/DocumentContext';
import CardView from './CardView';
import DocumentEditor from './DocumentEditor';

const CardList = forwardRef((_, ref) => {
  const { 
    state,
    createDocument, 
    updateDocument, 
    deleteDocument,
    loadDocuments
  } = useDocuments();
  
  const documents = state.documents;
  const loading = state.isLoading;
  
  // 修复剩余的UnifiedBlock引用
  const [selectedBlock, setSelectedBlock] = useState<AnyBlock | null>(null);
  
  // 获取所有文档块 - 使用AnyBlock
  const getAllBlocks = (): AnyBlock[] => {
    return documents.map((doc: any) => ({
      id: doc.id,
      type: 'doc',
      parentId: null,
      childrenIds: doc.blocks || [],
      title: doc.title,
      content: doc.blocks?.length ? `${doc.blocks.length} 个内容块` : '空文档',
      tags: doc.tags || [],
      createdAt: new Date(doc.createdAt),
      modifiedAt: new Date(doc.updatedAt),
      isDeleted: false
    }));
  };
  
  // 处理添加新卡片
  const handleAddCard = async () => {
    await createDocument('新笔记');
    
    // 重新加载文档列表以获取新创建的文档
    await loadDocuments();
    
    // 选择最新的文档作为新块
    const latestDoc = documents[documents.length - 1];
    if (latestDoc) {
      const newBlock = new DocBlock(
        latestDoc.id,
        null,
        latestDoc.title,
        ''
      );
      
      setSelectedBlock(newBlock);
      setIsModalVisible(true);
    }
  };
  
  // 处理编辑卡片
  const handleEditCard = (block: AnyBlock) => {
    setSelectedBlock(block);
    setIsModalVisible(true);
  };
  
  // 处理保存编辑
  const handleSaveEdit = async (block: AnyBlock) => {
    if (block instanceof DocBlock) {
      await updateDocument(block.id, {
        title: block.title || '无标题',
        tags: []
      });
    }
    setIsModalVisible(false);
    setSelectedBlock(null);
  };
  const [isModalVisible, setIsModalVisible] = useState(false);

  useImperativeHandle(ref, () => ({
    addNewCard: () => {
      handleAddCard();
    },
    getDocuments: () => documents,
    refresh: () => window.location.reload()
  }));

  const blocks: AnyBlock[] = documents.map((doc: any) => 
    new DocBlock(
      doc.id,
      null,
      doc.title,
      doc.blocks?.length ? `${doc.blocks.length} 个内容块` : '空文档'
    )
  );

  // 处理添加新卡片
  const handleAddCard = async () => {
    await createDocument('新笔记');
    
    // 重新加载文档列表以获取新创建的文档
    await loadDocuments();
    
    // 选择最新的文档作为新块
    const latestDoc = documents[documents.length - 1];
    if (latestDoc) {
      const newBlock: AnyBlock = {
        id: latestDoc.id,
        type: 'doc',
        parentId: null,
        childrenIds: [],
        title: latestDoc.title,
        content: '',
        tags: latestDoc.tags || [],
        createdAt: new Date(latestDoc.createdAt),
        modifiedAt: new Date(latestDoc.updatedAt),
        isDeleted: false
      };
      
      setSelectedBlock(newBlock);
      setIsModalVisible(true);
    }
  };

  // 处理编辑卡片
  const handleEditCard = (block: AnyBlock) => {
    setSelectedBlock(block);
    setIsModalVisible(true);
  };

  // 处理删除卡片
  const handleDeleteCard = async (id: string) => {
    await deleteDocument(id);
  };

  // 处理保存编辑
  const handleSaveEdit = async (block: AnyBlock) => {
    await updateDocument(block.id, {
      title: block.title || '无标题',
      tags: block.tags || []
    });
    setIsModalVisible(false);
    setSelectedBlock(null);
  };

  // 处理取消编辑
  const handleCancelEdit = () => {
    setIsModalVisible(false);
    setSelectedBlock(null);
  };

  if (isModalVisible && selectedBlock) {
    return (
      <DocumentEditor
        documentId={selectedBlock.id}
        onSave={handleSaveEdit}
        onCancel={handleCancelEdit}
        initialData={{
          title: selectedBlock instanceof DocBlock ? selectedBlock.title : '',
          content: selectedBlock instanceof DocBlock ? selectedBlock.content : '',
          tags: [],
          blocks: []
        }}
      />
    );
  }

  return (
    <div className="main-content">
      <div style={{ padding: '20px', maxWidth: 1200, margin: '0 auto' }}>
        {loading ? (
          <div style={{ textAlign: 'center', padding: '50px' }}>
            <Spin size="large" />
          </div>
        ) : blocks.length === 0 ? (
          <Empty
            image={Empty.PRESENTED_IMAGE_SIMPLE}
            description="暂无笔记"
            style={{ marginTop: 100 }}
          >
            <Button 
              type="primary" 
              icon={<PlusOutlined />} 
              onClick={handleAddCard}
            >
              创建第一篇笔记
            </Button>
          </Empty>
        ) : (
          <Row gutter={[16, 16]}>
            {blocks.map(block => (
              <Col xs={24} sm={12} md={8} lg={6} key={block.id}>
                <CardView
                  block={block}
                  onEdit={handleEditCard}
                  onDelete={handleDeleteCard}
                />
              </Col>
            ))}
          </Row>
        )}
      </div>
    </div>
  );
});

export default CardList;