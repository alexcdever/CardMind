// 核心类型定义 - 为整个monorepo提供共享的类型

// 文档块类型
export interface Block {
  id: string;
  type: 'text' | 'image' | 'code' | 'table' | 'todo';
  content: string;
  metadata?: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
  position: Position;
}

// 位置信息
export interface Position {
  x: number;
  y: number;
  width?: number;
  height?: number;
}

// 文档类型
export interface Document {
  id: string;
  title: string;
  blocks: Block[];
  tags: string[];
  createdAt: Date;
  updatedAt: Date;
  version: number;
}

// 同步状态
export interface SyncStatus {
  isOnline: boolean;
  lastSyncTime?: Date;
  pendingChanges: number;
}

// 协作用户
export interface Collaborator {
  id: string;
  name: string;
  color: string;
  cursor?: Position;
  lastActive: Date;
}

// 应用配置
export interface AppConfig {
  theme: 'light' | 'dark' | 'auto';
  language: string;
  autoSave: boolean;
  syncInterval: number;
}

// 数据库操作接口
export interface DatabaseOperations {
  createDocument(doc: Omit<Document, 'id' | 'createdAt' | 'updatedAt' | 'version'>): Promise<Document>;
  updateDocument(id: string, updates: Partial<Document>): Promise<Document>;
  deleteDocument(id: string): Promise<void>;
  getDocument(id: string): Promise<Document | null>;
  getAllDocuments(): Promise<Document[]>;
  searchDocuments(query: string): Promise<Document[]>;
}

// 事件类型
export type AppEvent = 
  | { type: 'document_created'; documentId: string }
  | { type: 'document_updated'; documentId: string }
  | { type: 'document_deleted'; documentId: string }
  | { type: 'sync_started' }
  | { type: 'sync_completed' }
  | { type: 'collaborator_joined'; userId: string }
  | { type: 'collaborator_left'; userId: string };