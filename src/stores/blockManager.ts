import { create } from 'zustand';
import { yDocManager } from './yDocManager';
import { UnifiedBlock } from '../types/block';
import { Database } from '../db/operations'; // 导入数据库操作

export interface BlockManagerState {
  // 当前打开的块数据
  currentBlock: UnifiedBlock | null;
  
  // 所有块列表
  blocks: UnifiedBlock[];

  // 状态锁 - 防止并发修改
  isOpening: boolean;

  // 查询方法
  getBlock: (id: string) => Promise<UnifiedBlock | null>;
  getAllBlocks: () => Promise<UnifiedBlock[]>;

  // 增删改方法
  createBlock: (block: Omit<UnifiedBlock, 'id'>) => Promise<string>;
  updateBlock: (block: UnifiedBlock) => Promise<void>;
  deleteBlock: (id: string) => Promise<void>;

  // 状态管理
  setCurrentBlock: (id: string | null) => Promise<void>;
  getCurrentBlock: () => UnifiedBlock | null;
}

export const useBlockManager = create<BlockManagerState>((set, get) => ({
  currentBlock: null,
  blocks: [],
  isOpening: false,

  // 获取单个块
  async getBlock(id: string) {
    try {
      const block = await Database.get(id);
      if (block && !block.isDeleted) {
        await yDocManager.updateBlock(id, block); // 同步到Y.Doc
        return block;
      }
      return null;
    } catch (error) {
      console.error('获取块失败:', error);
      return null;
    }
  },

  // 获取所有块
  async getAllBlocks() {
    const blocks = await Database.getAllBlocks();
    const filteredBlocks = blocks.filter(b => !b.isDeleted);
    const sortedBlocks = filteredBlocks.sort((a, b) => 
      new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
    set({ blocks: sortedBlocks });
    return sortedBlocks;
  },

  // 设置当前块
  async setCurrentBlock(id: string | null) {
    if (!id) {
      set({ currentBlock: null });
      return;
    }

    try {
      set({ isOpening: true });
      const block = await get().getBlock(id);
      if (block) {
        await yDocManager.open(id); // 初始化Y.Doc
        set({ currentBlock: block, isOpening: false });
      } else {
        set({ currentBlock: null, isOpening: false });
      }
    } catch (error) {
      console.error('设置当前块失败:', error);
      set({ currentBlock: null, isOpening: false });
    }
  },

  // 获取当前块
  getCurrentBlock() {
    return get().currentBlock;
  },

  // 创建新块
  async createBlock(block: Omit<UnifiedBlock, 'id'>) {
    // 生成块ID
    const id = crypto.randomUUID();
    const newBlock = { 
      ...block, 
      id,
      isDeleted: false,
      createdAt: new Date(),
      modifiedAt: new Date()
    };

    // 同时初始化Y.Doc和数据库
    await Promise.all([
      yDocManager.create(id),
      yDocManager.updateBlock(id, newBlock),
      Database.create(newBlock)
    ]);

    // 更新块列表
    await get().getAllBlocks();
    return id;
  },

  // 更新块数据
  async updateBlock(block: UnifiedBlock) {
    const { currentBlock } = get();
    if (currentBlock && currentBlock.id === block.id) {
      await Promise.all([
        yDocManager.updateBlock(block.id, block),
        Database.update(block)
      ]);
      set({ currentBlock: block });
    }
  },

  // 删除块
  async deleteBlock(id: string) {
    const block = await Database.get(id);
    if (!block) return;

    const deletedBlock = {
      ...block,
      isDeleted: true,
      modifiedAt: new Date()
    };

    await Promise.all([
      yDocManager.updateBlock(id, deletedBlock),
      Database.update(deletedBlock)
    ]);

    // 清除当前块状态
    if (get().currentBlock?.id === id) {
      await yDocManager.close(id);
      set({ currentBlock: null });
    }
  }
}));
