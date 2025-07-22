import { useBlockManager } from '../stores/blockManager';
import { useEffect, useState } from 'react';
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

export const DocumentGallery = () => {
  const { fetchAllBlocks } = useBlockManager();
  const [blocks, setBlocks] = useState<UnifiedBlock[]>([]);
  const [layout, setLayout] = useState<LayoutType>('grid');

  // 加载块数据
  useEffect(() => {
    const loadBlocks = async () => {
      const loadedBlocks = await fetchAllBlocks();
      setBlocks(loadedBlocks);
    };
    loadBlocks();
  }, []); // 空依赖数组，只加载一次

  // 监听zustand store中的blocks变化
  useEffect(() => {
    const unsubscribe = useBlockManager.subscribe(
      (state: { blocks: UnifiedBlock[] }) => {
        setBlocks(state.blocks);
      }
    );
    return () => unsubscribe();
  }, []);

  // 渲染卡片内容
  const renderCardContent = (block: UnifiedBlock) => {
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
      </div>
    );
  };

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
          <Card key={block.id} className="block-card" hoverable>
            {renderCardContent(block)}
          </Card>
        ))}
      </div>
    </div>
  );
};
