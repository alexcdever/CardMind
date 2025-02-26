import React, { useEffect, useState, useCallback, useMemo } from 'react';
import { Card as AntCard, Input, Spin, Button, Popconfirm, message, Empty } from 'antd';
import { EditOutlined, DeleteOutlined } from '@ant-design/icons';
import { Card } from '../types/card';
import MDEditor from '@uiw/react-md-editor';
import { useCardStore } from '../store/cardStore';
import './CardList.css';

const { Search } = Input;

interface CardListProps {
  onEditCard: (card: Card) => void;
  refreshTrigger: number;
}

const CardList: React.FC<CardListProps> = ({ onEditCard, refreshTrigger }) => {
  const [searchText, setSearchText] = useState('');
  const { cards, loading, loadCards, deleteCard } = useCardStore();

  useEffect(() => {
    (async () => {
      try {
        await loadCards();
      } catch (error) {
        console.error('加载卡片失败:', error);
        message.error('加载卡片失败');
      }
    })();
  }, [refreshTrigger]);

  const handleEdit = useCallback((card: Card) => {
    onEditCard(card);
  }, [onEditCard]);

  const handleDelete = useCallback(async (id: number) => {
    try {
      await deleteCard(id);
      message.success('删除成功');
    } catch (error) {
      console.error('删除卡片失败:', error);
      message.error('删除失败');
    }
  }, [deleteCard]);

  const filteredCards = useMemo(() => {
    if (!searchText) return cards;
    const lowerSearchText = searchText.toLowerCase();
    return cards.filter(card => 
      card.title.toLowerCase().includes(lowerSearchText) ||
      card.content.toLowerCase().includes(lowerSearchText)
    );
  }, [cards, searchText]);

  return (
    <div className="card-list">
      <div className="card-list-header">
        <Search
          placeholder="搜索卡片..."
          allowClear
          onChange={e => setSearchText(e.target.value)}
          style={{ width: '100%' }}
        />
      </div>
      
      <div className="card-list-content">
        <Spin spinning={loading}>
          {filteredCards.length > 0 ? (
            filteredCards.map(card => (
              <AntCard
                key={card.id}
                className="card-item"
                actions={[
                  <Button
                    key="edit"
                    type="text"
                    icon={<EditOutlined />}
                    onClick={() => handleEdit(card)}
                  >
                    编辑
                  </Button>,
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
            <Empty 
              description="暂无卡片" 
              style={{ margin: '40px 0' }}
            />
          )}
        </Spin>
      </div>
    </div>
  );
};

export default React.memo(CardList);