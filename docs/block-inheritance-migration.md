# 块类型继承重构迁移指南

## 概述
本文档旨在指导开发人员如何将现有的块类型定义从枚举+联合类型方案迁移到新的继承方式。

## 新旧对比

### 旧方案
```typescript
// 枚举定义块类型
enum BlockType { 
  DOC = 'doc',
  TEXT = 'text',
  MEDIA = 'media',
  CODE = 'code'
}

// 联合类型定义属性
interface DocBlockProperties {
  title: string;
  content: string;
}

interface TextBlockProperties {
  content: string;
}

// 统一块接口
interface UnifiedBlock {
  id: string;
  type: BlockType;
  parentId: string | null;
  childrenIds: string[];
  properties: BlockProperties;
  createdAt: Date;
  modifiedAt: Date;
  isDeleted: boolean;
}
```

### 新方案
```typescript
// 基类
abstract class Block {
  id: string;
  parentId: string | null;
  childrenIds: string[];
  createdAt: Date;
  modifiedAt: Date;
  isDeleted: boolean;
  
  constructor(id: string, parentId: string | null = null) {
    // 初始化代码
  }
}

// 具体块类型类
class DocBlock extends Block {
  title: string;
  content: string;
  
  constructor(id: string, parentId: string | null, title: string, content: string) {
    super(id, parentId);
    this.title = title;
    this.content = content;
  }
}

// 类型守卫函数
function isDocBlock(block: Block): block is DocBlock {
  return block instanceof DocBlock;
}
```

## 迁移步骤

### 1. 替换类型定义
将导入语句从：
```typescript
import { UnifiedBlock, BlockType } from '../types/block';
```

改为：
```typescript
import { Block, DocBlock, TextBlock, MediaBlock, CodeBlock } from '../types/block-inheritance';
```

### 2. 更新类型检查
将类型检查从：
```typescript
if (block.type === BlockType.DOC) {
  // 处理文档块
  const docProps = block.properties as DocBlockProperties;
  console.log(docProps.title);
}
```

改为：
```typescript
if (isDocBlock(block)) {
  // 处理文档块
  console.log(block.title); // 直接访问属性
}
```

### 3. 更新创建块的代码
将创建块的代码从：
```typescript
const newBlock: UnifiedBlock = {
  id: '1',
  type: BlockType.DOC,
  parentId: null,
  childrenIds: [],
  properties: {
    title: '新文档',
    content: '文档内容'
  },
  createdAt: new Date(),
  modifiedAt: new Date(),
  isDeleted: false
};
```

改为：
```typescript
const newBlock = new DocBlock('1', null, '新文档', '文档内容');
```

## 数据库序列化与反序列化

由于类实例在序列化时会丢失方法，需要在存储到数据库时进行特殊处理。

### 序列化
```typescript
function serializeBlock(block: Block): any {
  // 基础属性
  const baseData = {
    id: block.id,
    parentId: block.parentId,
    childrenIds: block.childrenIds,
    createdAt: block.createdAt,
    modifiedAt: block.modifiedAt,
    isDeleted: block.isDeleted
  };
  
  // 根据具体类型添加特定属性
  if (isDocBlock(block)) {
    return {
      ...baseData,
      type: 'doc',
      title: block.title,
      content: block.content
    };
  } else if (isTextBlock(block)) {
    return {
      ...baseData,
      type: 'text',
      content: block.content
    };
  } else if (isMediaBlock(block)) {
    return {
      ...baseData,
      type: 'media',
      filePath: block.filePath,
      fileHash: block.fileHash,
      fileName: block.fileName,
      thumbnailPath: block.thumbnailPath
    };
  } else if (isCodeBlock(block)) {
    return {
      ...baseData,
      type: 'code',
      code: block.code,
      language: block.language
    };
  }
  
  throw new Error('未知的块类型');
}
```

### 反序列化
```typescript
function deserializeBlock(data: any): Block {
  switch (data.type) {
    case 'doc':
      const docBlock = new DocBlock(
        data.id,
        data.parentId,
        data.title,
        data.content
      );
      // 恢复其他属性
      docBlock.childrenIds = data.childrenIds;
      docBlock.createdAt = new Date(data.createdAt);
      docBlock.modifiedAt = new Date(data.modifiedAt);
      docBlock.isDeleted = data.isDeleted;
      return docBlock;
    case 'text':
      const textBlock = new TextBlock(
        data.id,
        data.parentId,
        data.content
      );
      // 恢复其他属性
      textBlock.childrenIds = data.childrenIds;
      textBlock.createdAt = new Date(data.createdAt);
      textBlock.modifiedAt = new Date(data.modifiedAt);
      textBlock.isDeleted = data.isDeleted;
      return textBlock;
    case 'media':
      const mediaBlock = new MediaBlock(
        data.id,
        data.parentId,
        data.filePath,
        data.fileHash,
        data.fileName,
        data.thumbnailPath
      );
      // 恢复其他属性
      mediaBlock.childrenIds = data.childrenIds;
      mediaBlock.createdAt = new Date(data.createdAt);
      mediaBlock.modifiedAt = new Date(data.modifiedAt);
      mediaBlock.isDeleted = data.isDeleted;
      return mediaBlock;
    case 'code':
      const codeBlock = new CodeBlock(
        data.id,
        data.parentId,
        data.code,
        data.language
      );
      // 恢复其他属性
      codeBlock.childrenIds = data.childrenIds;
      codeBlock.createdAt = new Date(data.createdAt);
      codeBlock.modifiedAt = new Date(data.modifiedAt);
      codeBlock.isDeleted = data.isDeleted;
      return codeBlock;
    default:
      throw new Error(`未知的块类型: ${data.type}`);
  }
}
```

## 优势
1. **更强的类型安全性**：编译器可以在编译时检查属性访问
2. **更直观的API**：可以直接访问块的属性，而不需要通过properties字段
3. **更好的代码组织**：每种块类型的属性和方法都在自己的类中定义
4. **更容易扩展**：添加新类型只需继承Block类

## 注意事项
1. 需要更新所有使用UnifiedBlock的地方
2. 数据库存储格式需要调整以支持序列化和反序列化
3. 网络传输的序列化/反序列化需要特殊处理
4. 在迁移过程中，可以保持对旧接口的兼容，逐步替换