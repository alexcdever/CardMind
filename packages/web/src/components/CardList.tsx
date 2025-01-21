import React, { useEffect, useState, useCallback, useMemo } from 'react';
import { Card as AntCard, Row, Col, Empty, Input, Tag, Spin, Button, Popconfirm, message, Space } from 'antd';
import { EditOutlined, DeleteOutlined } from '@ant-design/icons';
import { Card } from '../types/electron';
import MDEditor from '@uiw/react-md-editor';
import { getTagColor } from '../utils/colorUtils';
import './CardList.css';

const { Search } = Input;

interface CardListProps {
  onEditCard: (card: Card) => void;
  refreshTrigger: number;
}

const CardList: React.FC<CardListProps> = ({ onEditCard, refreshTrigger }) => {
  const [loading, setLoading] = useState(false);
  const [cards, setCards] = useState<Card[]>([]);
  const [searchText, setSearchText] = useState('');

  const loadCards = useCallback(async () => {
    if (loading) return; // 防止重复加载
    
    setLoading(true);
    try {
      console.log('CardList: Loading cards');
      const response = await window.electron.database.getAllCards();
      console.log('CardList: Loaded cards:', response);
      
      if (!response.success) {
        throw new Error(response.error || 'Failed to load cards');
      }
      
      // 验证卡片数据
      const validCards = response.data.filter(card => {
        if (!card || typeof card.id === 'undefined') {
          console.warn('CardList: Invalid card data:', card);
          return false;
        }
        return true;
      });
      
      setCards(validCards);
    } catch (error) {
      console.error('CardList: Error loading cards:', error);
      message.error('Failed to load cards');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!loading) {
      const timer = setTimeout(() => {
        loadCards();
      }, 0);
      return () => clearTimeout(timer);
    }
  }, [refreshTrigger]);

  const handleEdit = useCallback((card: Card) => {
    console.log('CardList: Editing card:', card);
    onEditCard(card);
  }, [onEditCard]);

  const handleDelete = useCallback(async (id: number) => {
    try {
      // 确保 id 是数字类型
      const cardId = typeof id === 'string' ? parseInt(id, 10) : id;
      
      if (isNaN(cardId)) {
        throw new Error('Invalid card ID');
      }
      
      console.log('CardList: Deleting card:', cardId);
      await window.electron.database.deleteCard(cardId);
      console.log('CardList: Card deleted successfully');
      message.success('Card deleted successfully');
      loadCards(); // 重新加载卡片列表
    } catch (error) {
      console.error('CardList: Error deleting card:', error);
      message.error(error instanceof Error ? error.message : 'Failed to delete card');
    }
  }, [loadCards]);

  const handleSearch = useCallback(async (value: string) => {
    setLoading(true);
    try {
      if (value.trim()) {
        console.log('CardList: Searching for:', value);
        const response = await window.electron.database.searchCards(value);
        console.log('CardList: Search response:', response);
        
        if (!response.success) {
          throw new Error(response.error || 'Failed to search cards');
        }
        
        if (!response.data) {
          console.error('CardList: Search response data is missing');
          setCards([]);
          return;
        }
        
        console.log('CardList: Setting cards:', response.data);
        setCards(response.data);
      } else {
        await loadCards();
      }
    } catch (error) {
      console.error('CardList: Error searching cards:', error);
      message.error(error instanceof Error ? error.message : 'Failed to search cards');
      setCards([]); // 出错时清空卡片列表
    } finally {
      setLoading(false);
    }
  }, [loadCards]);

  const renderCard = useCallback((card: Card) => {
    if (!card || typeof card.id === 'undefined') {
      console.warn('CardList: Attempting to render invalid card:', card);
      return null;
    }

    return (
      <Col key={`card-${card.id}`} xs={24} sm={12} md={8} lg={6} style={{ padding: '8px' }}>
        <AntCard
          hoverable
          title={card.title || 'Untitled'}
          style={{ 
            height: '300px',
            display: 'flex',
            flexDirection: 'column'
          }}
          styles={{
            body: { 
              flex: '1 1 auto',
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column',
              padding: '12px'
            },
            header: {
              flex: '0 0 auto',
              overflow: 'hidden',
              whiteSpace: 'nowrap',
              textOverflow: 'ellipsis'
            }
          }}
          extra={
            <Space>
              <Button 
                type="text" 
                icon={<EditOutlined />} 
                onClick={() => handleEdit(card)}
              >
                Edit
              </Button>
              <Popconfirm
                title="Delete this card?"
                description="Are you sure to delete this card?"
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
            </Space>
          }
        >
          <div style={{ 
            height: '100%',
            display: 'flex',
            flexDirection: 'column'
          }}>
            <div className="card-content-container" style={{ flex: '1 1 auto', overflow: 'hidden' }}>
              <div data-color-mode="light">
                <MDEditor.Markdown 
                  source={card.content || 'No content'} 
                  style={{ 
                    width: '100%',
                    background: 'none',
                    overflow: 'hidden',
                    display: '-webkit-box',
                    WebkitBoxOrient: 'vertical',
                    WebkitLineClamp: 8,
                  }}
                  className="wmde-markdown-var"
                />
              </div>
            </div>
            {card.tags && card.tags.length > 0 && (
              <div style={{ marginTop: 'auto', paddingTop: '8px' }}>
                {card.tags.map((tag, index) => {
                  const tagName = typeof tag === 'string' ? tag : tag.name;
                  const color = getTagColor(tagName);
                  return (
                    <Tag 
                      key={index} 
                      style={{ 
                        marginBottom: '4px',
                        backgroundColor: color,
                        borderColor: color,
                        color: '#000000',
                      }}
                    >
                      {tagName}
                    </Tag>
                  );
                })}
              </div>
            )}
          </div>
        </AntCard>
      </Col>
    );
  }, [handleEdit, handleDelete]);

  const cardList = useMemo(() => {
    console.log('CardList: Rendering cards:', cards);
    // 确保 cards 是数组
    const cardsArray = Array.isArray(cards) ? cards : [];
    return (
      <Row gutter={[16, 16]}>
        {cardsArray.filter(card => card && typeof card.id !== 'undefined').map(card => renderCard(card))}
      </Row>
    );
  }, [cards, renderCard]);

  return (
    <div style={{ padding: 20 }}>
      <Search
        placeholder="Search cards..."
        onSearch={handleSearch}
        style={{ marginBottom: 16 }}
        loading={loading}
      />
      {loading ? (
        <div style={{ textAlign: 'center', padding: '50px' }}>
          <Spin size="large" />
        </div>
      ) : cards.length > 0 ? (
        cardList
      ) : (
        <Empty description="No cards found" />
      )}
    </div>
  );
};

export default React.memo(CardList);