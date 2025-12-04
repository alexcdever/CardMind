/**
 * 卡片服务
 * 处理卡片的CRUD操作，集成本地存储和同步功能
 */

import { Card } from '../types/card.types'
import useCardStore from '../stores/cardStore'
import useSyncStore from '../stores/syncStore'

// 定义卡片服务接口
export interface CardServiceInterface {
  // 初始化
  initialize(networkId: string, deviceId: string): Promise<void>;
  
  // 卡片CRUD操作
  getAllCards(): Promise<Card[]>;
  getCardById(id: string): Promise<Card | null>;
  createCard(cardData: Partial<Card>): Promise<Card>;
  updateCard(cardData: Card): Promise<Card>;
  deleteCard(id: string): Promise<void>;
  restoreCard(id: string): Promise<Card>;
  
  // 软删除管理
  getDeletedCards(): Promise<Card[]>;
  
  // 搜索和筛选
  searchCards(query: string): Promise<Card[]>;
  filterCardsByDateRange(startDate: Date, endDate: Date): Promise<Card[]>;
  
  // 批量操作
  batchDeleteCard(ids: string[]): Promise<void>;
  batchRestoreCard(ids: string[]): Promise<Card[]>;
}

class CardService implements CardServiceInterface {
  /**
   * 初始化卡片服务
   */
  async initialize(_networkId: string, _deviceId: string): Promise<void> {
    try {
      console.log('[CardService] 卡片服务初始化完成');
    } catch (error) {
      console.error('[CardService] 初始化失败:', error);
      throw new Error('卡片服务初始化失败');
    }
  }

  /**
   * 获取所有卡片
   */
  async getAllCards(): Promise<Card[]> {
    try {
      // 从卡片状态管理获取卡片
      await useCardStore.getState().fetchAllCards();
      return useCardStore.getState().cards;
    } catch (error) {
      console.error('[CardService] 获取所有卡片失败:', error);
      throw new Error('获取所有卡片失败');
    }
  }

  /**
   * 根据ID获取卡片
   */
  async getCardById(id: string): Promise<Card | null> {
    try {
      const cards = await this.getAllCards();
      return cards.find(card => card.id === id) || null;
    } catch (error) {
      console.error('[CardService] 根据ID获取卡片失败:', error);
      throw new Error('根据ID获取卡片失败');
    }
  }

  /**
   * 创建卡片
   */
  async createCard(cardData: Partial<Card>): Promise<Card> {
    try {
      const newCard = await useCardStore.getState().createCard(cardData);
      
      // 如果不是离线模式，更新同步状态
      if (useSyncStore.getState().isOnline) {
        useSyncStore.getState().setSyncStatus('syncing');
      }
      
      return newCard;
    } catch (error) {
      console.error('[CardService] 创建卡片失败:', error);
      throw new Error('创建卡片失败');
    }
  }

  /**
   * 更新卡片
   */
  async updateCard(cardData: Card): Promise<Card> {
    try {
      const updatedCard = await useCardStore.getState().updateCard(cardData);
      
      // 如果不是离线模式，更新同步状态
      if (useSyncStore.getState().isOnline) {
        useSyncStore.getState().setSyncStatus('syncing');
      }
      
      return updatedCard;
    } catch (error) {
      console.error('[CardService] 更新卡片失败:', error);
      throw new Error('更新卡片失败');
    }
  }

  /**
   * 删除卡片（软删除）
   */
  async deleteCard(id: string): Promise<void> {
    try {
      await useCardStore.getState().deleteCard(id);
      
      // 如果不是离线模式，更新同步状态
      if (useSyncStore.getState().isOnline) {
        useSyncStore.getState().setSyncStatus('syncing');
      }
    } catch (error) {
      console.error('[CardService] 删除卡片失败:', error);
      throw new Error('删除卡片失败');
    }
  }

  /**
   * 恢复卡片
   */
  async restoreCard(id: string): Promise<Card> {
    try {
      await useCardStore.getState().restoreCard(id);
      
      // 如果不是离线模式，更新同步状态
      if (useSyncStore.getState().isOnline) {
        useSyncStore.getState().setSyncStatus('syncing');
      }
      
      // 获取恢复后的卡片
      const restoredCard = await this.getCardById(id);
      if (!restoredCard) {
        throw new Error('恢复卡片失败，卡片不存在');
      }
      
      return restoredCard;
    } catch (error) {
      console.error('[CardService] 恢复卡片失败:', error);
      throw new Error('恢复卡片失败');
    }
  }

  /**
   * 获取已删除的卡片
   */
  async getDeletedCards(): Promise<Card[]> {
    try {
      await useCardStore.getState().fetchDeletedCards();
      return useCardStore.getState().deletedCards;
    } catch (error) {
      console.error('[CardService] 获取已删除卡片失败:', error);
      throw new Error('获取已删除卡片失败');
    }
  }

  /**
   * 搜索卡片
   */
  async searchCards(query: string): Promise<Card[]> {
    try {
      const allCards = await this.getAllCards();
      
      if (!query.trim()) {
        return allCards;
      }
      
      const lowerQuery = query.toLowerCase();
      return allCards.filter(card => 
        card.title.toLowerCase().includes(lowerQuery) ||
        card.content.toLowerCase().includes(lowerQuery)
      );
    } catch (error) {
      console.error('[CardService] 搜索卡片失败:', error);
      throw new Error('搜索卡片失败');
    }
  }

  /**
   * 根据日期范围筛选卡片
   */
  async filterCardsByDateRange(startDate: Date, endDate: Date): Promise<Card[]> {
    try {
      const allCards = await this.getAllCards();
      
      const startTimestamp = startDate.getTime();
      const endTimestamp = endDate.getTime();
      
      return allCards.filter(card => 
        card.createdAt >= startTimestamp && card.createdAt <= endTimestamp
      );
    } catch (error) {
      console.error('[CardService] 筛选卡片失败:', error);
      throw new Error('筛选卡片失败');
    }
  }

  /**
   * 批量删除卡片
   */
  async batchDeleteCard(ids: string[]): Promise<void> {
    try {
      for (const id of ids) {
        await this.deleteCard(id);
      }
      
      // 如果不是离线模式，更新同步状态
      if (useSyncStore.getState().isOnline) {
        useSyncStore.getState().setSyncStatus('syncing');
      }
    } catch (error) {
      console.error('[CardService] 批量删除卡片失败:', error);
      throw new Error('批量删除卡片失败');
    }
  }

  /**
   * 批量恢复卡片
   */
  async batchRestoreCard(ids: string[]): Promise<Card[]> {
    try {
      const restoredCards: Card[] = [];
      
      for (const id of ids) {
        const restoredCard = await this.restoreCard(id);
        restoredCards.push(restoredCard);
      }
      
      // 如果不是离线模式，更新同步状态
      if (useSyncStore.getState().isOnline) {
        useSyncStore.getState().setSyncStatus('syncing');
      }
      
      return restoredCards;
    } catch (error) {
      console.error('[CardService] 批量恢复卡片失败:', error);
      throw new Error('批量恢复卡片失败');
    }
  }
}

// 导出单例实例
export default new CardService();
