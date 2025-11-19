# CardService API接口设计与单元测试

> 本文档定义了CardMind系统的卡片服务接口、完整实现及其单元测试，并提供了实际使用示例。

## 目录
- [1. 接口定义](#1-接口定义)
- [2. 完整实现示例](#2-完整实现示例)
- [3. 实际使用示例](#3-实际使用示例)
- [4. 单元测试](#4-单元测试)

## 1. 接口定义

```typescript
// src/services/card/CardService.ts

/**
 * 卡片数据接口
 */
export interface Card {
  /**
   * 卡片唯一标识符
   */
  id: string;
  
  /**
   * 卡片标题
   */
  title: string;
  
  /**
   * 卡片内容
   */
  content: string;
  
  /**
   * 创建时间
   */
  createdAt: number; // Timestamp
  
  /**
   * 更新时间
   */
  updatedAt: number; // Timestamp
  
  /**
   * 创建者设备ID
   */
  createdBy: string;
  
  /**
   * 最后更新者设备ID
   */
  lastUpdatedBy: string;
  
  /**
   * 标签列表
   */
  tags: string[];
  
  /**
   * 是否为收藏卡片
   */
  isStarred: boolean;
}

/**
 * 卡片创建参数接口
 */
export interface CardCreateParams {
  /**
   * 卡片标题
   */
  title: string;
  
  /**
   * 卡片内容
   */
  content: string;
  
  /**
   * 标签列表
   */
  tags?: string[];
}

/**
 * 卡片更新参数接口
 */
export interface CardUpdateParams {
  /**
   * 卡片标题
   */
  title?: string;
  
  /**
   * 卡片内容
   */
  content?: string;
  
  /**
   * 标签列表
   */
  tags?: string[];
  
  /**
   * 是否为收藏卡片
   */
  isStarred?: boolean;
}

/**
 * 卡片服务接口
 */
export interface CardService {
  /**
   * 创建新卡片
   * @param params 卡片创建参数
   * @returns 创建的卡片
   */
  createCard(params: CardCreateParams): Promise<Card>;
  
  /**
   * 获取卡片列表
   * @returns 卡片列表
   */
  getAllCards(): Promise<Card[]>;
  
  /**
   * 根据ID获取卡片
   * @param id 卡片ID
   * @returns 卡片，如果不存在则返回null
   */
  getCard(id: string): Promise<Card | null>;
  
  /**
   * 更新卡片
   * @param id 卡片ID
   * @param params 卡片更新参数
   * @returns 更新后的卡片，如果不存在则返回null
   */
  updateCard(id: string, params: CardUpdateParams): Promise<Card | null>;
  
  /**
   * 删除卡片
   * @param id 卡片ID
   * @returns 删除结果
   */
  deleteCard(id: string): Promise<boolean>;
  
  /**
   * 搜索卡片
   * @param query 搜索关键词
   * @returns 匹配的卡片列表
   */
  searchCards(query: string): Promise<Card[]>;
}
```

## 2. 完整实现示例

```typescript
// src/services/card/CardServiceImpl.ts
import { CardService, Card, CardCreateParams, CardUpdateParams } from './CardService';
import { ICardStore } from '../store/CardStore';
import { ISyncService } from '../sync/SyncService';
import { IDeviceService } from '../device/DeviceService';

/**
 * 卡片服务实现类
 */
export class CardServiceImpl implements CardService {
  constructor(
    private cardStore: ICardStore,
    private syncService: ISyncService,
    private deviceService: IDeviceService
  ) {}

  /**
   * 创建新卡片
   */
  async createCard(params: CardCreateParams): Promise<Card> {
    const now = Date.now();
    const deviceId = this.deviceService.getDeviceId();
    
    const newCard: Card = {
      id: this.generateCardId(),
      title: params.title,
      content: params.content,
      createdAt: now,
      updatedAt: now,
      createdBy: deviceId,
      lastUpdatedBy: deviceId,
      tags: params.tags || [],
      isStarred: false
    };

    await this.cardStore.saveCard(newCard);
    await this.syncService.broadcastCardChange('create', newCard);
    
    return newCard;
  }

  /**
   * 获取卡片列表
   */
  async getAllCards(): Promise<Card[]> {
    return await this.cardStore.getAllCards();
  }

  /**
   * 根据ID获取卡片
   */
  async getCard(id: string): Promise<Card | null> {
    return await this.cardStore.getCardById(id);
  }

  /**
   * 更新卡片
   */
  async updateCard(id: string, params: CardUpdateParams): Promise<Card | null> {
    const existingCard = await this.cardStore.getCardById(id);
    if (!existingCard) return null;

    const updatedCard: Card = {
      ...existingCard,
      ...params,
      updatedAt: Date.now(),
      lastUpdatedBy: this.deviceService.getDeviceId()
    };

    await this.cardStore.saveCard(updatedCard);
    await this.syncService.broadcastCardChange('update', updatedCard);
    
    return updatedCard;
  }

  /**
   * 删除卡片
   */
  async deleteCard(id: string): Promise<boolean> {
    const success = await this.cardStore.deleteCard(id);
    if (success) {
      await this.syncService.broadcastCardChange('delete', { id });
    }
    return success;
  }

  /**
   * 搜索卡片
   */
  async searchCards(query: string): Promise<Card[]> {
    const allCards = await this.cardStore.getAllCards();
    const lowerCaseQuery = query.toLowerCase();
    
    return allCards.filter(card => 
      card.title.toLowerCase().includes(lowerCaseQuery) ||
      card.content.toLowerCase().includes(lowerCaseQuery) ||
      card.tags.some(tag => tag.toLowerCase().includes(lowerCaseQuery))
    );
  }

  /**
   * 生成卡片ID
   */
  private generateCardId(): string {
    return `card_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}
```

## 3. 实际使用示例

### 3.1 Web平台使用示例

```typescript
// src/components/CardManager.tsx
import React, { useState, useEffect } from 'react';
import { CardServiceImpl } from '../services/card/CardServiceImpl';
import { CardStoreImpl } from '../store/CardStoreImpl';
import { SyncServiceImpl } from '../services/sync/SyncServiceImpl';
import { DeviceServiceImpl } from '../services/device/DeviceServiceImpl';
import { CardCreateParams, CardUpdateParams } from '../services/card/CardService';

const CardManager: React.FC = () => {
  const [cards, setCards] = useState<any[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [newCardTitle, setNewCardTitle] = useState('');
  const [newCardContent, setNewCardContent] = useState('');
  const [editingCard, setEditingCard] = useState<any>(null);

  // 初始化服务
  const deviceService = new DeviceServiceImpl();
  const cardStore = new CardStoreImpl();
  const syncService = new SyncServiceImpl(deviceService);
  const cardService = new CardServiceImpl(cardStore, syncService, deviceService);

  // 加载卡片
  const loadCards = async () => {
    try {
      const allCards = await cardService.getAllCards();
      setCards(allCards);
    } catch (error) {
      console.error('加载卡片失败:', error);
    }
  };

  // 初始加载
  useEffect(() => {
    loadCards();
    
    // 订阅同步事件
    const unsubscribe = syncService.onCardChange((changeType, card) => {
      loadCards(); // 重新加载所有卡片
    });
    
    return () => unsubscribe();
  }, []);

  // 搜索卡片
  useEffect(() => {
    if (searchQuery) {
      cardService.searchCards(searchQuery)
        .then(results => setCards(results))
        .catch(error => console.error('搜索失败:', error));
    } else {
      loadCards();
    }
  }, [searchQuery]);

  // 创建卡片
  const handleCreateCard = async () => {
    if (!newCardTitle.trim()) return;

    try {
      const createParams: CardCreateParams = {
        title: newCardTitle.trim(),
        content: newCardContent.trim()
      };

      await cardService.createCard(createParams);
      
      // 重置表单
      setNewCardTitle('');
      setNewCardContent('');
      
      // 重新加载卡片
      loadCards();
    } catch (error) {
      console.error('创建卡片失败:', error);
    }
  };

  // 更新卡片
  const handleUpdateCard = async () => {
    if (!editingCard || !editingCard.id) return;

    try {
      const updateParams: CardUpdateParams = {
        title: editingCard.title,
        content: editingCard.content,
        isStarred: editingCard.isStarred
      };

      await cardService.updateCard(editingCard.id, updateParams);
      setEditingCard(null);
      loadCards();
    } catch (error) {
      console.error('更新卡片失败:', error);
    }
  };

  // 删除卡片
  const handleDeleteCard = async (id: string) => {
    if (window.confirm('确定要删除这张卡片吗？')) {
      try {
        await cardService.deleteCard(id);
        loadCards();
      } catch (error) {
        console.error('删除卡片失败:', error);
      }
    }
  };

  // 切换收藏状态
  const toggleStarred = async (card: any) => {
    try {
      await cardService.updateCard(card.id, { isStarred: !card.isStarred });
      loadCards();
    } catch (error) {
      console.error('更新收藏状态失败:', error);
    }
  };

  return (
    <div className="card-manager">
      <h2>卡片管理</h2>
      
      {/* 搜索框 */}
      <div className="search-bar">
        <input 
          type="text" 
          placeholder="搜索卡片..." 
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />
      </div>

      {/* 创建卡片表单 */}
      <div className="create-card-form">
        <input 
          type="text" 
          placeholder="卡片标题" 
          value={newCardTitle}
          onChange={(e) => setNewCardTitle(e.target.value)}
        />
        <textarea 
          placeholder="卡片内容" 
          value={newCardContent}
          onChange={(e) => setNewCardContent(e.target.value)}
        />
        <button onClick={handleCreateCard}>创建卡片</button>
      </div>

      {/* 卡片列表 */}
      <div className="cards-list">
        {cards.map(card => (
          <div key={card.id} className="card">
            {editingCard?.id === card.id ? (
              // 编辑模式
              <div className="card-edit">
                <input 
                  type="text" 
                  value={editingCard.title}
                  onChange={(e) => setEditingCard({...editingCard, title: e.target.value})}
                />
                <textarea 
                  value={editingCard.content}
                  onChange={(e) => setEditingCard({...editingCard, content: e.target.value})}
                />
                <div className="card-actions">
                  <button onClick={handleUpdateCard}>保存</button>
                  <button onClick={() => setEditingCard(null)}>取消</button>
                </div>
              </div>
            ) : (
              // 查看模式
              <>
                <div className="card-header">
                  <h3>{card.title}</h3>
                  <div className="card-meta">
                    <span onClick={() => toggleStarred(card)} className={`star ${card.isStarred ? 'starred' : ''}`}>
                      ⭐
                    </span>
                  </div>
                </div>
                <p className="card-content">{card.content}</p>
                <div className="card-footer">
                  <small>创建于: {new Date(card.createdAt).toLocaleString()}</small>
                  <div className="card-actions">
                    <button onClick={() => setEditingCard(card)}>编辑</button>
                    <button onClick={() => handleDeleteCard(card.id)}>删除</button>
                  </div>
                </div>
              </>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

export default CardManager;
```

## 4. 单元测试

```typescript
   * 获取收藏卡片
   * @returns 收藏卡片列表
   */
  getStarredCards(): Promise<Card[]>;
  
  /**
   * 根据标签获取卡片
   * @param tag 标签
   * @returns 匹配的卡片列表
   */
  getCardsByTag(tag: string): Promise<Card[]>;
}
```

## 2. 单元测试

CardService的单元测试已单独拆分为：
- [CardService API单元测试](card-service-api-test.md)

## 相关文档

- [AuthService API接口设计与单元测试](auth-service-api.md)
- [DeviceService API接口设计与单元测试](device-service-api.md)
- [EncryptionService API接口设计与单元测试](encryption-service-api.md)
- [SyncService API接口设计与单元测试](sync-service-api.md)

[返回API测试设计文档索引](../api-testing-design-index.md)