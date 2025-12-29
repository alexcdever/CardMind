# Mermaid 图表迁移指南

本文档列出所有文档中需要转换为 Mermaid 的图表位置。

## 为什么使用 Mermaid？

- ✅ **版本控制友好**: 纯文本，易于 diff
- ✅ **易于维护**: 修改图表只需修改文本
- ✅ **GitHub 原生支持**: 自动渲染，无需额外工具
- ✅ **统一风格**: 自动生成，风格一致

---

## 待转换图表清单

### 1. ARCHITECTURE.md

#### 1.1 架构概览图 (第7行)
**当前**: ASCII 框图
**改为**: Mermaid 架构图

```mermaid
graph TB
    subgraph "Flutter UI Layer"
        UI[界面、状态管理、用户交互<br/>Dart]
    end

    subgraph "Rust Business Layer"
        API[核心逻辑、Loro CRDT管理、数据同步]

        subgraph "Data Layer"
            Loro[Loro CRDT<br/>真理源/写]
            SQLite[SQLite Cache<br/>查询缓存/读]
            LoroFile[(loro_file<br/>文件持久化)]
        end

        Loro -->|订阅机制| SQLite
        Loro -->|文件持久化| LoroFile
    end

    UI <-->|flutter_rust_bridge| API

    style Loro fill:#f9f,stroke:#333,stroke-width:2px
    style SQLite fill:#bbf,stroke:#333,stroke-width:2px
    style LoroFile fill:#dfd,stroke:#333,stroke-width:2px
```

#### 1.2 数据流图 (第136-170行)
**当前**: ASCII 流程图
**改为**: Mermaid 流程图

```mermaid
flowchart TB
    subgraph Write["写操作流程 (Write Path)"]
        W1[用户编辑卡片] --> W2[Rust API 接收请求]
        W2 --> W3[修改 Loro 文档]
        W3 --> W4[loro.commit<br/>触发订阅回调]
        W4 --> W5[持久化到文件]
        W4 --> W6[更新 SQLite]
        W5 --> W7[返回成功]
        W6 --> W8[刷新缓存]
    end

    subgraph Read["读操作流程 (Read Path)"]
        R1[用户查询卡片列表] --> R2[Rust API 接收请求]
        R2 --> R3[查询 SQLite 缓存]
        R3 --> R4[返回结果<br/>快速]
    end

    style W4 fill:#faa,stroke:#333,stroke-width:2px
    style R3 fill:#afa,stroke:#333,stroke-width:2px
```

#### 1.3 P2P 同步架构图 (第562-580行)
**当前**: ASCII 双设备图
**改为**: Mermaid 序列图

```mermaid
sequenceDiagram
    participant DeviceA as Device A<br/>Loro Doc
    participant SyncEngineA as Sync Engine A
    participant P2P as libp2p P2P Network
    participant SyncEngineB as Sync Engine B
    participant DeviceB as Device B<br/>Loro Doc

    DeviceA->>SyncEngineA: 修改数据
    SyncEngineA->>P2P: 导出更新
    P2P->>SyncEngineB: P2P 传输
    SyncEngineB->>DeviceB: 导入更新
    DeviceB->>DeviceB: 更新 SQLite
```

---

### 2. DATABASE.md

#### 2.1 数据架构总览 (第8-24行)
**当前**: ASCII 框图
**改为**: Mermaid 架构图

```mermaid
graph TB
    Loro[Loro CRDT<br/>主数据源]
    SQLite[SQLite<br/>查询缓存层]

    Loro -->|订阅机制| SQLite

    subgraph "Loro 特性"
        L1[所有写操作]
        L2[文件持久化]
        L3[CRDT冲突解决]
        L4[P2P同步]
    end

    subgraph "SQLite 特性"
        S1[只读缓存]
        S2[快速查询]
        S3[全文搜索]
        S4[列表展示]
    end

    Loro -.-> L1
    Loro -.-> L2
    Loro -.-> L3
    Loro -.-> L4

    SQLite -.-> S1
    SQLite -.-> S2
    SQLite -.-> S3
    SQLite -.-> S4

    style Loro fill:#f9f,stroke:#333,stroke-width:3px
    style SQLite fill:#bbf,stroke:#333,stroke-width:2px
```

#### 2.2 数据流图 (第380-393行)
**当前**: ASCII 文本流程
**改为**: Mermaid 流程图

```mermaid
flowchart LR
    subgraph Write["写操作"]
        W1[用户编辑] --> W2[修改LoroDoc]
        W2 --> W3[追加到update.loro]
        W3 --> W4[触发订阅]
        W4 --> W5[更新SQLite缓存]
    end

    subgraph Read["读操作"]
        R1[用户查询] --> R2["SQLite缓存<br/>(WHERE is_deleted=0)"]
        R2 --> R3[快速返回]
    end

    subgraph Delete["删除操作"]
        D1[用户删除] --> D2[设置is_deleted=true]
        D2 --> D3[追加到update.loro]
        D3 --> D4[触发订阅]
        D4 --> D5[SQLite标记删除]
    end

    style W4 fill:#faa,stroke:#333,stroke-width:2px
    style R2 fill:#afa,stroke:#333,stroke-width:2px
```

---

### 3. PRD.md

#### 3.1 数据流图 (第106-114行)
**当前**: ASCII 文本流程
**改为**: Mermaid 流程图

```mermaid
flowchart TD
    User[用户操作] --> Loro[Loro文档修改]
    Loro --> Commit[Loro.commit]
    Commit --> Sub[触发订阅回调]
    Sub --> SQLite[更新SQLite缓存]
    SQLite --> UI[通知UI刷新]

    style Commit fill:#faa,stroke:#333,stroke-width:2px
    style Sub fill:#ffa,stroke:#333,stroke-width:2px
```

#### 3.2 P2P 同步流程 (第132-141行)
**当前**: ASCII 双设备文本
**改为**: Mermaid 序列图

```mermaid
sequenceDiagram
    participant A as 设备A
    participant B as 设备B

    A->>A: 修改Loro文档
    A->>A: Loro.export_updates()
    A->>B: 发送更新
    B->>B: Loro.import_updates()
    B->>B: 触发订阅更新SQLite
    B->>B: UI刷新
```

---

### 4. ROADMAP.md

#### 4.1 TDD 开发流程 (第516-543行)
**当前**: ASCII 文本流程
**改为**: Mermaid 流程图

```mermaid
flowchart LR
    Red[1. Red<br/>写失败的测试] --> Green[2. Green<br/>写最少代码让测试通过]
    Green --> Refactor[3. Refactor<br/>重构代码<br/>保持测试通过]
    Refactor --> Red

    style Red fill:#faa,stroke:#333,stroke-width:2px
    style Green fill:#afa,stroke:#333,stroke-width:2px
    style Refactor fill:#aaf,stroke:#333,stroke-width:2px
```

---

### 5. TESTING_GUIDE.md

#### 5.1 TDD 三步走 (第12-19行)
**当前**: ASCII 文本
**改为**: Mermaid 流程图

```mermaid
stateDiagram-v2
    [*] --> Red
    Red --> Green: 写代码实现
    Green --> Refactor: 测试通过
    Refactor --> Red: 重复循环
    Refactor --> [*]: 完成

    Red: 🔴 Red<br/>写失败的测试
    Green: 🟢 Green<br/>让测试通过
    Refactor: 🔵 Refactor<br/>重构优化
```

---

## 转换优先级

### 高优先级（立即转换）
1. ✅ ARCHITECTURE.md - 架构概览图
2. ✅ ARCHITECTURE.md - 数据流图
3. ✅ DATABASE.md - 数据架构总览

### 中优先级（Phase 1前转换）
4. ⏳ TESTING_GUIDE.md - TDD流程图
5. ⏳ ROADMAP.md - TDD开发流程
6. ⏳ PRD.md - 数据流图

### 低优先级（Phase 2前转换）
7. ⏳ ARCHITECTURE.md - P2P同步图
8. ⏳ PRD.md - P2P同步流程

---

## Mermaid 语法速查

### 流程图
```mermaid
flowchart LR
    A[方形] --> B(圆角)
    B --> C{菱形}
    C -->|Yes| D[结果1]
    C -->|No| E[结果2]
```

### 序列图
```mermaid
sequenceDiagram
    A->>B: 同步调用
    B-->>A: 返回
    A->>+B: 激活
    B->>-A: 停用
```

### 状态图
```mermaid
stateDiagram-v2
    [*] --> State1
    State1 --> State2
    State2 --> [*]
```

### 架构图
```mermaid
graph TB
    A[组件A] -->|关系| B[组件B]
    B --> C[组件C]

    subgraph "子系统"
        B
        C
    end
```

---

## 在线工具

- **Mermaid Live Editor**: https://mermaid.live/
- **GitHub渲染测试**: 直接在GitHub预览Markdown

---

## 注意事项

1. **GitHub 支持**: GitHub 自动渲染 Mermaid（无需插件）
2. **本地预览**: VS Code 需安装 Mermaid 预览插件
3. **语法检查**: 使用 Mermaid Live Editor 验证语法
4. **备份**: 转换前保留原ASCII图（注释掉）

---

**开始转换吧！** 🎨
