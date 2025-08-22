import React from 'react';
import { Card, Typography, Tag } from 'antd';
import { AnyBlock } from '@cardmind/types';
import { EditOutlined, DeleteOutlined } from '@ant-design/icons';
import dayjs from 'dayjs';

const { Title, Paragraph } = Typography;

interface CardViewProps {
  block: AnyBlock;
  onEdit: (block: AnyBlock) => void;
  onDelete: (id: string) => void;
}

const CardView: React.FC<CardViewProps> = ({ block, onEdit, onDelete }) => {
  const title = block.properties?.title || '无标题';
  const content = block.properties?.content || '暂无内容';
  const tags = block.properties?.tags || [];

  return (
    <Card
      className="card-item"
      hoverable
      style={{ 
        marginBottom: 16,
        borderRadius: 12,
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
        transition: 'all 0.3s ease'
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.transform = 'translateY(-2px)';
        e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.15)';
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.transform = 'translateY(0)';
        e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.1)';
      }}
      actions={[
        <EditOutlined key="edit" onClick={() => onEdit(block)} />,
        <DeleteOutlined key="delete" onClick={() => onDelete(block.id)} />
      ]}
    >
      <div style={{ height: 200, overflow: 'hidden' }}>
        <Title level={4} style={{ marginBottom: 8 }}>
          {title}
        </Title>
        <Paragraph 
          ellipsis={{ rows: 3 }}
          style={{ color: '#666', marginBottom: 12 }}
        >
          {content}
        </Paragraph>
        
        <div style={{ marginBottom: 8 }}>
          {tags.map((tag: string) => (
            <Tag key={tag} color="blue" style={{ marginBottom: 4 }}>
              {tag}
            </Tag>
          ))}
        </div>

        <div style={{ fontSize: 12, color: '#999' }}>
          {dayjs(block.createdAt).format('YYYY-MM-DD HH:mm')}
        </div>
      </div>
    </Card>
  );
};

export default CardView;