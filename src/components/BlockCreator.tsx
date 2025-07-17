import React, { useState } from 'react';
import { useBlockManager } from '../stores/blockManager';
import { BlockType } from '../types/block';
import { FloatButton, Modal, Input, message } from 'antd';
import { FileAddOutlined } from '@ant-design/icons';

export const BlockCreator: React.FC = () => {
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const { openBlockId, createBlock } = useBlockManager();
  const [isModalVisible, setIsModalVisible] = useState(false);

  const handleCreate = () => {
    setIsModalVisible(true);
  };

  const handleOk = async () => {
    try {
      const newBlock = {
        type: BlockType.DOC,
        parentId: openBlockId,
        childrenIds: [],
        properties: {
          title: title || '未命名文档',
          content
        },
        createdAt: new Date(),
        modifiedAt: new Date(),
        isDeleted: false
      };

      const blockId = await createBlock(newBlock);
      console.log('创建文档块完成，ID:', blockId);
      message.success('文档块创建成功');
      setIsModalVisible(false);
      setTitle('');
      setContent('');
      // 可以选择在这里手动打开新创建的块
      // await openBlockDoc(blockId);
    } catch (error) {
      console.error('创建文档块错误:', error);
      message.error('创建文档块失败');
    }
  };

  const handleCancel = () => {
    setIsModalVisible(false);
    setTitle('');
    setContent('');
  };

  return (
    <div className="block-creator">
      <FloatButton 
        icon={<FileAddOutlined />}
        type="primary"
        tooltip="创建文档块"
        onClick={handleCreate}
      />
      
      <Modal
        title="创建文档块"
        open={isModalVisible}
        onOk={handleOk}
        onCancel={handleCancel}
        width={800}
        centered
      >
        <Input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="文档标题"
          style={{ marginBottom: 16 }}
        />
        <Input.TextArea
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="文档内容"
          rows={10}
        />
      </Modal>
    </div>
  );
};
