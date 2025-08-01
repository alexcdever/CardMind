import { db } from './index';
import { UnifiedBlock } from '../types/block';

// 数据库操作封装
export const Database = {
  // 创建块
  create: async (block: UnifiedBlock) => {
    return db.blocks.add(block);
  },

  // 更新块
  update: async (block: UnifiedBlock) => {
    return db.blocks.put({ 
      ...block, 
      modifiedAt: new Date() 
    });
  },

  // 批量更新块
  batchUpdate: async (blocks: UnifiedBlock[]) => {
    return db.blocks.bulkPut(
      blocks.map(b => ({ ...b, modifiedAt: new Date() }))
    );
  },

  // 获取单个块
  get: async (id: string) => {
    return db.blocks.get(id);
  },

  // 获取所有块
  getAllBlocks: async () => {
    return db.blocks
      .filter(block => !block.isDeleted)
      .toArray();
  },

  // 获取子块列表
  getChildren: async (parentId: string) => {
    return db.blocks
      .where('parentId').equals(parentId)
      .and(block => !block.isDeleted)
      .toArray();
  },

  // 保存快照
  saveSnapshot: async (update: Uint8Array) => {
    return db.snapshots.add({ 
      id: crypto.randomUUID(), 
      ts: Date.now(), 
      update 
    });
  },

  // 获取快照列表
  listSnapshots: async () => {
    return db.snapshots
      .orderBy('ts')
      .reverse()
      .toArray();
  },

  // 获取单个快照
  getSnapshot: async (id: string) => {
    return db.snapshots.get(id);
  }
};
