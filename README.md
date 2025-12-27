# CardMind

一款简洁、高效的卡片笔记应用，支持离线优先和P2P多设备同步。

## 项目简介

CardMind 是一款专注于个人知识管理的卡片式笔记应用。通过卡片的形式组织和管理你的笔记、想法和知识片段。应用采用离线优先设计，基于 CRDT 技术实现可靠的多设备同步，支持完全离线编辑和自动冲突解决。

## 核心特性

- **卡片式笔记**: 用卡片组织你的想法和知识，每张卡片一个主题
- **Markdown支持**: 支持完整的Markdown格式，方便编写结构化笔记
- **离线优先**: 基于Loro CRDT，所有数据本地存储，无网络时也能正常使用
- **P2P同步**: 去中心化的点对点同步，无需依赖服务器
- **自动冲突解决**: CRDT算法自动处理编辑冲突，永不丢失数据
- **跨平台**: 基于Flutter开发，支持iOS、Android、Windows、macOS、Linux

## 技术栈

- **前端**: Flutter 3.x (Dart)
- **后端逻辑**: Rust
- **CRDT引擎**: Loro (文件持久化)
- **数据库**: SQLite (读取缓存层)
- **P2P同步**: libp2p (规划中)
- **桥接**: flutter_rust_bridge

## 项目状态

当前处于需求设计和架构规划阶段。

## 依赖版本锁定

> 本项目在开发阶段锁定以下关键依赖版本，确保可重现构建

### Rust依赖（Cargo.toml）

```toml
[dependencies]
# CRDT引擎（核心依赖）
loro = "1.0"

# 数据库
rusqlite = { version = "0.31", features = ["bundled"] }

# 序列化
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"

# UUID v7（时间排序）
uuid = { version = "1.7", features = ["v7", "serde"] }

# 时间处理
chrono = { version = "0.4", features = ["serde"] }

# 异步运行时
tokio = { version = "1.35", features = ["full"] }

# Flutter桥接
flutter_rust_bridge = "2.0"

# 日志
tracing = "0.1"
tracing-subscriber = "0.3"

# 错误处理
thiserror = "1.0"
anyhow = "1.0"

# P2P网络（Phase 2）
# libp2p = { version = "0.53", optional = true }
```

### Flutter依赖（pubspec.yaml）

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 状态管理
  provider: ^6.0.0

  # Markdown渲染
  flutter_markdown: ^0.6.0

  # Rust桥接
  flutter_rust_bridge: ^2.0.0

  # 本地存储（配置等）
  shared_preferences: ^2.2.0

  # 日志
  logger: ^2.0.0

  # UUID v7
  uuid: ^4.0.0
```

### 更新策略

- **MVP阶段**: 不主动升级依赖，保持稳定
- **Bug修复**: 仅小版本升级（如1.0.0 → 1.0.1）
- **大版本升级**: MVP完成后再评估
- **新依赖**: 优先选择成熟稳定的库

## 快速开始

> 开发中，敬请期待

## Git Commit规范

本项目采用简化的 Conventional Commits 规范：

```
<type>: <subject>

<body (optional)>
```

### Type类型

- `feat`: 新功能
- `fix`: Bug修复
- `refactor`: 代码重构（不改变功能）
- `test`: 测试相关
- `docs`: 文档更新
- `chore`: 构建/工具/依赖变动
- `style`: 代码格式调整（不影响逻辑）

### 示例

```bash
# 好的commit
feat: 实现卡片创建API

- 添加create_card函数
- Loro订阅机制同步到SQLite
- 测试覆盖率82%

fix: 修复卡片删除后SQLite未更新bug

订阅回调中缺少删除事件处理，导致软删除标记未更新。

test: 添加Loro到SQLite同步的集成测试

docs: 更新API文档，补充错误码说明
```

```bash
# 不好的commit（避免）
update code
fix bug
修改了一些东西
```

### 原则

- **主题行简洁**: 不超过50字符
- **描述清晰**: 说明做了什么和为什么
- **一次一件事**: 每个commit只做一件事
- **测试通过**: commit前确保测试通过

## 文档

- [产品需求文档 (PRD)](docs/PRD.md)
- [技术架构设计](docs/ARCHITECTURE.md)
- [数据库设计](docs/DATABASE.md)
- [开发路线图](docs/ROADMAP.md)
- [API接口定义](docs/API.md)
- [测试指南](docs/TESTING_GUIDE.md)
- [日志规范](docs/LOGGING.md)

## 开发计划

### 第一阶段 - MVP (最小可行产品)
- 卡片基础功能（创建、编辑、删除、查看）
- Markdown内容支持
- Loro CRDT集成（本地文件持久化）
- SQLite缓存层（快速查询）

### 第二阶段 - P2P同步
- libp2p集成
- 设备发现和连接
- CRDT数据同步
- 同步状态管理

### 第三阶段 - 优化完善
- 性能优化
- UI/UX改进
- 搜索功能
- 标签系统（可选）

