import { db } from './index';
import { Block, DocBlock, TextBlock, MediaBlock, CodeBlock } from '../types/block-inheritance';
import { serializeBlock, deserializeBlock } from '../types/block-inheritance';

// 数据库操作封装
export const Database = {
  // 创建块
  create: async (block: Block): Promise<string | number> => {
    return db.blocks.add(block);
  },

  // 更新块
  update: async (block: Block): Promise<string | number> => {
    return db.blocks.put({ 
      ...block, 
      modifiedAt: new Date() 
    });
  },

  // 批量更新块
  batchUpdate: async (blocks: Block[]): Promise<string | number> => {
    const result = await db.blocks.bulkPut(
      blocks.map((b: Block) => ({ ...b, modifiedAt: new Date() }))
    );
    return result;
  },

  // 获取单个块
  get: async (id: string): Promise<Block | undefined> => {
    return db.blocks.get(id);
  },

  // 获取所有块
  getAllBlocks: async (): Promise<Block[]> => {
    return db.blocks
      .filter((block: Block) => !block.isDeleted)
      .toArray();
  },

  // 获取子块列表
  getChildren: async (parentId: string): Promise<Block[]> => {
    return db.blocks
      .where('parentId').equals(parentId)
      .and((block: Block) => !block.isDeleted)
      .toArray();
  },

  // 保存快照
  saveSnapshot: async (update: Uint8Array): Promise<string | number> => {
    return db.snapshots.add({ 
      id: crypto.randomUUID(), 
      ts: Date.now(), 
      update 
    });
  },

  // 获取快照列表
  listSnapshots: async (): Promise<{id: string; ts: number; update: Uint8Array}[]> => {
    return db.snapshots
      .orderBy('ts')
      .reverse()
      .toArray();
  },

  // 获取单个快照
  getSnapshot: async (id: string): Promise<{id: string; ts: number; update: Uint8Array} | undefined> => {
    return db.snapshots.get(id);
  }
};
