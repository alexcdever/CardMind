# CardMind 文档导航地图
# CardMind Documentation Navigation Map

**最后更新 Last Updated**: 2026-01-24
**维护者 Maintainer**: CardMind Team

---

## 📖 文档体系概览
## Documentation System Overview

CardMind 的文档分为 4 个主要层级，按优先级排序：
CardMind documentation is organized into 4 main layers, prioritized as follows:

1. **OpenSpec 规格文档** - 定义"做什么"和"怎么做" (What & How)
2. **架构决策记录 (ADR)** - 解释"为什么" (Why)
3. **项目约束** - 代码级别的强制约束
4. **产品文档** - 产品愿景和路线图

---

## 🗺️ 快速导航
## Quick Navigation

### 新开发者入门
### New Developer Onboarding

1. **第一步**: 阅读 [README.md](../README.md) - 项目概览
2. **第二步**: 阅读 [CLAUDE.md](../CLAUDE.md) - 开发指南
3. **第三步**: 查看 [产品愿景](./requirements/product_vision.md) - 理解产品目标
4. **第四步**: 浏览 [架构决策记录](./adr/README.md) - 理解关键决策
5. **第五步**: 查看本文档的"按模块导航"部分

### 按角色导航
### Navigation by Role

| 角色 Role | 推荐文档 Recommended Docs |
|-----------|---------------------------|
| **产品经理** | [产品愿景](./requirements/product_vision.md), [路线图](./roadmap.md), [功能规格](../openspec/specs/features/) |
| **架构师** | [ADR](./adr/README.md), [架构规格](../openspec/specs/architecture/), [系统设计](./architecture/system_design.md) |
| **后端开发** | [Domain 规格](../openspec/specs/domain/), [Architecture 规格](../openspec/specs/architecture/), [Rust 测试](../rust/tests/) |
| **前端开发** | [UI 规格](../openspec/specs/ui/), [Features 规格](../openspec/specs/features/), [Flutter 测试](../test/) |
| **测试工程师** | [测试指南](./testing/TESTING_GUIDE.md), [Spec-Test 映射](#spec-test-映射表) |
| **技术写作** | [规格编写指南](../openspec/engineering/spec_writing_guide.md), [目录约定](../openspec/engineering/directory_conventions.md) |

---

## 📚 按模块导航
## Navigation by Module

### 🎴 Card (卡片模块)
### Card Module

**核心概念**: 用户创建和管理的笔记卡片
**Core Concept**: Note cards created and managed by users

| 文档类型 | 路径 | 描述 |
|---------|------|------|
| **领域模型** | [domain/card/model.md](../openspec/specs/domain/card/model.md) | 卡片的业务定义 |
| **业务规则** | [domain/card/rules.md](../openspec/specs/domain/card/rules.md) | 卡片的约束和规则 |
| **存储实现** | [architecture/storage/card_store.md](../openspec/specs/architecture/storage/card_store.md) | CardStore 技术实现 |
| **功能规格** | [features/card_management/spec.md](../openspec/specs/features/card_management/spec.md) | 卡片管理功能 |
| **UI 规格** | [features/card_editor/](../openspec/specs/features/card_editor/) | 卡片编辑器 UI |
| **Rust 代码** | `rust/src/models/card.rs` | Card 数据结构 |
| **Rust 代码** | `rust/src/store/card_store.rs` | CardStore 实现 |
| **Flutter 代码** | `lib/models/card.dart` | Card 模型 |
| **测试** | 见 [Spec-Test 映射表](#card-模块测试映射) | - |

**架构决策**:
- 无特定 ADR (卡片是核心实体，设计较为直接)

---

### 🗂️ Pool (数据池模块)
### Pool Module

**核心概念**: 单一数据池，所有卡片的容器
**Core Concept**: Single data pool, container for all cards

| 文档类型 | 路径 | 描述 |
|---------|------|------|
| **领域模型** | [domain/pool/model.md](../openspec/specs/domain/pool/model.md) | 单池模型定义 |
| **业务规则** | [domain/pool/rules.md](../openspec/specs/domain/pool/rules.md) | 单池约束 |
| **存储实现** | [architecture/storage/pool_store.md](../openspec/specs/architecture/storage/pool_store.md) | PoolStore 技术实现 |
| **设备配置** | [architecture/storage/device_config.md](../openspec/specs/architecture/storage/device_config.md) | DeviceConfig 存储 |
| **功能规格** | [features/pool_management/spec.md](../openspec/specs/features/pool_management/spec.md) | 池管理功能 |
| **Rust 代码** | `rust/src/models/pool.rs` | Pool 数据结构 |
| **Rust 代码** | `rust/src/models/device_config.rs` | DeviceConfig 结构 |
| **Rust 代码** | `rust/src/store/pool_store.rs` | PoolStore 实现 |
| **测试** | `rust/tests/sp_spm_001_spec.rs` | SP-SPM-001: 单池模型测试 |

**架构决策**:
- [ADR-0001: 单池所有权模型](./adr/0001-单池所有权模型.md) - 为什么选择单池而非多池

---

### 🔄 Sync (同步模块)
### Sync Module

**核心概念**: P2P 设备间同步，基于 Loro CRDT
**Core Concept**: P2P device synchronization based on Loro CRDT

| 文档类型 | 路径 | 描述 |
|---------|------|------|
| **领域模型** | [domain/sync/model.md](../openspec/specs/domain/sync/model.md) | 同步版本和冲突模型 |
| **同步服务** | [architecture/sync/service.md](../openspec/specs/architecture/sync/service.md) | P2P 同步服务架构 |
| **设备发现** | [architecture/sync/peer_discovery.md](../openspec/specs/architecture/sync/peer_discovery.md) | mDNS 对等发现 |
| **冲突解决** | [architecture/sync/conflict_resolution.md](../openspec/specs/architecture/sync/conflict_resolution.md) | CRDT 冲突解决 |
| **订阅机制** | [architecture/sync/subscription.md](../openspec/specs/architecture/sync/subscription.md) | Loro 订阅机制 |
| **功能规格** | [features/p2p_sync/spec.md](../openspec/specs/features/p2p_sync/spec.md) | P2P 同步功能 |
| **UI 规格** | [features/sync_feedback/](../openspec/specs/features/sync_feedback/) | 同步状态反馈 UI |
| **Rust 代码** | `rust/src/services/sync_service.rs` | SyncService 实现 |
| **Rust 代码** | `rust/src/network/mdns.rs` | mDNS 发现实现 |
| **测试** | `rust/tests/sp_sync_006_spec.rs` | SP-SYNC-006: P2P 同步测试 |
| **测试** | `rust/tests/sp_sync_007_spec.rs` | SP-SYNC-007: 同步流测试 |
| **测试** | `rust/tests/sp_mdns_001_spec.rs` | SP-MDNS-001: mDNS 发现测试 |

**架构决策**:
- [ADR-0003: 技术约束](./adr/0003-技术约束.md) - P2P 同步架构选择

---

### 💾 Storage (存储模块)
### Storage Module

**核心概念**: Loro (CRDT) + SQLite (缓存) 双层架构
**Core Concept**: Dual-layer architecture with Loro (CRDT) + SQLite (cache)

| 文档类型 | 路径 | 描述 |
|---------|------|------|
| **双层架构** | [architecture/storage/dual_layer.md](../openspec/specs/architecture/storage/dual_layer.md) | 架构模式和原则 |
| **Loro 集成** | [architecture/storage/loro_integration.md](../openspec/specs/architecture/storage/loro_integration.md) | Loro CRDT 集成 |
| **SQLite 缓存** | [architecture/storage/sqlite_cache.md](../openspec/specs/architecture/storage/sqlite_cache.md) | SQLite 缓存层 |
| **系统设计** | [architecture/system_design.md](./architecture/system_design.md) | 系统设计文档 |
| **Rust 代码** | `rust/src/store/mod.rs` | Store 模块入口 |
| **Rust 代码** | `rust/src/loro/integration.rs` | Loro 集成实现 |
| **Rust 代码** | `rust/src/store/sqlite.rs` | SQLite 实现 |

**架构决策**:
- [ADR-0002: 双层架构](./adr/0002-双层架构.md) - 为什么选择 Loro + SQLite

---

### 🔐 Security (安全模块)
### Security Module

**核心概念**: 密码管理、密钥存储、隐私保护
**Core Concept**: Password management, keyring storage, privacy protection

| 文档类型 | 路径 | 描述 |
|---------|------|------|
| **密码管理** | [architecture/security/password.md](../openspec/specs/architecture/security/password.md) | bcrypt 密码管理 |
| **密钥存储** | [architecture/security/keyring.md](../openspec/specs/architecture/security/keyring.md) | Keyring 存储 |
| **隐私保护** | [architecture/security/privacy.md](../openspec/specs/architecture/security/privacy.md) | mDNS 隐私保护 |
| **Rust 代码** | `rust/src/security/` | 安全模块实现 |

---

### 🎨 UI System (UI 系统)
### UI System Module

**核心概念**: 跨平台自适应 UI 系统
**Core Concept**: Cross-platform adaptive UI system

| 文档类型 | 路径 | 描述 |
|---------|------|------|
| **设计令牌** | [ui_system/design_tokens.md](../openspec/specs/ui_system/design_tokens.md) | 颜色、字体、间距 |
| **自适应布局** | [ui/adaptive/layouts.md](../openspec/specs/ui/adaptive/layouts.md) | 自适应布局系统 |
| **自适应组件** | [ui/adaptive/components.md](../openspec/specs/ui/adaptive/components.md) | 自适应组件 |
| **平台检测** | [ui/adaptive/platform_detection.md](../openspec/specs/ui/adaptive/platform_detection.md) | 平台检测逻辑 |
| **UI 设计** | [design/](./design/) | UI 设计文档 |
| **交互设计** | [interaction/](./interaction/) | 交互设计文档 |
| **Flutter 代码** | `lib/adaptive/` | 自适应系统实现 |
| **Flutter 测试** | `test/specs/adaptive_ui_*.dart` | 自适应 UI 测试 |

**架构决策**:
- [ADR-0004: UI 设计系统](./adr/0004-UI设计系统.md) - UI 设计系统选择

---

### 🌉 Bridge (桥接模块)
### Bridge Module

**核心概念**: Flutter 与 Rust 的通信桥接
**Core Concept**: Communication bridge between Flutter and Rust

| 文档类型 | 路径 | 描述 |
|---------|------|------|
| **桥接规格** | [architecture/bridge/flutter_rust_bridge.md](../openspec/specs/architecture/bridge/flutter_rust_bridge.md) | Flutter-Rust 桥接 |
| **Rust 代码** | `rust/src/api/` | API 接口定义 |
| **Flutter 代码** | `lib/bridge/` | 桥接层实现 |

---

## 🧪 Spec-Test 映射表
## Spec-Test Mapping

### Rust 模块测试映射
### Rust Module Test Mapping

| 规格编号 | 规格文档 | 测试文件 | 状态 |
|---------|---------|---------|------|
| SP-SPM-001 | [domain/pool/model.md](../openspec/specs/domain/pool/model.md) | `rust/tests/sp_spm_001_spec.rs` | ✅ 已实现 |
| SP-SYNC-006 | [architecture/sync/service.md](../openspec/specs/architecture/sync/service.md) | `rust/tests/sp_sync_006_spec.rs` | ✅ 已实现 |
| SP-SYNC-007 | [architecture/sync/service.md](../openspec/specs/architecture/sync/service.md) | `rust/tests/sp_sync_007_spec.rs` | ✅ 已实现 |
| SP-MDNS-001 | [architecture/sync/peer_discovery.md](../openspec/specs/architecture/sync/peer_discovery.md) | `rust/tests/sp_mdns_001_spec.rs` | ✅ 已实现 |

**覆盖率**: 4/87 规格文档有显式的 Rust spec 测试 (~5%)

### Card 模块测试映射
### Card Module Test Mapping

| 规格文档 | 测试文件 | 状态 |
|---------|---------|------|
| [domain/card/model.md](../openspec/specs/domain/card/model.md) | ⚠️ 无显式 spec test | 需要补充 |
| [domain/card/rules.md](../openspec/specs/domain/card/rules.md) | ⚠️ 无显式 spec test | 需要补充 |
| [architecture/storage/card_store.md](../openspec/specs/architecture/storage/card_store.md) | ⚠️ 无显式 spec test | 需要补充 |

**建议**: 创建 `rust/tests/sp_card_001_spec.rs` 测试卡片模型和规则

### Flutter UI 测试映射
### Flutter UI Test Mapping

详见 [Flutter Spec-Test 映射表](./testing/FLUTTER_SPEC_TEST_MAP.md) (Phase 2 任务 2 创建)

---

## 📂 文档目录结构
## Documentation Directory Structure

```
CardMind/
├── README.md                          # 项目概览
├── CLAUDE.md                          # 开发指南
├── AGENTS.md                          # AI Agent 配置
│
├── docs/                              # 产品和技术文档
│   ├── DOCUMENTATION_MAP.md           # 本文档 (导航地图)
│   │
│   ├── adr/                           # 架构决策记录 (Why)
│   │   ├── README.md                  # ADR 索引
│   │   ├── 0001-单池所有权模型.md
│   │   ├── 0002-双层架构.md
│   │   ├── 0003-技术约束.md
│   │   ├── 0004-UI设计系统.md
│   │   └── 0005-日志系统.md
│   │
│   ├── requirements/                  # 产品需求
│   │   └── product_vision.md          # 产品愿景
│   │
│   ├── architecture/                  # 系统设计文档
│   │   ├── system_design.md           # 系统设计
│   │   ├── sync_mechanism.md          # 同步机制
│   │   └── data_flow.md               # 数据流
│   │
│   ├── design/                        # UI 设计文档
│   │   ├── mobile_ui_design.md
│   │   ├── desktop_ui_design.md
│   │   └── design_system.md
│   │
│   ├── interaction/                   # 交互设计文档
│   │   ├── mobile_interactions.md
│   │   ├── desktop_interactions.md
│   │   ├── gestures.md
│   │   └── keyboard_shortcuts.md
│   │
│   ├── testing/                       # 测试文档
│   │   ├── TESTING_GUIDE.md           # 测试指南
│   │   ├── FLUTTER_SPEC_TEST_MAP.md   # Flutter 映射表 (Phase 2)
│   │   └── (其他测试文档)
│   │
│   ├── roadmap.md                     # 开发路线图
│   └── user_guide.md                  # 用户使用手册
│
├── openspec/                          # OpenSpec 规格体系
│   ├── specs/                         # 规格文档 (What & How)
│   │   ├── README.md                  # 规格索引
│   │   ├── domain/                    # 领域层 (业务模型)
│   │   ├── architecture/              # 架构层 (技术实现)
│   │   ├── features/                  # 功能层 (用户功能)
│   │   ├── ui/                        # UI 层 (界面组件)
│   │   ├── ui_system/                 # UI 系统 (设计令牌)
│   │   └── api/                       # API 层 (公共接口)
│   │
│   ├── engineering/                   # 工程指南
│   │   ├── README.md                  # 指南索引
│   │   ├── guide.md                   # Spec Coding 方法论
│   │   ├── spec_writing_guide.md      # 规格编写指南
│   │   ├── directory_conventions.md   # 目录约定
│   │   └── (其他指南)
│   │
│   └── changes/                       # 变更记录
│       └── (OpenSpec 变更目录)
│
├── rust/                              # Rust 后端代码
│   ├── src/
│   │   ├── models/                    # 数据模型
│   │   ├── store/                     # 存储层
│   │   ├── services/                  # 服务层
│   │   ├── network/                   # 网络层
│   │   ├── loro/                      # Loro 集成
│   │   ├── security/                  # 安全模块
│   │   └── api/                       # API 接口
│   └── tests/
│       ├── sp_spm_001_spec.rs         # 单池模型测试
│       ├── sp_sync_006_spec.rs        # P2P 同步测试
│       ├── sp_sync_007_spec.rs        # 同步流测试
│       └── sp_mdns_001_spec.rs        # mDNS 发现测试
│
└── test/                              # Flutter 测试
    ├── specs/                         # Spec 测试
    │   ├── home_screen_spec_test.dart
    │   ├── card_editor_spec_test.dart
    │   └── (其他 spec 测试)
    └── widgets/                       # Widget 测试
        └── (组件测试)
```

---

## 🔍 如何查找文档
## How to Find Documentation

### 按问题类型查找
### Find by Question Type

| 问题 | 查找位置 |
|------|---------|
| "这个功能是做什么的？" | [features/](../openspec/specs/features/) |
| "为什么这样设计？" | [docs/adr/](./adr/) |
| "怎么实现的？" | [architecture/](../openspec/specs/architecture/) |
| "业务规则是什么？" | [domain/](../openspec/specs/domain/) |
| "UI 怎么设计的？" | [ui/](../openspec/specs/ui/) 或 [design/](./design/) |
| "如何测试？" | [testing/](./testing/) |
| "产品目标是什么？" | [requirements/product_vision.md](./requirements/product_vision.md) |
| "开发计划是什么？" | [roadmap.md](./roadmap.md) |

### 按文件名查找
### Find by Filename

```bash
# 查找规格文档
find openspec/specs -name "*pool*" -type f

# 查找测试文件
find rust/tests -name "sp_*.rs"
find test -name "*_spec_test.dart"

# 查找 ADR
ls docs/adr/

# 全文搜索
grep -r "单池模型" openspec/specs/
```

---

## 📊 文档统计
## Documentation Statistics

| 类型 | 数量 | 位置 |
|------|------|------|
| **规格文档** | 87 个 | `openspec/specs/` |
| **架构决策记录** | 5 个 | `docs/adr/` |
| **工程指南** | 9 个 | `openspec/engineering/` |
| **Rust Spec 测试** | 4 个 | `rust/tests/sp_*.rs` |
| **Flutter 测试** | 38 个 | `test/` |
| **产品文档** | 2 个 | `docs/requirements/`, `docs/roadmap.md` |
| **设计文档** | 7 个 | `docs/design/`, `docs/interaction/` |

---

## 🔄 文档更新流程
## Documentation Update Process

### 何时更新文档
### When to Update Documentation

1. **新增功能**: 先写规格 → 再写测试 → 最后写代码
2. **修改功能**: 先更新规格 → 更新测试 → 更新代码
3. **架构变更**: 先写 ADR → 更新规格 → 更新代码
4. **重构**: 更新规格和 ADR (如果架构改变)

### 文档更新检查清单
### Documentation Update Checklist

- [ ] 规格文档已更新
- [ ] 测试已更新 (如果有)
- [ ] ADR 已创建/更新 (如果是架构决策)
- [ ] 本导航地图已更新 (如果是新模块)
- [ ] README.md 已更新 (如果影响项目概览)
- [ ] 所有链接有效

---

## 🆘 获取帮助
## Getting Help

### 文档问题
### Documentation Issues

- 发现断链或错误: 提交 Issue 到 GitHub
- 文档不清晰: 提交 PR 改进文档
- 需要新文档: 在 Issue 中说明需求

### 开发问题
### Development Issues

- 查看 [CLAUDE.md](../CLAUDE.md) 的"常见问题"部分
- 查看相关模块的规格文档
- 查看对应的 ADR 理解设计决策

---

**维护说明**: 本文档应在每次重大文档重组后更新。
**Maintenance Note**: This document should be updated after each major documentation reorganization.

**最后更新**: 2026-01-24 (Phase 2 - 结构重建)
**Last Updated**: 2026-01-24 (Phase 2 - Structure Rebuild)
