import Dexie from 'dexie';
import { UnifiedBlock } from '../types/block';

const isRN = typeof navigator !== 'undefined' && navigator.product === 'ReactNative';
if (isRN) require('indexeddbshim')(global, { checkOrigin: false, win: global });

class NotesDatabase extends Dexie {
  blocks!: Dexie.Table<UnifiedBlock, string>;
  snapshots!: Dexie.Table<{ id: string; ts: number; update: Uint8Array }, string>;

  constructor() {
    super('NotesApp');
    
    // 数据库版本和表结构定义
    this.version(3).stores({
      blocks: 'id, parentId, modifiedAt, isDeleted',  // 块表索引
      snapshots: '++id, ts'  // 快照表索引
    });
  }
}

// 导出数据库实例
export const db = new NotesDatabase();
