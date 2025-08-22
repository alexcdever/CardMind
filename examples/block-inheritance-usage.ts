// 块继承方式使用示例

// 导入新的块类型定义
import { Block, DocBlock, TextBlock, MediaBlock, CodeBlock, isDocBlock, isTextBlock, isMediaBlock, isCodeBlock } from '../src/types/block-inheritance';
import { BlockType } from '@cardmind/types';

// 1. 创建不同类型的块
const docBlock = new DocBlock('1', null, '我的文档', '这是文档内容');
const textBlock = new TextBlock('2', '1', '这是一段文本');
const mediaBlock = new MediaBlock('3', '1', '/path/to/image.jpg', 'hash123', 'image.jpg', '/path/to/thumbnail.jpg');
const codeBlock = new CodeBlock('4', '1', 'console.log("Hello World");', 'javascript');

// 2. 使用类型守卫函数进行类型检查
function processBlock(block: Block) {
  if (isDocBlock(block)) {
    console.log(`文档块标题: ${block.title}`);
    console.log(`文档块内容: ${block.content}`);
  } else if (isTextBlock(block)) {
    console.log(`文本块内容: ${block.content}`);
  } else if (isMediaBlock(block)) {
    console.log(`媒体块文件: ${block.fileName}`);
    console.log(`媒体块路径: ${block.filePath}`);
  } else if (isCodeBlock(block)) {
    console.log(`代码块语言: ${block.language}`);
    console.log(`代码块内容: ${block.code}`);
  }
}

// 3. 处理块数据
processBlock(docBlock);
processBlock(textBlock);
processBlock(mediaBlock);
processBlock(codeBlock);

// 4. 演示与现有枚举方式的对比
// 旧方式（枚举+联合类型）
/*
import { UnifiedBlock, BlockType } from '@cardmind/types';

const oldBlock: UnifiedBlock = {
  id: '1',
  type: BlockType.DOC,
  parentId: null,
  childrenIds: [],
  properties: {
    title: '我的文档',
    content: '这是文档内容'
  },
  createdAt: new Date(),
  modifiedAt: new Date(),
  isDeleted: false
};

function processOldBlock(block: UnifiedBlock) {
  switch (block.type) {
    case BlockType.DOC:
      const docProps = block.properties as { title: string; content: string };
      console.log(`文档块标题: ${docProps.title}`);
      console.log(`文档块内容: ${docProps.content}`);
      break;
    // 其他类型...
  }
}
*/

// 5. 数据库存储示例
// 注意：在实际应用中，我们需要将类实例序列化为可存储的格式
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

// 序列化示例
const serializedDocBlock = serializeBlock(docBlock);
console.log('序列化的文档块:', serializedDocBlock);

// 反序列化示例
function deserializeBlock(data: any): Block {
  switch (data.type) {
    case 'doc':
      return new DocBlock(
        data.id,
        data.parentId,
        data.title,
        data.content
      );
    case 'text':
      return new TextBlock(
        data.id,
        data.parentId,
        data.content
      );
    case 'media':
      return new MediaBlock(
        data.id,
        data.parentId,
        data.filePath,
        data.fileHash,
        data.fileName,
        data.thumbnailPath
      );
    case 'code':
      return new CodeBlock(
        data.id,
        data.parentId,
        data.code,
        data.language
      );
    default:
      throw new Error(`未知的块类型: ${data.type}`);
  }
}

// 反序列化示例
const deserializedDocBlock = deserializeBlock(serializedDocBlock);
console.log('反序列化的文档块:', deserializedDocBlock);
console.log('标题:', deserializedDocBlock instanceof DocBlock ? deserializedDocBlock.title : 'N/A');