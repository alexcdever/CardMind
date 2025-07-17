// 定义块类型枚举
export enum BlockType { 
  DOC = 'doc',    // 文档块
  TEXT = 'text',  // 文本块
  MEDIA = 'media', // 媒体块
  CODE = 'code'   // 代码块
}

// 文档块属性接口
export interface DocBlockProperties {
  title: string;                // 文档标题
  content: string;              // 文档内容
}

// 文本块属性接口  
export interface TextBlockProperties {
  content: string;              // 文本内容
}

// 媒体块属性接口
export interface MediaBlockProperties {
  filePath: string;             // 文件路径
  fileHash: string;             // 文件哈希值
  fileName: string;             // 文件名称
  thumbnailPath: string;        // 缩略图路径
}

// 代码块属性接口
export interface CodeBlockProperties {
  code: string;                 // 代码内容
  language: string;             // 编程语言
}

// 块属性联合类型
export type BlockProperties = 
  | DocBlockProperties
  | TextBlockProperties
  | MediaBlockProperties
  | CodeBlockProperties
  | Record<string, any>;        // 其他类型块的默认属性

// 统一块接口定义
export interface UnifiedBlock {
  id: string;                   // 块唯一ID
  type: BlockType;              // 块类型
  parentId: string | null;      // 父块ID
  childrenIds: string[];        // 子块ID数组
  properties: BlockProperties;  // 块属性(根据类型不同而不同)
  createdAt: Date;              // 创建时间
  modifiedAt: Date;             // 修改时间
  isDeleted: boolean;           // 是否已删除
}
