# 块类型重构计划

## 目标
使用继承方式重构块类型定义，替代现有的枚举+联合类型方案。

## 当前问题
1. 枚举方式在switch语句中容易出现重复case
2. 类型安全性不够强
3. 扩展性有限
4. 属性访问需要通过properties字段

## 新的设计方案

### 1. 基类定义
```typescript
/**
 * 块基类 - 所有块类型的基类
 */
export abstract class Block {
  /** 块唯一ID */
  id: string;
  
  /** 父块ID */
  parentId: string | null;
  
  /** 子块ID数组 */
  childrenIds: string[];
  
  /** 创建时间 */
  createdAt: Date;
  
  /** 修改时间 */
  modifiedAt: Date;
  
  /** 是否已删除 */
  isDeleted: boolean;
  
  constructor(id: string, parentId: string | null = null) {
    this.id = id;
    this.parentId = parentId;
    this.childrenIds = [];
    this.createdAt = new Date();
    this.modifiedAt = new Date();
    this.isDeleted = false;
  }
  
  /**
   * 获取块的类型标识
   * @returns 块类型字符串
   */
  abstract getType(): string;
}
```

### 2. 文档块类
```typescript
/**
 * 文档块类 - 表示一个文档
 */
export class DocBlock extends Block {
  /** 文档标题 */
  title: string;
  
  /** 文档内容 */
  content: string;
  
  constructor(id: string, parentId: string | null, title: string, content: string) {
    super(id, parentId);
    this.title = title;
    this.content = content;
  }
  
  getType(): string {
    return 'doc';
  }
}
```

### 3. 文本块类
```typescript
/**
 * 文本块类 - 表示一段文本
 */
export class TextBlock extends Block {
  /** 文本内容 */
  content: string;
  
  constructor(id: string, parentId: string | null, content: string) {
    super(id, parentId);
    this.content = content;
  }
  
  getType(): string {
    return 'text';
  }
}
```

### 4. 媒体块类
```typescript
/**
 * 媒体块类 - 表示媒体文件（图片、视频等）
 */
export class MediaBlock extends Block {
  /** 文件路径 */
  filePath: string;
  
  /** 文件哈希值 */
  fileHash: string;
  
  /** 文件名称 */
  fileName: string;
  
  /** 缩略图路径 */
  thumbnailPath: string;
  
  constructor(
    id: string, 
    parentId: string | null,
    filePath: string,
    fileHash: string,
    fileName: string,
    thumbnailPath: string
  ) {
    super(id, parentId);
    this.filePath = filePath;
    this.fileHash = fileHash;
    this.fileName = fileName;
    this.thumbnailPath = thumbnailPath;
  }
  
  getType(): string {
    return 'media';
  }
}
```

### 5. 代码块类
```typescript
/**
 * 代码块类 - 表示代码片段
 */
export class CodeBlock extends Block {
  /** 代码内容 */
  code: string;
  
  /** 编程语言 */
  language: string;
  
  constructor(id: string, parentId: string | null, code: string, language: string) {
    super(id, parentId);
    this.code = code;
    this.language = language;
  }
  
  getType(): string {
    return 'code';
  }
}
```

## 实施步骤
1. 创建新的类型定义文件
2. 更新相关组件和函数以使用新类型
3. 逐步替换现有代码中的旧类型
4. 删除旧的枚举和接口定义

## 预期优势
1. 更强的类型安全性
2. 更好的代码组织
3. 更直观的属性访问
4. 更好的扩展性