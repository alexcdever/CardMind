# Architecture Layer Documentation
# 架构层文档

**Version**: 1.0.0
**版本**: 1.0.0

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

---

## Overview
## 概述

This directory contains technical architecture specifications for CardMind, describing implementation details, design patterns, and technology choices.

本目录包含 CardMind 的技术架构规格，描述实现细节、设计模式和技术选择。

**Purpose**:
**目的**:
- Document technical implementation details
- 记录技术实现细节
- Specify technology stack and libraries
- 指定技术栈和库
- Define design patterns and architectural decisions
- 定义设计模式和架构决策
- Guide developers in implementation
- 指导开发人员实现

---

## Directory Structure
## 目录结构

```
architecture/
├── storage/              # Storage layer implementations
│   ├── card_store.md    # CardStore technical implementation
│   ├── pool_store.md    # PoolStore technical implementation
│   ├── device_config.md # Device configuration storage
│   ├── dual_layer.md    # Loro + SQLite dual-layer architecture
│   ├── sqlite_cache.md  # SQLite caching layer details
│   └── loro_integration.md # Loro CRDT integration
├── sync/                 # Synchronization implementations
│   ├── service.md       # P2P sync service architecture
│   ├── peer_discovery.md # mDNS peer discovery
│   ├── conflict_resolution.md # CRDT conflict resolution
│   └── subscription.md  # Loro subscription mechanism
├── security/             # Security implementations (planned)
│   ├── password.md      # Password hashing with bcrypt
│   ├── keyring.md       # Keyring integration
│   └── privacy.md       # Privacy protection mechanisms
├── bridge/               # Platform bridge implementations (planned)
│   └── flutter_rust_bridge.md # Flutter-Rust bridge
└── README.md            # This file
```

---

## Storage Layer
## 存储层

### Dual-Layer Architecture
### 双层架构

CardMind uses a dual-layer storage architecture that separates write operations from read operations:

CardMind 使用双层存储架构，将写操作与读操作分离：

**Write Layer (Loro CRDT)**:
**写入层（Loro CRDT）**:
- Source of truth for all data
- 所有数据的数据源
- Conflict-free synchronization
- 无冲突同步
- P2P sync capability
- P2P 同步能力
- File-based persistence
- 基于文件的持久化

**Read Layer (SQLite)**:
**读取层（SQLite）**:
- Optimized for queries
- 优化查询
- Indexed for fast access
- 索引以快速访问
- Full-text search (FTS5)
- 全文搜索（FTS5）
- Eventually consistent with Loro
- 与 Loro 最终一致

**Key Documents**:
**关键文档**:
- [storage/dual_layer.md](storage/dual_layer.md) - Architecture overview
- [storage/dual_layer.md](storage/dual_layer.md) - 架构概述
- [storage/card_store.md](storage/card_store.md) - Card data management
- [storage/card_store.md](storage/card_store.md) - 卡片数据管理
- [storage/pool_store.md](storage/pool_store.md) - Pool data management
- [storage/pool_store.md](storage/pool_store.md) - 池数据管理
- [storage/sqlite_cache.md](storage/sqlite_cache.md) - SQLite optimization
- [storage/sqlite_cache.md](storage/sqlite_cache.md) - SQLite 优化
- [storage/loro_integration.md](storage/loro_integration.md) - Loro CRDT integration
- [storage/loro_integration.md](storage/loro_integration.md) - Loro CRDT 集成

---

## Synchronization Layer
## 同步层

### P2P Sync Architecture
### P2P 同步架构

CardMind implements peer-to-peer synchronization using Loro CRDT for conflict-free data merging:

CardMind 使用 Loro CRDT 实现对等点同步以进行无冲突数据合并：

**Components**:
**组件**:
- **Peer Discovery**: mDNS-based local network discovery
- **对等点发现**: 基于 mDNS 的本地网络发现
- **Conflict Resolution**: Automatic CRDT-based merging
- **冲突解决**: 基于 CRDT 的自动合并
- **Subscription**: Automatic SQLite updates on Loro changes
- **订阅**: Loro 变更时自动更新 SQLite
- **Incremental Sync**: Only sync changed data
- **增量同步**: 仅同步变更的数据

**Key Documents**:
**关键文档**:
- [sync/service.md](sync/service.md) - P2P sync service
- [sync/service.md](sync/service.md) - P2P 同步服务
- [sync/peer_discovery.md](sync/peer_discovery.md) - mDNS discovery
- [sync/peer_discovery.md](sync/peer_discovery.md) - mDNS 发现
- [sync/conflict_resolution.md](sync/conflict_resolution.md) - CRDT conflict resolution
- [sync/conflict_resolution.md](sync/conflict_resolution.md) - CRDT 冲突解决
- [sync/subscription.md](sync/subscription.md) - Loro subscription mechanism
- [sync/subscription.md](sync/subscription.md) - Loro 订阅机制

---

## Technology Stack
## 技术栈

### Core Technologies
### 核心技术

**Storage**:
**存储**:
- **Loro** (v0.16+): CRDT library for conflict-free sync
- **Loro**（v0.16+）: 用于无冲突同步的 CRDT 库
- **SQLite** (v3.40+): Embedded database with FTS5
- **SQLite**（v3.40+）: 带 FTS5 的嵌式数据库
- **rusqlite** (v0.30+): Rust SQLite bindings
- **rusqlite**（v0.30+）: Rust SQLite 绑定

**Networking**:
**网络**:
- **mdns-sd**: mDNS service discovery
- **mdns-sd**: mDNS 服务发现
- **tokio**: Async runtime
- **tokio**: 异步运行时

**Security**:
**安全**:
- **bcrypt**: Password hashing
- **bcrypt**: 密码哈希
- **sha2**: SHA-256 for privacy protection
- **sha2**: 用于隐私保护的 SHA-256

**Platform Bridge**:
**平台桥接**:
- **flutter_rust_bridge**: Flutter-Rust interop
- **flutter_rust_bridge**: Flutter-Rust 互操作

---

## Design Patterns
## 设计模式

### Architectural Patterns
### 架构模式

**CQRS (Command Query Responsibility Segregation)**:
**CQRS（命令查询职责分离）**:
- Write operations go to Loro (command)
- 写操作进入 Loro（命令）
- Read operations go to SQLite (query)
- 读操作进入 SQLite（查询）
- Eventual consistency between layers
- 层之间的最终一致性

**Observer Pattern**:
**观察者模式**:
- Loro document subscriptions
- Loro 文档订阅
- Automatic SQLite updates
- 自动 SQLite 更新
- Event-driven architecture
- 事件驱动架构

**Repository Pattern**:
**仓储模式**:
- CardStore and PoolStore as data access layers
- CardStore 和 PoolStore 作为数据访问层
- Abstract storage implementation details
- 抽象存储实现细节
- Clean separation of concerns
- 清晰的关注点分离

**Cache-Aside Pattern**:
**旁路缓存模式**:
- SQLite as cache for Loro
- SQLite 作为 Loro 的缓存
- In-memory LRU cache for hot documents
- 热文档的内存 LRU 缓存
- Lazy loading and eviction
- 延迟加载和驱逐

---

## Performance Characteristics
## 性能特征

### Storage Performance
### 存储性能

**Read Operations**:
**读操作**:
- Query 1000 cards: < 10ms
- 查询 1000 张卡片: < 10ms
- Full-text search: < 100ms
- 全文搜索: < 100ms
- Single card lookup: < 1ms
- 单张卡片查找: < 1ms

**Write Operations**:
**写操作**:
- Create card: < 50ms
- 创建卡片: < 50ms
- Update card: < 50ms
- 更新卡片: < 50ms
- Subscription callback: < 1ms
- 订阅回调: < 1ms

### Sync Performance
### 同步性能

**Peer Discovery**:
**对等点发现**:
- mDNS discovery: < 5s
- mDNS 发现: < 5s
- Connection establishment: < 1s
- 连接建立: < 1s

**Data Sync**:
**数据同步**:
- Incremental update: ~100 bytes per operation
- 增量更新: 每个操作约 100 字节
- Import speed: ~1ms per update
- 导入速度: 每次更新约 1ms
- Export speed: ~0.5ms per update
- 导出速度: 每次更新约 0.5ms

---

## Security Considerations
## 安全考虑

### Data Security
### 数据安全

**Password Protection**:
**密码保护**:
- bcrypt hashing with cost factor 12
- 使用成本因子 12 的 bcrypt 哈希
- Constant-time comparison
- 恒定时间比较

**Privacy Protection**:
**隐私保护**:
- Device ID obfuscation in mDNS
- mDNS 中的设备 ID 混淆
- Pool ID hashing
- 池 ID 哈希
- Local network only (no internet exposure)
- 仅限本地网络（无互联网暴露）

**Data Isolation**:
**数据隔离**:
- Pool-based filtering
- 基于池的过滤
- No cross-pool data leakage
- 无跨池数据泄漏
- Device-level access control
- 设备级访问控制

---

## What Belongs Here
## 应该包含什么

**✅ Should Include**:
**✅ 应该包含**:
- Technical architecture design
- 技术架构设计
- Implementation patterns and best practices
- 实现模式和最佳实践
- Technology stack choices and rationale
- 技术栈选择和理由
- Performance optimization strategies
- 性能优化策略
- Security implementation details
- 安全实现细节
- Data flow and state management
- 数据流和状态管理
- Error handling and retry mechanisms
- 错误处理和重试机制
- Technical constraints and limitations
- 技术约束和限制

**❌ Should NOT Include**:
**❌ 不应该包含**:
- Business rule definitions (belongs in domain layer)
- 业务规则定义（属于领域层）
- User feature descriptions (belongs in features layer)
- 用户功能描述（属于功能层）
- UI component implementations (belongs in ui layer)
- UI 组件实现（属于 UI 层）

---

## Writing Guidelines
## 编写指南

### Use Technical Language
### 使用技术语言

**Good Example**:
**好的示例**:
```markdown
The system SHALL use Loro CRDT as the write layer and SQLite as the read layer, maintaining synchronization through subscription mechanisms.

系统应使用 Loro CRDT 作为写入层，SQLite 作为读取层，通过订阅机制保持同步。
```

**Bad Example**:
**不好的示例**:
```markdown
The system SHALL save card data.

系统应保存卡片数据。
```

### Document Implementation Details
### 记录实现细节

Include code examples, data structures, and algorithms.

包含代码示例、数据结构和算法。

### Include Performance and Security Considerations
### 包含性能和安全考虑

Document performance characteristics and security measures.

记录性能特征和安全措施。

### Reference ADRs
### 引用架构决策记录

Link to relevant Architecture Decision Records.

链接到相关的架构决策记录。

---

## Related Documentation
## 相关文档

**Domain Layer**:
**领域层**:
- [../domain/README.md](../domain/README.md) - Business rules and domain models
- [../domain/README.md](../domain/README.md) - 业务规则和领域模型

**Features Layer**:
**功能层**:
- [../features/README.md](../features/README.md) - User-facing features
- [../features/README.md](../features/README.md) - 面向用户的功能

**UI Layer**:
**UI 层**:
- [../ui/README.md](../ui/README.md) - User interface specifications
- [../ui/README.md](../ui/README.md) - 用户界面规格

**ADRs**:
**架构决策记录**:
- [../../docs/adr/](../../docs/adr/) - Architecture Decision Records
- [../../docs/adr/](../../docs/adr/) - 架构决策记录

---

**Authors**: CardMind Team
**作者**: CardMind Team
