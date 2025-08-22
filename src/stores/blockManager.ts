import { create } from 'zustand';
import { yDocManager } from './yDocManager';
import { Block, DocBlock, TextBlock, MediaBlock, CodeBlock } from '../types/block-inheritance';
import { serializeBlock, deserializeBlock } from '../types/block-inheritance';
import { Database } from '../db/operations'; // 导入数据库操作

export interface BlockManagerState {
  // 当前打开的块数据
  currentBlock: Block | null;
  
  // 所有块列表
  blocks: Block[];

  // 状态锁 - 防止并发修改
  isOpening: boolean;

  // 查询方法
  getBlock: (id: string) => Promise<Block | null>;
  getAllBlocks: () => Promise<Block[]>;

  // 增删改方法
  createBlock: (block: Omit<Block, 'id'>) => Promise<string>;
  updateBlock: (block: Block) => Promise<void>;
  deleteBlock: (id: string) => Promise<void>;

  // 状态管理
  setCurrentBlock: (id: string | null) => Promise<void>;
  getCurrentBlock: () => Block | null;
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
    const filteredBlocks = blocks.filter((b: Block) => !b.isDeleted);
    const sortedBlocks = filteredBlocks.sort((a: Block, b: Block) => 
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
  async createBlock(block: Omit<Block, 'id'>) {
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
      const serializedBlock = serializeBlock(newBlock);
      Database.create(serializedBlock)
    ]);

    // 重新获取并更新blocks数组，确保状态同步
    const updatedBlocks = await get().getAllBlocks();
    return id;
  },

  // 更新块数据
  async updateBlock(block: Block) {
    // 更新数据库和Y.Doc
    await Promise.all([
      yDocManager.updateBlock(block.id, block),
      const serializedBlock = serializeBlock(block);
      Database.update(serializedBlock)
    ]);
    
    // 更新当前块（如果正在查看）
    const { currentBlock } = get();
    if (currentBlock && currentBlock.id === block.id) {
      set({ currentBlock: block });
    }
    
    // 重新获取并更新blocks数组，确保列表数据同步
    await get().getAllBlocks();
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
    
    // 重新获取并更新blocks数组，确保列表数据同步
    await get().getAllBlocks();
  }
}));
