// 更新脚本 - 将UnifiedBlock使用方式更新为继承方式

import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

// 获取__dirname的ES模块兼容方式
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 需要更新的文件列表
const filesToUpdate = [
  'src/stores/blockManager.ts',
  'src/db/operations.ts',
  'src/stores/yDocManager.ts',
  'apps/web/src/contexts/DocumentContext.tsx',
  'apps/web/src/components/BlockEditor.tsx'
];

// 更新函数
function updateFile(filePath: string) {
  const fullPath = path.join(__dirname, filePath);
  if (!fs.existsSync(fullPath)) {
    console.log(`文件不存在: ${fullPath}`);
    return;
  }

  let content = fs.readFileSync(fullPath, 'utf-8');
  
  // 更新导入语句
  content = content.replace(
    "import { UnifiedBlock } from '../types/block';",
    "import { Block, DocBlock, TextBlock, MediaBlock, CodeBlock } from '../types/block-inheritance';\nimport { serializeBlock, deserializeBlock } from '../types/block-inheritance';"
  );
  
  content = content.replace(
    "import { UnifiedBlock } from '@cardmind/types';",
    "import { Block, DocBlock, TextBlock, MediaBlock, CodeBlock } from '@cardmind/types/block-inheritance';\nimport { serializeBlock, deserializeBlock } from '@cardmind/types/block-inheritance';"
  );
  
  // 更新类型引用
  content = content.replace(/UnifiedBlock/g, 'Block');
  
  // 特殊处理blockManager.ts
  if (filePath.includes('blockManager.ts')) {
    // 更新createBlock方法
    content = content.replace(
      "async createBlock(block: Omit<UnifiedBlock, 'id'>) {",
      "async createBlock(blockData: Omit<Block, 'id'>) {\n    // 创建一个新的块实例\n    // 注意：这里我们需要根据块类型创建相应的实例\n    // 在实际应用中，我们可能需要额外的信息来确定块类型\n    let newBlock: Block;\n    \n    // 这里只是一个示例，实际实现需要根据传入的数据创建相应的块实例\n    // 例如，如果我们知道要创建一个DocBlock：\n    if ('title' in blockData && 'content' in blockData) {\n      // 假设这是一个DocBlock\n      newBlock = new DocBlock(\n        crypto.randomUUID(),\n        blockData.parentId || null,\n        (blockData as any).title,\n        (blockData as any).content\n      );\n    } else if ('content' in blockData && !('code' in blockData)) {\n      // 假设这是一个TextBlock\n      newBlock = new TextBlock(\n        crypto.randomUUID(),\n        blockData.parentId || null,\n        (blockData as any).content\n      );\n    } else if ('code' in blockData && 'language' in blockData) {\n      // 假设这是一个CodeBlock\n      newBlock = new CodeBlock(\n        crypto.randomUUID(),\n        blockData.parentId || null,\n        (blockData as any).code,\n        (blockData as any).language\n      );\n    } else if ('filePath' in blockData) {\n      // 假设这是一个MediaBlock\n      newBlock = new MediaBlock(\n        crypto.randomUUID(),\n        blockData.parentId || null,\n        (blockData as any).filePath,\n        (blockData as any).fileHash || '',\n        (blockData as any).fileName || '',\n        (blockData as any).thumbnailPath || null\n      );\n    } else {\n      // 默认创建一个TextBlock\n      newBlock = new TextBlock(\n        crypto.randomUUID(),\n        blockData.parentId || null,\n        ''\n      );\n    }"
    );
    
    // 更新数据库操作调用
    content = content.replace(
      "Database.create(newBlock)",
      "const serializedBlock = serializeBlock(newBlock);\n      Database.create(serializedBlock)"
    );
    
    content = content.replace(
      "Database.update(block)",
      "const serializedBlock = serializeBlock(block);\n      Database.update(serializedBlock)"
    );
    
    content = content.replace(
      "const deletedBlock = {\n      ...block,\n      isDeleted: true,\n      modifiedAt: new Date()\n    };\n\n    await Promise.all([\n      yDocManager.updateBlock(id, deletedBlock),\n      Database.update(deletedBlock)\n    ]);",
      "const deletedBlock = {\n      ...block,\n      isDeleted: true,\n      modifiedAt: new Date()\n    } as Block;\n    \n    const serializedDeletedBlock = serializeBlock(deletedBlock);\n\n    await Promise.all([\n      yDocManager.updateBlock(id, deletedBlock),\n      Database.update(serializedDeletedBlock)\n    ]);"
    );
  }
  
  // 特殊处理operations.ts
  if (filePath.includes('operations.ts')) {
    // 更新create方法
    content = content.replace(
      "create: async (block: UnifiedBlock): Promise<string | number> => {",
      "create: async (block: any): Promise<string | number> => {"
    );
    
    // 更新update方法
    content = content.replace(
      "update: async (block: UnifiedBlock): Promise<string | number> => {",
      "update: async (block: any): Promise<string | number> => {"
    );
    
    // 更新batchUpdate方法
    content = content.replace(
      "batchUpdate: async (blocks: UnifiedBlock[]): Promise<string | number> => {",
      "batchUpdate: async (blocks: any[]): Promise<string | number> => {"
    );
    
    // 更新get方法
    content = content.replace(
      "get: async (id: string): Promise<UnifiedBlock | undefined> => {",
      "get: async (id: string): Promise<any | undefined> => {"
    );
    
    // 更新getAllBlocks方法
    content = content.replace(
      "getAllBlocks: async (): Promise<UnifiedBlock[]> => {",
      "getAllBlocks: async (): Promise<any[]> => {"
    );
    
    // 更新getChildren方法
    content = content.replace(
      "getChildren: async (parentId: string): Promise<UnifiedBlock[]> => {",
      "getChildren: async (parentId: string): Promise<any[]> => {"
    );
  }
  
  // 特殊处理yDocManager.ts
  if (filePath.includes('yDocManager.ts')) {
    // 更新updateBlock方法
    content = content.replace(
      "static async updateBlock(blockId: string, block: UnifiedBlock): Promise<void> {",
      "static async updateBlock(blockId: string, block: Block): Promise<void> {\n    const serializedBlock = serializeBlock(block);"
    );
    
    content = content.replace(
      "Object.entries(block).forEach(([key, value]) => {",
      "Object.entries(serializedBlock).forEach(([key, value]) => {"
    );
    
    // 更新getBlock方法
    content = content.replace(
      "static async getBlock(blockId: string): Promise<UnifiedBlock | null> {",
      "static async getBlock(blockId: string): Promise<Block | null> {"
    );
    
    content = content.replace(
      "return data as unknown as UnifiedBlock;",
      "if (!data) return null;\n    return deserializeBlock(data);"
    );
  }
  
  // 特殊处理DocumentContext.tsx
  if (filePath.includes('DocumentContext.tsx')) {
    // 更新动作类型
    content = content.replace(
      "| { type: 'ADD_BLOCK'; payload: UnifiedBlock }",
      "| { type: 'ADD_BLOCK'; payload: Block }"
    );
    
    content = content.replace(
      "| { type: 'UPDATE_BLOCK'; payload: { documentId: string; block: UnifiedBlock } }",
      "| { type: 'UPDATE_BLOCK'; payload: { documentId: string; block: Block } }"
    );
    
    // 更新上下文类型
    content = content.replace(
      "addBlock: (block: Omit<UnifiedBlock, 'id' | 'createdAt' | 'modifiedAt'>) => Promise<void>;",
      "addBlock: (block: Omit<Block, 'id' | 'createdAt' | 'modifiedAt'>) => Promise<void>;"
    );
    
    content = content.replace(
      "updateBlock: (block: UnifiedBlock) => Promise<void>;",
      "updateBlock: (block: Block) => Promise<void>;"
    );
    
    // 更新addBlock函数
    content = content.replace(
      "const addBlock = async (block: Omit<UnifiedBlock, 'id' | 'createdAt' | 'modifiedAt'>) => {",
      "const addBlock = async (blockData: Omit<Block, 'id' | 'createdAt' | 'modifiedAt'>) => {\n    if (!state.currentDocument) return;\n\n    // 创建一个新的块实例\n    // 注意：这里我们需要根据块类型创建相应的实例\n    // 在实际应用中，我们可能需要额外的信息来确定块类型\n    let newBlock: Block;\n    \n    // 这里只是一个示例，实际实现需要根据传入的数据创建相应的块实例\n    // 例如，如果我们知道要创建一个DocBlock：\n    if ('title' in blockData && 'content' in blockData) {\n      // 假设这是一个DocBlock\n      newBlock = new DocBlock(\n        crypto.randomUUID(),\n        blockData.parentId || null,\n        (blockData as any).title,\n        (blockData as any).content\n      );\n    } else if ('content' in blockData && !('code' in blockData)) {\n      // 假设这是一个TextBlock\n      newBlock = new TextBlock(\n        crypto.randomUUID(),\n        blockData.parentId || null,\n        (blockData as any).content\n      );\n    } else if ('code' in blockData && 'language' in blockData) {\n      // 假设这是一个CodeBlock\n      newBlock = new CodeBlock(\n        crypto.randomUUID(),\n        blockData.parentId || null,\n        (blockData as any).code,\n        (blockData as any).language\n      );\n    } else if ('filePath' in blockData) {\n      // 假设这是一个MediaBlock\n      newBlock = new MediaBlock(\n        crypto.randomUUID(),\n        blockData.parentId || null,\n        (blockData as any).filePath,\n        (blockData as any).fileHash || '',\n        (blockData as any).fileName || '',\n        (blockData as any).thumbnailPath || null\n      );\n    } else {\n      // 默认创建一个TextBlock\n      newBlock = new TextBlock(\n        crypto.randomUUID(),\n        blockData.parentId || null,\n        ''\n      );\n    }"
    );
    
    content = content.replace(
      "const newBlock: UnifiedBlock = {\n      ...block,\n      id: crypto.randomUUID(),\n      createdAt: new Date(),\n      modifiedAt: new Date()\n    };\n\n    const updatedDocument = {\n      ...state.currentDocument,\n      blocks: [...state.currentDocument.blocks, newBlock]\n    };\n\n    await updateDocument(state.currentDocument.id, updatedDocument);\n    dispatch({ type: 'ADD_BLOCK', payload: newBlock });",
      "const serializedBlock = serializeBlock(newBlock);\n\n    const updatedDocument = {\n      ...state.currentDocument,\n      blocks: [...state.currentDocument.blocks, serializedBlock]\n    };\n\n    await updateDocument(state.currentDocument.id, updatedDocument);\n    dispatch({ type: 'ADD_BLOCK', payload: newBlock });"
    );
    
    // 更新updateBlock函数
    content = content.replace(
      "const updateBlock = async (block: UnifiedBlock) => {",
      "const updateBlock = async (block: Block) => {\n    if (!state.currentDocument) return;\n\n    const updatedBlock = { ...block, modifiedAt: new Date() } as Block;"
    );
    
    content = content.replace(
      "const updatedBlock = { ...block, modifiedAt: new Date() };\n    \n    const updatedDocument = {\n      ...state.currentDocument,\n      blocks: state.currentDocument.blocks.map(b =>\n        b.id === updatedBlock.id ? updatedBlock : b\n      )\n    };\n\n    await updateDocument(state.currentDocument.id, updatedDocument);\n    dispatch({ type: 'UPDATE_BLOCK', payload: { documentId: state.currentDocument.id, block: updatedBlock } });",
      "const serializedBlock = serializeBlock(updatedBlock);\n    \n    const updatedDocument = {\n      ...state.currentDocument,\n      blocks: state.currentDocument.blocks.map(b =>\n        b.id === serializedBlock.id ? serializedBlock : b\n      )\n    };\n\n    await updateDocument(state.currentDocument.id, updatedDocument);\n    dispatch({ type: 'UPDATE_BLOCK', payload: { documentId: state.currentDocument.id, block: updatedBlock } });"
    );
  }
  
  // 特殊处理BlockEditor.tsx
  if (filePath.includes('BlockEditor.tsx')) {
    // 更新导入语句
    content = content.replace(
      "import type { UnifiedBlock } from '@cardmind/types';",
      "import type { Block } from '@cardmind/types/block-inheritance';"
    );
    
    // 更新组件属性
    content = content.replace(
      "block: UnifiedBlock;",
      "block: Block;"
    );
    
    // 更新renderBlockContent函数
    content = content.replace(
      "const renderBlockContent = () => {\n    switch (block.type) {",
      "const renderBlockContent = () => {\n    // 需要根据新的块类型调整渲染逻辑\n    // 这里暂时保持原样，实际应用中需要根据新的类型系统进行调整\n    let blockType: string;\n    if (isDocBlock(block)) blockType = 'doc';\n    else if (isTextBlock(block)) blockType = 'text';\n    else if (isCodeBlock(block)) blockType = 'code';\n    else if (isMediaBlock(block)) blockType = 'media';\n    else blockType = 'text'; // 默认类型\n    \n    switch (blockType) {"
    );
    
    // 更新handleSave函数
    content = content.replace(
      "await updateBlock({\n        ...block,\n        properties: {\n          ...block.properties,\n          content\n        }\n      });",
      "// 需要根据新的块类型调整更新逻辑\n      // 这里暂时保持原样，实际应用中需要根据新的类型系统进行调整\n      const updatedBlock = { ...block } as any;\n      if (isDocBlock(block)) {\n        updatedBlock.content = content;\n      } else if (isTextBlock(block)) {\n        updatedBlock.content = content;\n      } else if (isCodeBlock(block)) {\n        updatedBlock.code = content;\n      } else if (isMediaBlock(block)) {\n        updatedBlock.filePath = content;\n      }\n      await updateBlock(updatedBlock);"
    );
  }

  fs.writeFileSync(fullPath, content, 'utf-8');
  console.log(`已更新文件: ${fullPath}`);
}

// 执行更新
filesToUpdate.forEach(updateFile);

console.log('所有文件更新完成');