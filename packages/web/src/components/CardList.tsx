import React, { useEffect, useState, useCallback, useMemo } from 'react';
import { Card as AntCard, Row, Col, Empty, Input, Spin, Button, Popconfirm, message } from 'antd';
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
    loadCards().catch(error => {
      console.error('Failed to load cards:', error);
      message.error('Failed to load cards');
    });
  }, [loadCards, refreshTrigger]);

  const handleEdit = useCallback((card: Card) => {
    onEditCard(card);
  }, [onEditCard]);

  const handleDelete = useCallback(async (id: number) => {
    try {
      await deleteCard(id);
      message.success('Card deleted successfully');
    } catch (error) {
      console.error('Failed to delete card:', error);
      message.error('Failed to delete card');
    }
  }, [deleteCard]);

  const handleSearch = useCallback((value: string) => {
    setSearchText(value);
  }, []);

  const filteredCards = useMemo(() => {
    if (!searchText) {
      return cards;
    }
    const lowerSearchText = searchText.toLowerCase();
    return cards.filter(card => 
      card.title.toLowerCase().includes(lowerSearchText) ||
      card.content.toLowerCase().includes(lowerSearchText)
    );
  }, [cards, searchText]);

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '50px' }}>
        <Spin size="large" tip="Loading cards..." />
      </div>
    );
  }

  if (cards.length === 0) {
    return (
      <Empty 
        description="No cards found" 
        style={{ margin: '50px 0' }}
      />
    );
  }

  return (
    <div className="card-list">
      <div className="card-list-header">
        <Search
          placeholder="Search cards..."
          allowClear
          onChange={e => handleSearch(e.target.value)}
          style={{ width: 200 }}
        />
      </div>
      
      <Row gutter={[16, 16]}>
        {filteredCards.map(card => (
          <Col key={card.id} xs={24} sm={12} md={8} lg={6}>
            <AntCard
              hoverable
              className="card-item"
              actions={[
                <Button
                  key="edit"
                  type="text"
                  icon={<EditOutlined />}
                  onClick={() => handleEdit(card)}
                >
                  Edit
                </Button>,
                <Popconfirm
                  key="delete"
                  title="Are you sure you want to delete this card?"
                  onConfirm={() => handleDelete(card.id)}
                  okText="Yes"
                  cancelText="No"
                >
                  <Button
                    type="text"
                    danger
                    icon={<DeleteOutlined />}
                  >
                    Delete
                  </Button>
                </Popconfirm>
              ]}
            >
              <AntCard.Meta
                title={card.title}
                description={
                  <div className="card-content">
                    <MDEditor.Markdown source={card.content} />
                  </div>
                }
              />
            </AntCard>
          </Col>
        ))}
      </Row>
    </div>
  );
};

export default React.memo(CardList);