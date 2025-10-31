/**
 * 卡片管理服务
 * 提供卡片相关的业务逻辑和数据操作
 * 使用双数据源架构：IndexedDB + Yjs CRDT
 */

import { Card } from '@/types/card.types';
import { MinimalCardStorage, createMinimalCardStorage } from './minimalCardStorage';
import { v4 as uuidv4 } from 'uuid';

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
  
  // 同步操作
  syncFromYjsToIndexedDB(): Promise<void>;
  syncAllCardsFromYjs(): Promise<Card[]>;
  createYjsDocForExistingCard(cardId: string): Promise<void>;
}

class CardService implements CardServiceInterface {
  private storage: MinimalCardStorage | null = null;

  /**
   * 初始化卡片服务
   */
  async initialize(networkId: string, deviceId: string): Promise<void> {
    try {
      this.storage = createMinimalCardStorage(networkId, deviceId);
      await this.storage.initialize();
      console.log('[CardService] 卡片服务初始化完成');
    } catch (error) {
      console.error('[CardService] 初始化失败:', error);
      throw new Error('卡片服务初始化失败');
    }
  }

  /**
   * 确保存储已初始化
   */
  private ensureStorage(): MinimalCardStorage {
    if (!this.storage) {
      throw new Error('卡片服务未初始化，请先调用initialize方法');
    }
    return this.storage;
  }

  /**
   * 获取所有未删除的卡片
   */
  async getAllCards(): Promise<Card[]> {
    try {
      const storage = this.ensureStorage();
      return await storage.getAllCards();
    } catch (error) {
      console.error('获取卡片失败:', error);
      throw new Error('获取卡片失败');
    }
  }

  /**
   * 根据ID获取卡片
   */
  async getCardById(id: string): Promise<Card | null> {
    try {
      const storage = this.ensureStorage();
      return await storage.getCardById(id);
    } catch (error) {
      console.error('获取卡片失败:', error);
      throw new Error('获取卡片失败');
    }
  }

  /**
   * 创建新卡片
   */
  async createCard(cardData: Partial<Card>): Promise<Card> {
    try {
      const storage = this.ensureStorage();
      return await storage.createCard(cardData);
    } catch (error) {
      console.error('创建卡片失败:', error);
      throw new Error('创建卡片失败');
    }
  }

  /**
   * 更新卡片
   */
  async updateCard(cardData: Card): Promise<Card> {
    try {
      const storage = this.ensureStorage();
      return await storage.updateCard(cardData);
    } catch (error) {
      console.error('更新卡片失败:', error);
      throw new Error('更新卡片失败');
    }
  }

  /**
   * 删除卡片（软删除）
   */
  async deleteCard(id: string): Promise<void> {
    try {
      const storage = this.ensureStorage();
      await storage.deleteCard(id);
    } catch (error) {
      console.error('删除卡片失败:', error);
      throw new Error('删除卡片失败');
    }
  }

  /**
   * 恢复已删除的卡片
   */
  async restoreCard(id: string): Promise<Card> {
    try {
      const storage = this.ensureStorage();
      return await storage.restoreCard(id);
    } catch (error) {
      console.error('恢复卡片失败:', error);
      throw new Error('恢复卡片失败');
    }
  }

  /**
   * 获取所有已删除的卡片
   */
  async getDeletedCards(): Promise<Card[]> {
    try {
      const storage = this.ensureStorage();
      return await storage.getDeletedCards();
    } catch (error) {
      console.error('获取已删除卡片失败:', error);
      throw new Error('获取已删除卡片失败');
    }
  }

  /**
   * 搜索卡片（按标题和内容）
   */
  async searchCards(query: string): Promise<Card[]> {
    try {
      const cards = await this.getAllCards();
      const searchTerm = query.toLowerCase();
      
      return cards.filter(card => 
        card.title.toLowerCase().includes(searchTerm) ||
        card.content.toLowerCase().includes(searchTerm)
      );
    } catch (error) {
      console.error('搜索卡片失败:', error);
      throw new Error('搜索卡片失败');
    }
  }

  /**
   * 按日期范围筛选卡片
   */
  async filterCardsByDateRange(startDate: Date, endDate: Date): Promise<Card[]> {
    try {
      const cards = await this.getAllCards();
      const startTime = startDate.getTime();
      const endTime = endDate.getTime();
      
      return cards.filter(card => {
        const cardTime = card.createdAt;
        return cardTime >= startTime && cardTime <= endTime;
      });
    } catch (error) {
      console.error('按日期筛选卡片失败:', error);
      throw new Error('按日期筛选卡片失败');
    }
  }

  /**
   * 批量删除卡片
   */
  async batchDeleteCard(ids: string[]): Promise<void> {
    try {
      const storage = this.ensureStorage();
      
      // 逐个删除卡片
      for (const id of ids) {
        await storage.deleteCard(id);
      }
    } catch (error) {
      console.error('批量删除卡片失败:', error);
      throw new Error('批量删除卡片失败');
    }
  }

  /**
   * 批量恢复卡片
   */
  async batchRestoreCard(ids: string[]): Promise<Card[]> {
    try {
      const storage = this.ensureStorage();
      const restoredCards: Card[] = [];
      
      // 逐个恢复卡片
      for (const id of ids) {
        const restoredCard = await storage.restoreCard(id);
        restoredCards.push(restoredCard);
      }
      
      return restoredCards;
    } catch (error) {
      console.error('批量恢复卡片失败:', error);
      throw new Error('批量恢复卡片失败');
    }
  }

  /**
   * 从Yjs同步数据到IndexedDB
   */
  async syncFromYjsToIndexedDB(): Promise<void> {
    try {
      const storage = this.ensureStorage();
      await storage.syncFromYjsToIndexedDB();
      console.log('[CardService] Yjs到IndexedDB同步完成');
    } catch (error) {
      console.error('[CardService] Yjs同步失败:', error);
      throw new Error('Yjs同步失败');
    }
  }

  /**
   * 同步所有卡片从Yjs（批量操作）
   */
  async syncAllCardsFromYjs(): Promise<Card[]> {
    try {
      const storage = this.ensureStorage();
      const cards = await storage.syncAllCardsFromYjs();
      console.log('[CardService] 从Yjs同步所有卡片完成，数量:', cards.length);
      return cards;
    } catch (error) {
      console.error('[CardService] 从Yjs同步所有卡片失败:', error);
      throw new Error('从Yjs同步所有卡片失败');
    }
  }

  /**
   * 为已有卡片创建Yjs文档
   */
  async createYjsDocForExistingCard(cardId: string): Promise<void> {
    try {
      const storage = this.ensureStorage();
      await storage.createYjsDocForExistingCard(cardId);
      console.log('[CardService] 为已有卡片创建Yjs文档完成:', cardId);
    } catch (error) {
      console.error('[CardService] 为已有卡片创建Yjs文档失败:', error);
      throw new Error('为已有卡片创建Yjs文档失败');
    }
  }
}

// 导出单例实例
export default new CardService();