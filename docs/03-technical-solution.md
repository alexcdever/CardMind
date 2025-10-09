# CardMind 技术方案文档

## 1. 项目概述

CardMind是一个现代化的笔记卡片管理应用，基于需求文档要求，需要实现卡片管理、多设备数据同步、本地加密存储等核心功能。本技术方案将确保需求的高效、安全、可靠实现。

## 2. 架构设计

### 2.1 整体架构

采用**渐进式Web应用(PWA)**架构，结合**离线优先**设计原则：

```
┌─────────────────────────────────────────────────────┐
│                   用户界面层                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   卡片列表   │  │   卡片详情   │  │   编辑窗口   │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────┐
│                   业务逻辑层                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │  卡片管理器   │  │  数据同步器   │  │  加密管理器   │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────┐
│                   数据存储层                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ 本地IndexedDB│  │  CRDT同步   │  │  加密存储   │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────┘
```

### 2.2 技术架构分层

#### 2.2.1 表现层 (Presentation Layer)
- **框架**: React + TypeScript
- **状态管理**: Zustand (轻量级状态管理)
- **UI组件**: Tailwind CSS + Headless UI
- **响应式设计**: 移动端优先

#### 2.2.2 业务逻辑层 (Business Logic Layer)
- **数据管理**: 卡片CRUD操作
- **同步逻辑**: Yjs CRDT算法实现
- **加密服务**: Web Crypto API
- **验证逻辑**: 输入验证和字数统计

#### 2.2.3 数据访问层 (Data Access Layer)
- **本地存储**: IndexedDB (通过Dexie.js封装)
- **数据模型**: 基于需求定义的卡片结构
- **加密存储**: AES-256-GCM加密
- **数据同步**: Yjs + WebRTC点对点同步

### 2.3 数据模型设计

#### 2.3.1 卡片实体结构
```typescript
interface Card {
  id: string;           // 唯一标识符 (UUID v4)
  title: string;        // 卡片标题 (最大20字符)
  content: string;    // 卡片内容 (最大2000字符)
  createdAt: number;  // 创建时间 (毫秒级时间戳)
  updatedAt: number;  // 修改时间 (毫秒级时间戳)
  isDeleted: boolean;   // 软删除标记
  // 注意: 使用Yjs CRDT后，不再需要version字段，冲突解决由Yjs自动处理
}
```

#### 2.3.2 存储结构
```typescript
interface DatabaseSchema {
  cards: Card;        // 卡片主表
  encryption: {       // 加密配置表
    keyHash: string;
    salt: Uint8Array;
  };
  // 注意：移除了sync_state表，Yjs自动处理同步状态和设备标识
```

## 3. 技术选型

### 3.1 前端技术栈

| 技术 | 版本 | 用途 | 选择理由 |
|------|------|------|----------|
| pnpm | 8.x | 包管理器 | 快速、节省磁盘空间的包管理工具 |
| React | 18.x | 前端框架 | 生态成熟，组件化开发 |
| Ant Design | 5.x | UI框架 | 丰富的组件库，美观的设计系统 |
| TypeScript | 5.x | 类型系统 | 静态类型检查，减少运行时错误 |
| Vite | 5.x | 构建工具 | 快速开发，优秀的PWA支持 |
| Tailwind CSS | 3.x | 样式框架 | 快速开发，响应式设计 |
| Zustand | 4.x | 状态管理 | 轻量级，简单易用 |
| Dexie.js | 3.x | IndexedDB封装 | 简化本地存储操作 |
| Yjs | 13.x | CRDT同步 | 成熟的冲突解决算法 |

### 3.2 安全与加密

| 技术 | 用途 | 实现方案 |
|------|------|----------|
| Web Crypto API | 数据加密 | AES-256-GCM算法 |
| PBKDF2 | 密钥派生 | 100,000次迭代 |
| UUID v4 | 唯一标识 | 基于crypto.getRandomValues |

### 3.3 开发工具

| 工具 | 用途 | 配置 |
|------|------|------|
| ESLint | 代码质量 | Airbnb规范 + TypeScript |
| Prettier | 代码格式化 | 统一代码风格 |
| Jest | 单元测试 | React Testing Library |
| Playwright | E2E测试 | 关键用户流程测试 |

## 4. 实现步骤

### 4.1 第一阶段：基础框架搭建

#### 4.1.1 项目初始化
```bash
# 克隆项目仓库（新项目初始化）
# git clone [repository-url]
# cd CardMind

# 安装项目依赖（使用pnpm）
pnpm install

# 安装核心依赖已在package.json中定义，包括：
# - antd 和 @ant-design/icons：UI组件库
# - zustand：状态管理
# - dexie：IndexedDB封装
# - yjs、y-indexeddb、y-webrtc：CRDT同步
# - libsodium-wrappers：加密功能
```

#### 4.1.2 基础配置
- 配置TypeScript严格模式
- 设置Tailwind CSS响应式断点
- 配置PWA manifest
- 设置开发环境变量

#### 4.1.3 目录结构
```
src/
├── components/          # UI组件
│   ├── CardList/
│   ├── CardDetail/
│   └── CardEditor/
├── stores/             # 状态管理
│   ├── cardStore.ts
│   └── syncStore.ts
├── services/           # 业务服务
│   ├── CardService.ts
│   ├── EncryptionService.ts
│   └── SyncService.ts
├── utils/              # 工具函数
│   ├── encryption.ts
│   └── validation.ts
└── types/              # 类型定义
    └── card.types.ts
```

### 4.2 第二阶段：核心功能实现 (3-4天)

#### 4.2.1 双数据源极简架构实现
```typescript
// services/MinimalCardStorage.ts
import Dexie from 'dexie';
import * as Y from 'yjs';
import { WebrtcProvider } from 'y-webrtc';
import { IndexeddbPersistence } from 'y-indexeddb';
import { Card } from '../types/card.types';

class MinimalCardStorage {
  private db: Dexie;
  private yDocs: Map<string, Y.Doc> = new Map();
  private providers: Map<string, WebrtcProvider> = new Map();
  private persistences: Map<string, IndexeddbPersistence> = new Map(); // Yjs持久化
  
  async initializeDatabase(): Promise<void> {
    // 初始化IndexedDB（存储业务数据）
    this.db = new Dexie('CardMindDB');
    this.db.version(1).stores({
      cards: 'id, title, content, createdAt, updatedAt, isDeleted' // 存储业务数据
    });
  }
  
  // 双数据源操作：每次操作同时更新IndexedDB和Yjs
  async createCard(title: string, content: string): Promise<Card> {
    const cardId = crypto.randomUUID();
    const now = Date.now();
    const card: Card = {
      id: cardId,
      title,
      content,
      createdAt: now,
      updatedAt: now,
      isDeleted: false
    };
    
    // 1. 保存到IndexedDB（业务数据）
    await this.db.cards.put(card);
    
    // 2. 创建Yjs文档（同步数据）- 保存整个Card对象
    const yDoc = new Y.Doc();
    const yMap = yDoc.getMap('card'); // 使用Y.Map存储整个Card对象
    
    // 将Card对象的所有属性同步到Yjs
    yMap.set('id', card.id);
    yMap.set('title', card.title);
    yMap.set('content', card.content);
    yMap.set('createdAt', card.createdAt);
    yMap.set('updatedAt', card.updatedAt);
    yMap.set('isDeleted', card.isDeleted);
    
    // 3. 配置Yjs持久化（关键修复：防止重启丢失数据）
    const persistence = new IndexeddbPersistence(`card-${cardId}`, yDoc);
    await persistence.whenSynced; // 等待持久化就绪
    
    // 4. 启用实时同步
    const provider = new WebrtcProvider(`card-${cardId}`, yDoc);
    this.yDocs.set(cardId, yDoc);
    this.providers.set(cardId, provider);
    this.persistences.set(cardId, persistence); // 保存持久化引用
    
    // 5. 监听Yjs变化，自动同步到IndexedDB
    yMap.observe(() => {
      // 当Yjs数据变化时，自动同步回IndexedDB
      this.syncFromYjsToIndexedDB(cardId);
    });
    
    return card;
  }
  
  async updateCard(cardId: string, updates: Partial<Card>): Promise<void> {
    // 1. 更新IndexedDB
    const card = await this.db.cards.get(cardId);
    if (card) {
      Object.assign(card, updates, { updatedAt: Date.now() });
      await this.db.cards.put(card);
    }
    
    // 2. 更新Yjs（同步到其他设备）
    const yDoc = this.yDocs.get(cardId);
    if (yDoc) {
      const yMap = yDoc.getMap('card');
      // 更新Yjs中对应的属性
      Object.keys(updates).forEach(key => {
        yMap.set(key, updates[key as keyof Card]);
      });
      yMap.set('updatedAt', Date.now());
    }
  }
  
  async deleteCard(cardId: string): Promise<void> {
    // 1. 软删除：将isDeleted标记为true，而不是真正删除数据
    const card = await this.db.cards.get(cardId);
    if (card) {
      card.isDeleted = true;
      card.updatedAt = Date.now();
      await this.db.cards.put(card);
    }
    
    // 2. 同步软删除状态到Yjs
    const yDoc = this.yDocs.get(cardId);
    if (yDoc) {
      const yMap = yDoc.getMap('card');
      yMap.set('isDeleted', true);
      yMap.set('updatedAt', Date.now());
    }
    
    // 3. 注意：不清理Yjs资源，保持同步能力
    // 因为软删除的卡片仍然可以被恢复
  }
  
  async getAllCards(): Promise<Card[]> {
    return await this.db.cards.where('isDeleted').equals(false).orderBy('updatedAt').reverse().toArray();
  }

  async getDeletedCards(): Promise<Card[]> {
    return await this.db.cards.where('isDeleted').equals(true).orderBy('updatedAt').reverse().toArray();
  }

  async restoreCard(cardId: string): Promise<void> {
    // 1. 恢复卡片：将isDeleted标记为false
    const card = await this.db.cards.get(cardId);
    if (card) {
      card.isDeleted = false;
      card.updatedAt = Date.now();
      await this.db.cards.put(card);
    }
    
    // 2. 同步恢复状态到Yjs
    const yDoc = this.yDocs.get(cardId);
    if (yDoc) {
      const yMap = yDoc.getMap('card');
      yMap.set('isDeleted', false);
      yMap.set('updatedAt', Date.now());
    }
  }
  
  // 从Yjs加载完整Card数据（用于初始同步）
  async loadFromYjs(cardId: string): Promise<Card | null> {
    const yDoc = this.yDocs.get(cardId);
    if (yDoc) {
      const yMap = yDoc.getMap('card');
      // 从Yjs中读取完整的Card对象，包括软删除状态
      return {
        id: yMap.get('id') || cardId,
        title: yMap.get('title') || '',
        content: yMap.get('content') || '',
        createdAt: yMap.get('createdAt') || Date.now(),
        updatedAt: yMap.get('updatedAt') || Date.now(),
        isDeleted: yMap.get('isDeleted') || false  // 正确读取软删除状态
      };
    }
    return null;
  }

  // 关键缺失方法：从Yjs同步数据回IndexedDB（解决多设备同步问题）
  async syncFromYjsToIndexedDB(cardId: string): Promise<void> {
    const yDoc = this.yDocs.get(cardId);
    if (!yDoc) {
      // 如果本地没有这个卡片的Yjs文档，创建它
      await this.createYjsDocForExistingCard(cardId);
      return;
    }

    const yMap = yDoc.getMap('card');
    const cardFromYjs: Card = {
      id: yMap.get('id') || cardId,
      title: yMap.get('title') || '',
      content: yMap.get('content') || '',
      createdAt: yMap.get('createdAt') || Date.now(),
      updatedAt: yMap.get('updatedAt') || Date.now(),
      isDeleted: yMap.get('isDeleted') || false
    };

    // 解决冲突：使用最新的更新时间
    const localCard = await this.db.cards.get(cardId);
    if (!localCard || cardFromYjs.updatedAt > localCard.updatedAt) {
      // Yjs的数据更新，同步到IndexedDB
      await this.db.cards.put(cardFromYjs);
    } else if (localCard.updatedAt > cardFromYjs.updatedAt) {
      // 本地数据更新，同步到Yjs（反向同步）
      const yMap = yDoc.getMap('card');
      yMap.set('title', localCard.title);
      yMap.set('content', localCard.content);
      yMap.set('updatedAt', localCard.updatedAt);
      yMap.set('isDeleted', localCard.isDeleted);
    }
    // 如果时间戳相同，认为数据一致，无需操作
  }

  // 为新设备同步所有现有卡片
  async syncAllCardsFromYjs(): Promise<void> {
    // 1. 获取所有在Yjs中存在的卡片
    const allCardIds = new Set<string>();
    
    // 2. 遍历本地IndexedDB中的所有卡片
    const localCards = await this.db.cards.toArray();
    for (const card of localCards) {
      allCardIds.add(card.id);
    }

    // 3. 同步每个卡片
    for (const cardId of allCardIds) {
      await this.syncFromYjsToIndexedDB(cardId);
    }
  }

  // 为已存在的卡片创建Yjs文档（新设备首次同步时使用）
  private async createYjsDocForExistingCard(cardId: string): Promise<void> {
    const card = await this.db.cards.get(cardId);
    if (!card) return;

    // 创建Yjs文档
    const yDoc = new Y.Doc();
    const yMap = yDoc.getMap('card');
    
    // 将本地数据同步到Yjs
    yMap.set('id', card.id);
    yMap.set('title', card.title);
    yMap.set('content', card.content);
    yMap.set('createdAt', card.createdAt);
    yMap.set('updatedAt', card.updatedAt);
    yMap.set('isDeleted', card.isDeleted);

    // 配置持久化和同步
    const persistence = new IndexeddbPersistence(`card-${cardId}`, yDoc);
    await persistence.whenSynced;
    const provider = new WebrtcProvider(`card-${cardId}`, yDoc);
    
    this.yDocs.set(cardId, yDoc);
    this.providers.set(cardId, provider);
    this.persistences.set(cardId, persistence);
  }
}

#### 4.2.2 卡片管理功能
- 实现极简CRUD操作（通过Yjs自动同步）
- 添加实时协作编辑
- 实现软删除机制
- 添加空列表提示

#### 4.2.3 用户界面实现
- 卡片列表组件（实时排序）
- 卡片详情模态框（支持协作编辑）
- 卡片编辑模态框（实时同步）
- 删除确认对话框

### 4.3 第三阶段：网络状态管理 (1天)

#### 4.3.1 实时状态指示
```typescript
// hooks/useSyncStatus.ts
function useSyncStatus(cardId: string) {
  const [isOnline, setIsOnline] = useState(false);
  const [collaborators, setCollaborators] = useState([]);
  
  // Yjs自动提供同步状态
  useEffect(() => {
    const provider = new WebrtcProvider(`card-${cardId}`, yDoc);
    
    provider.on('status', ({ status }) => {
      setIsOnline(status === 'connected');
    });
    
    provider.awareness.on('change', () => {
      setCollaborators(Array.from(provider.awareness.getStates().values()));
    });
  }, [cardId]);
  
  return { isOnline, collaborators };
}
```

#### 4.3.2 离线模式处理
- 网络断开时自动切换到离线模式
- 重新连接后自动同步变更
- 添加同步状态指示器（在线/离线/同步中）

### 4.4 第四阶段：安全与优化 (1-2天)

#### 4.4.1 加密实现
```typescript
// services/EncryptionService.ts
class EncryptionService {
  async generateKey(password: string): Promise<CryptoKey> {
    // 使用PBKDF2生成加密密钥
  }
  
  async encrypt(data: string, key: CryptoKey): Promise<EncryptedData> {
    // AES-256-GCM加密
  }
  
  async decrypt(encryptedData: EncryptedData, key: CryptoKey): Promise<string> {
    // AES-256-GCM解密
  }
}
```

#### 4.4.2 性能优化
- 实现虚拟滚动（大量卡片时）
- 添加防抖处理（搜索、输入）
- 优化图片和媒体资源加载
- 实现懒加载机制

### 4.5 第五阶段：测试与部署 (1-2天)

#### 4.5.1 测试策略
- 单元测试：核心业务逻辑
- 集成测试：数据存储和同步
- E2E测试：关键用户流程
- 性能测试：大量数据场景

#### 4.5.2 部署配置
- PWA配置优化
- 构建脚本优化
- CDN部署配置
- 监控和错误追踪

## 5. 风险评估与应对策略

### 5.1 技术风险

#### 5.1.1 IndexedDB兼容性问题
- **风险**: 部分旧版浏览器不支持IndexedDB
- **概率**: 低 (现代浏览器支持率>95%)
- **影响**: 高 (无法存储数据)
- **应对策略**:
  - 添加IndexedDB可用性检测
  - 提供降级方案（localStorage）
  - 显示兼容性提示

#### 5.1.2 WebRTC连接失败
- **风险**: 网络环境限制WebRTC连接
- **概率**: 中 (企业网络、防火墙限制)
- **影响**: 中 (无法实现多设备同步)
- **应对策略**:
  - 实现连接状态检测
  - 提供手动同步选项
  - 添加网络诊断工具

#### 5.1.3 加密性能问题
- **风险**: 大量数据加密影响性能
- **概率**: 低 (现代硬件性能充足)
- **影响**: 中 (用户体验下降)
- **应对策略**:
  - 实现分批加密处理
  - 使用Web Worker避免阻塞主线程
  - 优化加密算法参数

### 5.2 数据安全

#### 5.2.1 数据丢失风险
- **风险**: 用户误操作或设备故障导致数据丢失
- **概率**: 中
- **影响**: 极高
- **应对策略**:
  - 实现自动备份机制
  - 添加数据导出功能（后续版本）
  - 提供数据恢复工具

#### 5.2.2 密码遗忘风险
- **风险**: 用户忘记密码导致数据无法解密
- **概率**: 高
- **影响**: 极高 (数据永久丢失)
- **应对策略**:
  - 提供密码提示功能
  - 实现密钥恢复机制（需要安全考虑）
  - 添加数据备份建议

### 5.3 用户体验

#### 5.3.1 首次使用复杂度
- **风险**: 首次使用需要设置密码，增加使用门槛
- **概率**: 高
- **影响**: 中 (用户流失)
- **应对策略**:
  - 提供可选的加密设置
  - 优化首次使用引导流程
  - 提供快速开始选项

#### 5.3.2 同步延迟感知
- **风险**: 用户感知到同步延迟，怀疑数据丢失
- **概率**: 中
- **影响**: 中 (用户信任度下降)
- **应对策略**:
  - 添加同步状态指示器
  - 实现实时同步状态反馈
  - 提供手动刷新功能

## 6. 开发里程碑

### 6.1 时间规划 (总计8-10天)

| 阶段 | 时间 | 关键交付物 | 验收标准 |
|------|------|------------|----------|
| 阶段1 | 1-2天 | 基础框架 | 项目可运行，基础UI完成 |
| 阶段2 | 3-4天 | 核心功能 | 卡片CRUD完整实现 |
| 阶段3 | 2-3天 | 数据同步 | 多设备同步可用 |
| 阶段4 | 1-2天 | 安全优化 | 加密存储，性能优化 |
| 阶段5 | 1-2天 | 测试部署 | 测试通过，PWA部署 |

### 6.2 质量门禁

#### 6.2.1 代码质量
- TypeScript零错误
- ESLint零警告
- 单元测试覆盖率>80%
- 关键路径E2E测试通过

#### 6.2.2 性能标准
- 首屏加载<3秒
- 卡片列表渲染<100ms
- 加密/解密操作<500ms
- 同步延迟<2秒

#### 6.2.3 用户体验
- 所有交互响应<100ms
- 离线模式可用性100%
- 错误恢复率>99%

## 7. 后续扩展规划

### 7.1 功能扩展
- 标签系统（基于需求优先级）
- 全文搜索功能
- 数据导出/导入
- 主题切换
- 回收站功能

### 7.2 技术升级
- 服务端同步备份
- 多端应用（iOS/Android）
- AI辅助功能
- 协作编辑

## 8. 结论

本技术方案基于需求文档制定，采用现代Web技术栈，确保功能完整实现的同时兼顾性能、安全和用户体验。通过渐进式开发策略，可以在8-10天内交付可用的MVP版本，并为后续扩展预留充足空间。

关键技术亮点：
- 离线优先的PWA架构
- 端到端加密存储
- 无冲突的CRDT数据同步
- 响应式设计，跨设备兼容
- 模块化架构，易于扩展

该方案经过风险评估，制定了详细的应对策略，能够有效规避已知风险，确保项目成功交付。