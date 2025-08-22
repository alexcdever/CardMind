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
}

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
}

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
}

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
}

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
}

/**
 * 类型守卫函数 - 检查是否为文档块
 * @param block 块对象
 * @returns 如果是文档块返回true，否则返回false
 */
export function isDocBlock(block: Block): block is DocBlock {
  return block instanceof DocBlock;
}

/**
 * 类型守卫函数 - 检查是否为文本块
 * @param block 块对象
 * @returns 如果是文本块返回true，否则返回false
 */
export function isTextBlock(block: Block): block is TextBlock {
  return block instanceof TextBlock;
}

/**
 * 类型守卫函数 - 检查是否为媒体块
 * @param block 块对象
 * @returns 如果是媒体块返回true，否则返回false
 */
export function isMediaBlock(block: Block): block is MediaBlock {
  return block instanceof MediaBlock;
}

/**
 * 类型守卫函数 - 检查是否为代码块
 * @param block 块对象
 * @returns 如果是代码块返回true，否则返回false
 */
export function isCodeBlock(block: Block): block is CodeBlock {
  return block instanceof CodeBlock;
}

/**
 * 序列化块以存储到数据库
 * @param block 块对象
 * @returns 序列化后的块数据
 */
export function serializeBlock(block: Block): any {
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

/**
 * 反序列化块从数据库
 * @param data 序列化的块数据
 * @returns 块对象
 */
export function deserializeBlock(data: any): Block {
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
      docBlock.createdAt = data.createdAt;
      docBlock.modifiedAt = data.modifiedAt;
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
      textBlock.createdAt = data.createdAt;
      textBlock.modifiedAt = data.modifiedAt;
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
      mediaBlock.createdAt = data.createdAt;
      mediaBlock.modifiedAt = data.modifiedAt;
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
      codeBlock.createdAt = data.createdAt;
      codeBlock.modifiedAt = data.modifiedAt;
      codeBlock.isDeleted = data.isDeleted;
      return codeBlock;
    default:
      throw new Error(`未知的块类型: ${data.type}`);
  }
}