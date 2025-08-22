# CardMind 开发者文档

## 技术栈

- **前端框架**: React 18 + TypeScript
- **状态管理**: Zustand
- **UI组件库**: Ant Design 5.x
- **数据存储**: IndexedDB (通过 Dexie.js)
- **配置同步**: Yjs (支持多端同步)
- **构建工具**: Vite
- **包管理**: pnpm

## 项目结构

```
src/
├── components/          # React组件
│   ├── DocEditor.tsx  # 文档编辑器
│   ├── DocList.tsx    # 文档列表
│   └── SettingsModal.tsx # 设置弹窗
├── stores/             # 状态管理
│   ├── blockManager.ts # 卡片数据管理
│   └── settingsManager.ts # 设置管理
├── types/              # TypeScript类型定义
│   ├── block.ts       # 卡片相关类型
│   └── settings.ts    # 设置相关类型
└── App.tsx            # 主应用组件
```

## 核心功能实现

### 1. 卡片数据模型

```typescript
interface Block {
  id: string;
  title: string;
  content: string;
  createdAt: Date;
  updatedAt: Date;
}
```

### 2. 设置配置模型

```typescript
interface RelaySettings {
  enabled: boolean;
  ip: string;
  port: number;
  path: string;
}

interface AppSettings {
  relay: RelaySettings;
}
```

### 3. 数据管理

**卡片管理** (`blockManager.ts`):
- 使用 Dexie.js 操作 IndexedDB
- 支持 CRUD 操作
- 实时数据同步

**设置管理** (`settingsManager.ts`):
- 使用 Zustand 管理状态
- 集成 Yjs 实现多端配置同步
- 智能合并配置，避免覆盖现有设置

### 4. 设置功能实现

**配置同步机制**:
- 使用 Y.Doc 存储配置数据
- 通过 Y.Map 结构保存设置
- 支持实时同步和离线缓存

**配置合并策略**:
- 初始化时检查现有配置
- 空白配置值不会覆盖现有设置
- 支持增量更新配置项

**中继服务配置**:
- 开关控制：enabled 字段
- 参数配置：ip、port、path
- 动态验证：配置变更时实时验证

## 开发环境

### 安装依赖

```bash
pnpm install
```

### 开发命令

```bash
# 启动开发服务器
pnpm dev

# 构建生产版本
pnpm build

# 预览构建结果
pnpm preview
```

### 调试工具

- **React DevTools**: 组件调试
- **Redux DevTools**: 状态管理调试
- **IndexedDB 浏览器工具**: 查看本地数据

## 扩展建议

### 1. 功能扩展

**卡片功能**:
- 添加标签系统
- 支持富文本编辑
- 添加搜索功能
- 支持导入导出

**设置功能**:
- 主题切换
- 快捷键配置
- 数据备份/恢复

### 2. 架构优化

**性能优化**:
- 虚拟滚动优化大列表
- 数据分页加载
- 缓存策略优化

**代码组织**:
- 提取通用组件
- 实现插件化架构
- 添加单元测试

### 3. 部署方案

**Web部署**:
- 支持Docker部署
- 环境变量配置
- CDN加速

**桌面应用**:
- 使用 Electron 打包
- 自动更新机制
- 系统托盘集成

## 注意事项

- 所有数据默认保存在浏览器本地，生产环境需配置中继服务
- 配置变更会实时同步，注意处理并发冲突
- 开发时注意Yjs文档的生命周期管理
- 配置验证应在UI层和逻辑层都实现