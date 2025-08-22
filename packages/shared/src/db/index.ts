// Dexie数据库实现 - 提供本地存储功能
import Dexie, { Table } from 'dexie';
import type { Document, AnyBlock, AppConfig, SyncStatus, DatabaseOperations } from '@cardmind/types';

// Dexie数据库类
export class CardMindDatabase extends Dexie {
  public documents!: Table<Document, string>;
  public blocks!: Table<any, string>; // 使用序列化后的块数据
  public config!: Table<AppConfig, string>;
  public syncStatus!: Table<SyncStatus, string>;

  constructor() {
    super('CardMindDatabase');
    
    // 定义数据库版本和表结构 - 适配序列化后的块类型
    this.version(3).stores({
      documents: 'id, title, createdAt, updatedAt, tags',
      blocks: 'id, type, parentId, createdAt, modifiedAt, isDeleted',
      config: '++id',
      syncStatus: '++id'
    });
  }
}

// 创建数据库实例
export const db = new CardMindDatabase();

// 数据库操作实现
export class DatabaseService implements DatabaseOperations {
  async createDocument(doc: Omit<Document, 'id' | 'createdAt' | 'updatedAt' | 'version'>): Promise<Document> {
    const now = new Date();
    const newDoc: Document = {
      ...doc,
      id: crypto.randomUUID(),
      createdAt: now,
      updatedAt: now,
      version: 1
    };

    await db.documents.add(newDoc);
    return newDoc;
  }

  async updateDocument(id: string, updates: Partial<Document>): Promise<Document> {
    const doc = await db.documents.get(id);
    if (!doc) throw new Error(`Document ${id} not found`);

    const updatedDoc: Document = {
      ...doc,
      ...updates,
      updatedAt: new Date(),
      version: doc.version + 1
    };

    await db.documents.put(updatedDoc);
    return updatedDoc;
  }

  async deleteDocument(id: string): Promise<void> {
    await db.documents.delete(id);
    // 同时删除相关的blocks
    await db.blocks.where('documentId').equals(id).delete();
  }

  async getDocument(id: string): Promise<Document | null> {
    return await db.documents.get(id) || null;
  }

  async getAllDocuments(): Promise<Document[]> {
    return await db.documents.orderBy('updatedAt').reverse().toArray();
  }

  async searchDocuments(query: string): Promise<Document[]> {
    const lowerQuery = query.toLowerCase();
    return await db.documents
      .filter(doc => 
        doc.title.toLowerCase().includes(lowerQuery)
      )
      .toArray();
  }

  // 使用新的继承式块类型操作方法
  async createBlock(block: Omit<any, 'id' | 'createdAt' | 'modifiedAt'>): Promise<any> {
    const now = new Date();
    const newBlock = {
      ...block,
      id: crypto.randomUUID(),
      createdAt: now,
      modifiedAt: now
    };

    await db.blocks.add(newBlock);
    return newBlock;
  }

  async updateBlock(id: string, updates: Partial<any>): Promise<any> {
    const block = await db.blocks.get(id);
    if (!block) throw new Error(`Block ${id} not found`);

    const updatedBlock = {
      ...block,
      ...updates,
      modifiedAt: new Date()
    };

    await db.blocks.put(updatedBlock);
    return updatedBlock;
  }

  async deleteBlock(id: string): Promise<void> {
    // 软删除 - 标记为已删除
    await this.updateBlock(id, { isDeleted: true });
  }

  async getBlock(id: string): Promise<any | null> {
    const block = await db.blocks.get(id);
    return block && !block.isDeleted ? block : null;
  }

  async getChildBlocks(parentId: string): Promise<any[]> {
    return await db.blocks
      .where('parentId')
      .equals(parentId)
      .filter(block => !block.isDeleted)
      .toArray();
  }
}

// 导出数据库服务实例
export const databaseService = new DatabaseService();