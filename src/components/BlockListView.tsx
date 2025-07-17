import { useBlockManager } from '../stores/blockManager';
import { useEffect, useState } from 'react';
import { 
  UnifiedBlock, 
  BlockType, 
  DocBlockProperties, 
  TextBlockProperties 
} from '../types/block';
import '../styles/block-list.css';

// 布局类型
type LayoutType = 'grid' | 'list-single' | 'list-double';

export const BlockListView = () => {
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
      <div className="card-content">
        <h3 className="card-title">{title}</h3>
        <p className="card-preview">{previewText}</p>
        <div className="card-meta">
          <span>创建: {new Date(block.createdAt).toLocaleString()}</span>
          <span>修改: {new Date(block.modifiedAt).toLocaleString()}</span>
        </div>
      </div>
    );
  };

  return (
    <div className={`block-list ${layout}`}>
      <div className="layout-controls">
        <button 
          className={layout === 'grid' ? 'active' : ''}
          onClick={() => setLayout('grid')}
        >
          平铺
        </button>
        <button 
          className={layout === 'list-single' ? 'active' : ''}
          onClick={() => setLayout('list-single')}
        >
          单列
        </button>
        <button 
          className={layout === 'list-double' ? 'active' : ''}
          onClick={() => setLayout('list-double')}
        >
          双列
        </button>
      </div>

      <div className="blocks-container">
        {blocks.map(block => (
          <div key={block.id} className="block-card">
            {renderCardContent(block)}
          </div>
        ))}
      </div>
    </div>
  );
};
