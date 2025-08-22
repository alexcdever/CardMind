// 使用继承方式的数据库服务 - 提供本地存储功能
import Dexie, { Table } from 'dexie';
import type { Document, AppConfig, SyncStatus, DatabaseOperations, AnyBlock, Block } from '@cardmind/types';
import { serializeBlock, deserializeBlock } from '@cardmind/types';

// 定义用于存储的块类型
interface SerializedBlock {
  id: string;
  type: string;
  parentId: string | null;
  childrenIds: string[];
  createdAt: Date;
  modifiedAt: Date;
  isDeleted: boolean;
  // 其他特定于类型的属性将作为键值对存储
  [key: string]: any;
}

// Dexie数据库类
export class CardMindDatabase extends Dexie {
  public documents!: Table<Document, string>;
  public blocks!: Table<SerializedBlock, string>; // 使用序列化后的块类型
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
export class DatabaseServiceInheritance implements DatabaseOperations {
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

  // 使用继承方式的块操作方法
  async createBlock(block: Omit<AnyBlock, 'id' | 'createdAt' | 'modifiedAt'>): Promise<AnyBlock> {
    const now = new Date();
    
    // 创建序列化块数据
    const blockData = block as any;
    let serializedBlock: any = {
      id: crypto.randomUUID(),
      parentId: blockData.parentId || null,
      childrenIds: [],
      createdAt: now,
      modifiedAt: now,
      isDeleted: false
    };
    
    // 根据块类型设置特定属性
    if ('title' in blockData && 'content' in blockData && !('code' in blockData)) {
      // DocBlock
      serializedBlock.type = 'doc';
      serializedBlock.title = blockData.title;
      serializedBlock.content = blockData.content;
    } else if ('content' in blockData && !('code' in blockData) && !('title' in blockData)) {
      // TextBlock
      serializedBlock.type = 'text';
      serializedBlock.content = blockData.content;
    } else if ('code' in blockData && 'language' in blockData) {
      // CodeBlock
      serializedBlock.type = 'code';
      serializedBlock.code = blockData.code;
      serializedBlock.language = blockData.language;
    } else if ('filePath' in blockData) {
      // MediaBlock
      serializedBlock.type = 'media';
      serializedBlock.filePath = blockData.filePath;
      serializedBlock.fileHash = blockData.fileHash || '';
      serializedBlock.fileName = blockData.fileName || '';
      serializedBlock.thumbnailPath = blockData.thumbnailPath || '';
    } else {
      // 默认创建一个TextBlock
      serializedBlock.type = 'text';
      serializedBlock.content = '';
    }
    
    await db.blocks.add(serializedBlock);
    return deserializeBlock(serializedBlock) as AnyBlock;
  }

  async updateBlock(id: string, updates: Partial<AnyBlock>): Promise<AnyBlock> {
    const block = await db.blocks.get(id);
    if (!block) throw new Error(`Block ${id} not found`);

    // 反序列化块以进行更新
    let updatedBlock = deserializeBlock(block);
    
    // 应用更新
    Object.assign(updatedBlock, updates);
    
    // 更新修改时间
    updatedBlock.modifiedAt = new Date();

    // 序列化更新后的块以存储到数据库
    const serializedBlock = serializeBlock(updatedBlock);
    
    await db.blocks.put(serializedBlock);
    return updatedBlock as AnyBlock;
  }

  async deleteBlock(id: string): Promise<void> {
    // 软删除 - 标记为已删除
    const block = await db.blocks.get(id);
    if (!block) throw new Error(`Block ${id} not found`);
    
    const updatedBlock = deserializeBlock(block);
    updatedBlock.isDeleted = true;
    updatedBlock.modifiedAt = new Date();
    
    const serializedBlock = serializeBlock(updatedBlock);
    await db.blocks.put(serializedBlock);
  }

  async getBlock(id: string): Promise<AnyBlock | null> {
    const block = await db.blocks.get(id);
    if (!block) return null;
    
    // 检查是否已删除
    if (block.isDeleted) return null;
    
    // 反序列化块
    return deserializeBlock(block) as AnyBlock;
  }

  async getChildBlocks(parentId: string): Promise<AnyBlock[]> {
    const blocks = await db.blocks
      .where('parentId')
      .equals(parentId)
      .filter(block => !block.isDeleted)
      .toArray();
    
    // 反序列化块
    return blocks.map(block => deserializeBlock(block) as AnyBlock);
  }
}

// 导出数据库服务实例
export const databaseServiceInheritance = new DatabaseServiceInheritance();