/**
 * 极简卡片存储服务
 * 实现双数据源架构：IndexedDB + Yjs CRDT
 * 提供卡片相关的业务逻辑和数据操作
 */

import Dexie, { Table } from 'dexie';
import * as Y from 'yjs';
import { IndexeddbPersistence } from 'y-indexeddb';
import { Card } from '@/types/card.types';
import { v4 as uuidv4 } from 'uuid';

// IndexedDB数据库接口
export interface CardDatabase extends Dexie {
  cards: Table<Card, string>;
  networks: Table<{ id: string; name: string; createdAt: number }, string>;
  devices: Table<{ id: string; name: string; networkId: string; createdAt: number }, string>;
}

// Yjs文档管理器
export class YjsDocumentManager {
  private docs: Map<string, { doc: Y.Doc; persistence: IndexeddbPersistence }> = new Map();

  /**
   * 获取或创建Yjs文档
   */
  async getOrCreateDoc(docId: string): Promise<{ doc: Y.Doc; persistence: IndexeddbPersistence }> {
    if (this.docs.has(docId)) {
      return this.docs.get(docId)!;
    }

    const doc = new Y.Doc();
    const persistence = new IndexeddbPersistence(docId, doc);
    
    // 等待持久化初始化完成
    await new Promise<void>((resolve) => {
      persistence.on('synced', () => {
        resolve();
      });
      
      // 如果已经同步过，直接resolve
      setTimeout(() => resolve(), 100);
    });

    const docEntry = { doc, persistence };
    this.docs.set(docId, docEntry);
    return docEntry;
  }

  /**
   * 销毁文档
   */
  async destroyDoc(docId: string): Promise<void> {
    const docEntry = this.docs.get(docId);
    if (docEntry) {
      docEntry.persistence.destroy();
      docEntry.doc.destroy();
      this.docs.delete(docId);
    }
  }

  /**
   * 获取所有文档ID
   */
  getAllDocIds(): string[] {
    return Array.from(this.docs.keys());
  }
}

// 极简卡片存储类
export class MinimalCardStorage {
  private db: CardDatabase;
  private yjsManager: YjsDocumentManager;
  private networkId: string;
  private deviceId: string;

  constructor(networkId: string, deviceId: string) {
    this.networkId = networkId;
    this.deviceId = deviceId;
    this.yjsManager = new YjsDocumentManager();
    
    // 初始化IndexedDB
    this.db = new Dexie(`CardMind_${networkId}`) as CardDatabase;
    this.db.version(1).stores({
      cards: 'id, title, content, createdAt, updatedAt, isDeleted, lastModifiedDeviceId',
      networks: 'id, name, createdAt',
      devices: 'id, name, networkId, createdAt'
    });
  }

  /**
   * 初始化存储
   */
  async initialize(): Promise<void> {
    try {
      // 确保数据库已打开
      await this.db.open();
      
      // 初始化网络和设备记录
      await this.initializeNetworkAndDevice();
      
      console.log('[MinimalCardStorage] 存储初始化完成');
    } catch (error) {
      console.error('[MinimalCardStorage] 存储初始化失败:', error);
      throw new Error('存储初始化失败');
    }
  }

  /**
   * 初始化网络和设备记录
   */
  private async initializeNetworkAndDevice(): Promise<void> {
    // 检查网络是否存在
    const existingNetwork = await this.db.networks.get(this.networkId);
    if (!existingNetwork) {
      await this.db.networks.add({
        id: this.networkId,
        name: `Network_${this.networkId.substring(0, 8)}`,
        createdAt: Date.now()
      });
    }

    // 检查设备是否存在
    const existingDevice = await this.db.devices.get(this.deviceId);
    if (!existingDevice) {
      await this.db.devices.add({
        id: this.deviceId,
        name: `Device_${this.deviceId.substring(0, 8)}`,
        networkId: this.networkId,
        createdAt: Date.now()
      });
    }
  }

  /**
   * 创建新卡片
   */
  async createCard(cardData: Partial<Card>): Promise<Card> {
    const now = Date.now();
    const newCard: Card = {
      id: uuidv4(),
      title: cardData.title || '',
      content: cardData.content || '',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      lastModifiedDeviceId: this.deviceId
    };

    try {
      // 1. 保存到IndexedDB
      await this.db.cards.add(newCard);
      
      // 2. 创建Yjs文档并同步
      await this.syncCardToYjs(newCard);
      
      console.log('[MinimalCardStorage] 卡片创建完成:', newCard.id);
      return newCard;
    } catch (error) {
      console.error('[MinimalCardStorage] 创建卡片失败:', error);
      throw new Error('创建卡片失败');
    }
  }

  /**
   * 更新卡片
   */
  async updateCard(cardData: Card): Promise<Card> {
    const updatedCard: Card = {
      ...cardData,
      updatedAt: Date.now(),
      lastModifiedDeviceId: this.deviceId
    };

    try {
      // 1. 更新IndexedDB
      const existingCard = await this.db.cards.get(cardData.id);
      if (!existingCard) {
        throw new Error('卡片不存在');
      }
      
      await this.db.cards.put(updatedCard);
      
      // 2. 同步到Yjs
      await this.syncCardToYjs(updatedCard);
      
      console.log('[MinimalCardStorage] 卡片更新完成:', updatedCard.id);
      return updatedCard;
    } catch (error) {
      console.error('[MinimalCardStorage] 更新卡片失败:', error);
      throw new Error('更新卡片失败');
    }
  }

  /**
   * 删除卡片（软删除）
   */
  async deleteCard(id: string): Promise<void> {
    try {
      const existingCard = await this.db.cards.get(id);
      if (!existingCard) {
        throw new Error('卡片不存在');
      }

      const deletedCard: Card = {
        ...existingCard,
        isDeleted: true,
        deletedAt: Date.now(),
        updatedAt: Date.now(),
        lastModifiedDeviceId: this.deviceId
      };

      // 1. 更新IndexedDB
      await this.db.cards.put(deletedCard);
      
      // 2. 同步到Yjs
      await this.syncCardToYjs(deletedCard);
      
      console.log('[MinimalCardStorage] 卡片删除完成:', id);
    } catch (error) {
      console.error('[MinimalCardStorage] 删除卡片失败:', error);
      throw new Error('删除卡片失败');
    }
  }

  /**
   * 获取所有未删除的卡片
   */
  async getAllCards(): Promise<Card[]> {
    try {
      const cards = await this.db.cards
        .where('isDeleted')
        .equals(0)
        .toArray();
      
      console.log('[MinimalCardStorage] 获取所有卡片:', cards.length);
      return cards;
    } catch (error) {
      console.error('[MinimalCardStorage] 获取卡片失败:', error);
      throw new Error('获取卡片失败');
    }
  }

  /**
   * 根据ID获取卡片
   */
  async getCardById(id: string): Promise<Card | null> {
    try {
      const card = await this.db.cards.get(id);
      return card || null;
    } catch (error) {
      console.error('[MinimalCardStorage] 获取卡片失败:', error);
      throw new Error('获取卡片失败');
    }
  }

  /**
   * 获取所有已删除的卡片
   */
  async getDeletedCards(): Promise<Card[]> {
    try {
      const cards = await this.db.cards
        .where('isDeleted')
        .equals(1)
        .toArray();
      
      return cards;
    } catch (error) {
      console.error('[MinimalCardStorage] 获取已删除卡片失败:', error);
      throw new Error('获取已删除卡片失败');
    }
  }

  /**
   * 恢复已删除的卡片
   */
  async restoreCard(id: string): Promise<Card> {
    try {
      const existingCard = await this.db.cards.get(id);
      if (!existingCard) {
        throw new Error('卡片不存在');
      }

      if (!existingCard.isDeleted) {
        throw new Error('卡片未被删除');
      }

      const restoredCard: Card = {
        ...existingCard,
        isDeleted: false,
        deletedAt: undefined,
        updatedAt: Date.now(),
        lastModifiedDeviceId: this.deviceId
      };

      // 1. 更新IndexedDB
      await this.db.cards.put(restoredCard);
      
      // 2. 同步到Yjs
      await this.syncCardToYjs(restoredCard);
      
      console.log('[MinimalCardStorage] 卡片恢复完成:', id);
      return restoredCard;
    } catch (error) {
      console.error('[MinimalCardStorage] 恢复卡片失败:', error);
      throw new Error('恢复卡片失败');
    }
  }

  /**
   * 同步卡片到Yjs
   */
  private async syncCardToYjs(card: Card): Promise<void> {
    try {
      const docId = `card-${card.id}`;
      const { doc } = await this.yjsManager.getOrCreateDoc(docId);
      
      // 使用Y.Map存储卡片数据
      const yMap = doc.getMap('card');
      
      // 转换卡片数据为可序列化格式
      const cardData = {
        id: card.id,
        title: card.title,
        content: card.content,
        createdAt: card.createdAt,
        updatedAt: card.updatedAt,
        isDeleted: card.isDeleted,
        deletedAt: card.deletedAt,
        lastModifiedDeviceId: card.lastModifiedDeviceId
      };
      
      // 更新Yjs文档
      Object.entries(cardData).forEach(([key, value]) => {
        yMap.set(key, value);
      });
      
      console.log('[MinimalCardStorage] 同步到Yjs完成:', card.id);
    } catch (error) {
      console.error('[MinimalCardStorage] 同步到Yjs失败:', error);
      // 不抛出错误，因为Yjs同步失败不应该影响主流程
    }
  }

  /**
   * 从Yjs同步数据到IndexedDB
   */
  async syncFromYjsToIndexedDB(): Promise<void> {
    try {
      const allDocIds = this.yjsManager.getAllDocIds();
      let syncCount = 0;
      
      for (const docId of allDocIds) {
        if (!docId.startsWith('card-')) continue;
        
        const { doc } = await this.yjsManager.getOrCreateDoc(docId);
        const yMap = doc.getMap('card');
        
        if (yMap.size === 0) continue;
        
        // 从Yjs获取卡片数据
        const cardData: Partial<Card> = {};
        yMap.forEach((value, key) => {
          (cardData as any)[key] = value;
        });
        
        if (cardData.id) {
          // 检查本地是否存在
          const existingCard = await this.db.cards.get(cardData.id);
          
          if (!existingCard || cardData.updatedAt! > existingCard.updatedAt) {
            // 更新IndexedDB
            await this.db.cards.put(cardData as Card);
            syncCount++;
            console.log('[MinimalCardStorage] 从Yjs同步卡片:', cardData.id);
          }
        }
      }
      
      console.log(`[MinimalCardStorage] Yjs到IndexedDB同步完成，共同步${syncCount}张卡片`);
    } catch (error) {
      console.error('[MinimalCardStorage] 从Yjs同步失败:', error);
      throw new Error('从Yjs同步数据失败');
    }
  }

  /**
   * 同步所有卡片从Yjs（批量操作）
   */
  async syncAllCardsFromYjs(): Promise<Card[]> {
    await this.syncFromYjsToIndexedDB();
    return this.getAllCards();
  }

  /**
   * 为已有卡片创建Yjs文档
   */
  async createYjsDocForExistingCard(cardId: string): Promise<void> {
    try {
      const card = await this.db.cards.get(cardId);
      if (card) {
        await this.syncCardToYjs(card);
      }
    } catch (error) {
      console.error('[MinimalCardStorage] 为已有卡片创建Yjs文档失败:', error);
      throw new Error('为已有卡片创建Yjs文档失败');
    }
  }

  /**
   * 清理资源
   */
  async cleanup(): Promise<void> {
    try {
      // 销毁所有Yjs文档
      const allDocIds = this.yjsManager.getAllDocIds();
      for (const docId of allDocIds) {
        await this.yjsManager.destroyDoc(docId);
      }
      
      // 关闭数据库连接
      this.db.close();
      
      console.log('[MinimalCardStorage] 资源清理完成');
    } catch (error) {
      console.error('[MinimalCardStorage] 清理资源失败:', error);
      throw new Error('清理资源失败');
    }
  }
}

// 导出单例工厂函数
export const createMinimalCardStorage = (networkId: string, deviceId: string): MinimalCardStorage => {
  return new MinimalCardStorage(networkId, deviceId);
};

export default MinimalCardStorage;