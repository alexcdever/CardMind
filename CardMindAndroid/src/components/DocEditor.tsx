import React, { useState, useEffect } from 'react';
import { useBlockManager } from '../stores/blockManager';
import { BlockType, UnifiedBlock, DocBlockProperties } from '../types/block';
import { FloatButton, Modal, Input, message, Button } from 'antd';
import { FileAddOutlined, EditOutlined } from '@ant-design/icons';

interface DocEditorProps {
  // 编辑模式时传入block
  block?: UnifiedBlock & {
    properties: DocBlockProperties;
  };
  // 创建模式回调
  onCreateSuccess?: (blockId: string) => void;
}

export const DocEditor: React.FC<DocEditorProps> = ({ block, onCreateSuccess }) => {
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const { createBlock, updateBlock } = useBlockManager();
  const [isModalVisible, setIsModalVisible] = useState(false);
  const isEditMode = !!block;

  // 编辑模式初始化
  useEffect(() => {
    if (isEditMode && block) {
      setTitle(block.properties.title);
      setContent(block.properties.content);
    }
  }, [block, isEditMode]);

  const showEditor = () => {
    setIsModalVisible(true);
  };

  const handleSubmit = async () => {
    try {
      if (isEditMode && block) {
        // 更新现有块
        await updateBlock({
          ...block,
          properties: {
            title: title || '未命名文档',
            content
          },
          modifiedAt: new Date()
        });
        message.success('文档更新成功');
      } else {
        // 创建新块
        const newBlock = {
          type: BlockType.DOC,
          parentId: null,
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
        message.success('文档创建成功');
        onCreateSuccess?.(blockId);
      }

      setIsModalVisible(false);
      resetForm();
    } catch (error) {
      console.error('操作失败:', error);
      message.error(isEditMode ? '文档更新失败' : '文档创建失败');
    }
  };

  const resetForm = () => {
    setTitle('');
    setContent('');
  };

  const handleCancel = () => {
    setIsModalVisible(false);
    if (!isEditMode) {
      resetForm();
    }
  };

  return (
    <>
      {!isEditMode && (
        <FloatButton 
          icon={<FileAddOutlined />}
          type="primary"
          tooltip="创建文档"
          onClick={showEditor}
        />
      )}

      {isEditMode && (
        <Button 
          type="text" 
          icon={<EditOutlined />} 
          onClick={showEditor}
        />
      )}

      <Modal
        title={isEditMode ? '编辑文档' : '创建文档'}
        open={isModalVisible}
        onOk={handleSubmit}
        onCancel={handleCancel}
        width={800}
        centered
        destroyOnClose
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
    </>
  );
};
