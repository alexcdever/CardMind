# CardMind 开发者文档

本指南帮助开发者了解 CardMind 项目架构和开发流程。

## 🏗️ 项目架构

### 技术栈
- **前端框架**: React 18 + TypeScript
- **构建工具**: Vite
- **UI库**: Ant Design + Tailwind CSS
- **状态管理**: Zustand
- **数据存储**: IndexedDB (Dexie.js)

### 项目结构

```
src/
├── components/          # React组件
│   ├── DocEditor.tsx  # 卡片创建/编辑组件
│   ├── DocList.tsx    # 卡片列表组件
│   └── DocDetail.tsx  # 卡片详情组件
├── stores/            # 状态管理
│   ├── blockManager.ts # 卡片数据管理
│   └── yDocManager.ts  # Yjs协作管理(预留)
├── types/             # TypeScript类型定义
│   └── block.ts       # 卡片数据结构
├── db/                # 数据库操作
│   ├── index.ts       # 数据库初始化
│   └── operations.ts  # 数据操作方法
└── utils/             # 工具函数
    └── crypto.ts      # 加密相关(预留)
```

### 核心功能实现

#### 卡片数据模型
```typescript
interface UnifiedBlock {
  id: string;
  type: BlockType;
  parentId: string | null;
  childrenIds: string[];
  properties: DocBlockProperties | TextBlockProperties;
  createdAt: Date;
  modifiedAt: Date;
  isDeleted: boolean;
}

interface DocBlockProperties {
  title: string;
  content: string;
}
```

#### 主要功能
- **创建卡片**: 通过模态框输入标题和内容
- **编辑卡片**: 修改现有卡片的标题和内容
- **删除卡片**: 软删除标记
- **数据持久化**: 使用IndexedDB本地存储
- **视图切换**: 支持网格、单列、双列三种布局

### 开发环境

#### 环境要求
- Node.js >= 18
- pnpm >= 8

#### 安装和启动
```bash
# 安装依赖
pnpm install

# 启动开发服务器
pnpm dev

# 构建生产版本
pnpm build
```

#### 可用命令
- `pnpm dev` - 启动开发服务器
- `pnpm build` - 构建生产版本
- `pnpm preview` - 预览构建结果

### 扩展建议

#### 可添加功能
- 标签系统
- 搜索功能
- 数据导入/导出
- 云端同步
- 协作编辑
- 卡片模板

#### 技术改进方向
- 添加单元测试
- 实现响应式设计优化
- 添加错误边界处理
- 优化性能（虚拟滚动等）
- 添加国际化支持