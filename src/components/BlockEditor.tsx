import React, { useState } from 'react';
import { BlockType, UnifiedBlock, DocBlockProperties, TextBlockProperties, MediaBlockProperties, CodeBlockProperties } from '../types/block';
import { Input, Select, Button, Upload } from 'antd';
import { CodeOutlined, FileTextOutlined, FileImageOutlined } from '@ant-design/icons';

// 类型守卫函数
function isDocBlock(block: UnifiedBlock): block is UnifiedBlock & { properties: DocBlockProperties } {
  return block.type === BlockType.DOC;
}

function isTextBlock(block: UnifiedBlock): block is UnifiedBlock & { properties: TextBlockProperties } {
  return block.type === BlockType.TEXT;
}

function isMediaBlock(block: UnifiedBlock): block is UnifiedBlock & { properties: MediaBlockProperties } {
  return block.type === BlockType.MEDIA;
}

function isCodeBlock(block: UnifiedBlock): block is UnifiedBlock & { properties: CodeBlockProperties } {
  return block.type === BlockType.CODE;
}

interface Props {
  block: UnifiedBlock;
  onSave: (updatedBlock: UnifiedBlock) => void;
  onCancel: () => void;
}

export const BlockEditor: React.FC<Props> = ({ block, onSave, onCancel }) => {
  const [editedBlock, setEditedBlock] = useState<UnifiedBlock>({...block});

  const handleChange = (key: string, value: any) => {
    setEditedBlock(prev => ({
      ...prev,
      properties: {
        ...prev.properties,
        [key]: value
      },
      modifiedAt: new Date()
    }));
  };

  const renderEditor = () => {
    if (isDocBlock(editedBlock)) {
      return (
        <div>
          <Input
            value={editedBlock.properties.title || ''}
            onChange={(e) => handleChange('title', e.target.value)}
            placeholder="文档标题"
          />
          <Input.TextArea
            value={editedBlock.properties.content || ''}
            onChange={(e) => handleChange('content', e.target.value)}
            placeholder="文档内容"
            rows={10}
          />
        </div>
      );
    }

    if (isTextBlock(editedBlock)) {
      return (
        <Input.TextArea
          value={editedBlock.properties.content || ''}
          onChange={(e) => handleChange('content', e.target.value)}
          placeholder="输入文本内容"
          rows={6}
        />
      );
    }

    if (isCodeBlock(editedBlock)) {
      return (
        <Input.TextArea
          value={editedBlock.properties.code || ''}
          onChange={(e) => handleChange('code', e.target.value)}
          placeholder="输入代码"
          rows={10}
        />
      );
    }

    if (isMediaBlock(editedBlock)) {
      return (
        <Upload
          beforeUpload={(file) => {
            const url = URL.createObjectURL(file);
            handleChange('filePath', url);
            handleChange('fileName', file.name);
            return false;
          }}
        >
          <Button icon={<FileImageOutlined />}>上传媒体文件</Button>
        </Upload>
      );
    }

    return null;
  };

  return (
    <div className="block-editor">
      {renderEditor()}
      <div style={{ marginTop: 16 }}>
        <Button type="primary" onClick={() => onSave(editedBlock)}>
          保存
        </Button>
        <Button style={{ marginLeft: 8 }} onClick={onCancel}>
          取消
        </Button>
      </div>
    </div>
  );
};
