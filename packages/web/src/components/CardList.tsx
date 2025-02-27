// 导入必要的依赖
import React, { useEffect, useState, useCallback, useMemo } from 'react';
import { Card as AntCard, Input, Spin, Button, Popconfirm, message, Empty } from 'antd';
import { EditOutlined, DeleteOutlined } from '@ant-design/icons';
import { Card } from '../types/card';
import MDEditor from '@uiw/react-md-editor';
import { useCardStore } from '../store/cardStore';
import './CardList.css';

const { Search } = Input;

// 组件属性接口定义
interface CardListProps {
  onEditCard: (card: Card) => void;  // 编辑卡片的回调函数
  refreshTrigger: number;            // 刷新触发器
}

// 卡片列表组件
const CardList: React.FC<CardListProps> = ({ onEditCard, refreshTrigger }) => {
  // 状态管理
  const [searchText, setSearchText] = useState('');  // 搜索文本
  const { cards, loading, loadCards, deleteCard } = useCardStore();  // 从全局状态获取数据和方法

  // 加载卡片数据
  useEffect(() => {
    (async () => {
      try {
        await loadCards();
      } catch (error) {
        console.error('加载卡片失败:', error);
        message.error('加载卡片失败');
      }
    })();
  }, [refreshTrigger]);  // 当刷新触发器变化时重新加载

  // 处理编辑卡片
  const handleEdit = useCallback((card: Card) => {
    onEditCard(card);
  }, [onEditCard]);

  // 处理删除卡片
  const handleDelete = useCallback(async (id: number) => {
    try {
      await deleteCard(id);
      message.success('删除成功');
    } catch (error) {
      console.error('删除卡片失败:', error);
      message.error('删除失败');
    }
  }, [deleteCard]);

  // 根据搜索文本过滤卡片
  const filteredCards = useMemo(() => {
    if (!searchText) return cards;
    const lowerSearchText = searchText.toLowerCase();
    return cards.filter(card => 
      card.title.toLowerCase().includes(lowerSearchText) ||
      card.content.toLowerCase().includes(lowerSearchText)
    );
  }, [cards, searchText]);

  // 渲染UI
  return (
    <div className="card-list">
      {/* 搜索栏 */}
      <div className="card-list-header">
        <Search
          placeholder="搜索卡片..."
          allowClear
          onChange={e => setSearchText(e.target.value)}
          style={{ width: '100%' }}
        />
      </div>
      
      {/* 卡片列表内容 */}
      <div className="card-list-content">
        <Spin spinning={loading}>
          {filteredCards.length > 0 ? (
            filteredCards.map(card => (
              <AntCard
                key={card.id}
                className="card-item"
                actions={[
                  // 编辑按钮
                  <Button
                    key="edit"
                    type="text"
                    icon={<EditOutlined />}
                    onClick={() => handleEdit(card)}
                  >
                    编辑
                  </Button>,
                  // 删除按钮（带确认框）
                  <Popconfirm
                    key="delete"
                    title="确定要删除这张卡片吗？"
                    onConfirm={() => handleDelete(card.id)}
                    okText="确定"
                    cancelText="取消"
                  >
                    <Button
                      type="text"
                      danger
                      icon={<DeleteOutlined />}
                    >
                      删除
                    </Button>
                  </Popconfirm>
                ]}
              >
                {/* 卡片内容展示 */}
                <AntCard.Meta
                  title={card.title}
                  description={
                    <div data-color-mode="light">
                      <MDEditor.Markdown 
                        source={card.content} 
                        style={{ whiteSpace: 'pre-wrap' }}
                      />
                    </div>
                  }
                />
              </AntCard>
            ))
          ) : (
            // 空状态展示
            <Empty 
              description={searchText ? "没有找到匹配的卡片" : "还没有创建任何卡片"} 
              style={{ marginTop: '40px' }}
            />
          )}
        </Spin>
      </div>
    </div>
  );
};

// 使用 React.memo 优化性能，避免不必要的重渲染
export default React.memo(CardList);