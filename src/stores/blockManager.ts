import { create } from 'zustand';
import { yDocManager } from './YDocManager';
import { UnifiedBlock } from '../types/block';
import { Database } from '../db/operations'; // 导入数据库操作

interface BlockManagerState {
  // 当前打开的块ID
  openBlockId: string | null;
  
  // 当前打开的块数据
  openBlock: UnifiedBlock | null;

  // 所有块列表
  blocks: UnifiedBlock[];

  // 打开块文档
  openBlockDoc: (id: string) => void;

  // 关闭块文档  
  closeBlockDoc: () => void;

  // 更新块数据
  updateBlock: (block: UnifiedBlock) => void;

  // 创建新块
  createBlock: (block: Omit<UnifiedBlock, 'id'>) => Promise<string>;

  // 获取所有块(返回未删除的块数组)
  fetchAllBlocks: () => Promise<UnifiedBlock[]>;
}

export const useBlockManager = create<BlockManagerState>((set, get) => ({
  openBlockId: null,
  openBlock: null,
  blocks: [],
  
  // 获取所有块(默认只获取未删除的块)
  async fetchAllBlocks() {
    // 直接从数据库获取未删除的块
    const blocks = await Database.getAllBlocks();
    const filteredBlocks = blocks.filter(b => !b.isDeleted);
    // 按创建时间降序排列
    const sortedBlocks = filteredBlocks.sort((a, b) => 
      new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
    set({ blocks: sortedBlocks });
    return sortedBlocks;
  },

  // 打开块文档
  async openBlockDoc(id: string) {
    // 初始化Y.Doc文档(用于协同编辑)
    await yDocManager.open(id);
    
    // 从数据库获取块数据
    const block = await Database.get(id);
    if (block) {
      console.log('设置当前打开块:', id, block);
      set({ openBlockId: id, openBlock: block });
      
      // 将数据库数据同步到Y.Doc
      await yDocManager.updateBlock(id, block);
    } else {
      console.warn('获取块数据为空:', id);
    }
  },

  // 关闭块文档
  closeBlockDoc() {
    const { openBlockId } = get();
    if (openBlockId) {
      yDocManager.close(openBlockId);
      set({ openBlockId: null, openBlock: null });
    }
  },

  // 更新块数据
  async updateBlock(block: UnifiedBlock) {
    const { openBlockId } = get();
    if (openBlockId && openBlockId === block.id) {
      // 同时更新到Y.Doc和数据库
      await Promise.all([
        yDocManager.updateBlock(block.id, block),
        Database.update(block)
      ]);
      set({ openBlock: block });
    }
  },

  // 创建新块
  async createBlock(block: Omit<UnifiedBlock, 'id'>) {
    // 生成块ID
    const id = crypto.randomUUID();
    const newBlock = { 
      ...block, 
      id,
      isDeleted: false, // 确保新块未删除
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
    await get().fetchAllBlocks();

    // 返回新块ID
    return id;
  },

  // 删除块(软删除，设置isDeleted为true)
  async deleteBlock(id: string) {
    const { openBlockId } = get();
    if (!openBlockId || openBlockId !== id) return;

    // 获取当前块数据
    const block = await Database.get(id);
    if (!block) return;

    // 更新为已删除状态
    const deletedBlock = {
      ...block,
      isDeleted: true,
      modifiedAt: new Date()
    };

    // 同步更新到Y.Doc和数据库
    await Promise.all([
      yDocManager.updateBlock(id, deletedBlock),
      Database.update(deletedBlock)
    ]);

    // 关闭并清除当前打开的块
    get().closeBlockDoc();
  }
}));
