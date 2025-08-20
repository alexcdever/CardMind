// Dexie数据库实现 - 提供本地存储功能
import Dexie, { Table } from 'dexie';
import type { Document, Block, AppConfig, SyncStatus, DatabaseOperations } from '@cardmind/types';

// Dexie数据库类
export class CardMindDatabase extends Dexie {
  public documents!: Table<Document, string>;
  public blocks!: Table<Block, string>;
  public config!: Table<AppConfig, string>;
  public syncStatus!: Table<SyncStatus, string>;

  constructor() {
    super('CardMindDatabase');
    
    // 定义数据库版本和表结构
    this.version(1).stores({
      documents: 'id, title, createdAt, updatedAt, tags',
      blocks: 'id, type, createdAt, updatedAt',
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
        doc.title.toLowerCase().includes(lowerQuery) ||
        (doc.blocks && doc.blocks.some(block => 
          block.content.toLowerCase().includes(lowerQuery)
        ))
      )
      .toArray();
  }
}

// 导出数据库服务实例
export const databaseService = new DatabaseService();