# CardMind 规格中心

> **Spec Coding 方法论**: 测试即规格,规格即文档

主规格文档入口，所有功能规格都集中在这里管理。

---

## 🔔 重要通知：目录结构已重组

**迁移日期**: 2026-01-23
**新结构**: 四层架构组织 (Four-Layer Architecture)

所有规格已重组为清晰的四层架构：
- 🏗️ `domain/` - 领域模型和业务规则（业务语言）
- 🔧 `architecture/` - 技术架构和实现模式（技术细节）
- ✨ `features/` - 用户功能和业务流程（用户视角）
- 🎨 `ui/` - UI 组件和屏幕（按平台分离）

详细约定见 [规格编写指南](../engineering/spec_writing_guide.md)

---

## 📂 目录结构

```
openspec/specs/
├── domain/              # 领域层：业务模型和规则
│   ├── card/           # 卡片领域模型
│   ├── pool/           # 数据池领域模型
│   ├── sync/           # 同步领域模型
│   └── types.md        # 通用类型定义
│
├── architecture/        # 架构层：技术实现
│   ├── storage/        # 存储架构（Loro + SQLite）
│   ├── sync/           # 同步架构（P2P、CRDT）
│   ├── security/       # 安全架构（密码、密钥）
│   └── bridge/         # 跨平台桥接
│
├── features/            # 功能层：用户功能
│   ├── card_management/      # 卡片管理
│   ├── pool_management/      # 池管理
│   ├── p2p_sync/            # P2P 同步
│   ├── search_and_filter/   # 搜索和过滤
│   └── settings/            # 设置
│
└── ui/                  # UI 层：界面组件
    ├── screens/        # 屏幕（mobile/desktop/shared）
    ├── components/     # 组件（mobile/desktop/shared）
    └── adaptive/       # 自适应系统
```

**工程指南**: 参见 [openspec/engineering/](../engineering/)
**架构决策**: 参见 [docs/adr/](../../docs/adr/)

---

## 📋 规格文档索引

### 🏗️ Domain Layer (领域层)

**用途**: 定义业务模型和规则，使用业务语言，不包含技术实现细节。

| 文档 | 描述 | 状态 |
|------|------|------|
| [types.md](./domain/types.md) | 通用类型系统 | ✅ 完成 |
| [card/model.md](./domain/card/model.md) | 卡片领域模型 | ✅ 完成 |
| [card/rules.md](./domain/card/rules.md) | 卡片业务规则 | ✅ 完成 |
| [pool/model.md](./domain/pool/model.md) | 单池模型核心规格 | ✅ 完成 |
| [sync/model.md](./domain/sync/model.md) | 同步领域模型 | ✅ 完成 |

### 🔧 Architecture Layer (架构层)

**用途**: 定义技术实现、存储方案、同步机制等技术细节。

#### Storage (存储)
| 文档 | 描述 | 状态 |
|------|------|------|
| [dual_layer.md](./architecture/storage/dual_layer.md) | Loro + SQLite 双层架构 | ✅ 完成 |
| [card_store.md](./architecture/storage/card_store.md) | 卡片存储实现 | ✅ 完成 |
| [pool_store.md](./architecture/storage/pool_store.md) | 池存储实现 | ✅ 完成 |
| [device_config.md](./architecture/storage/device_config.md) | 设备配置存储 | ✅ 完成 |
| [loro_integration.md](./architecture/storage/loro_integration.md) | Loro CRDT 集成 | ✅ 完成 |
| [sqlite_cache.md](./architecture/storage/sqlite_cache.md) | SQLite 缓存层 | ✅ 完成 |

#### Sync (同步)
| 文档 | 描述 | 状态 |
|------|------|------|
| [service.md](./architecture/sync/service.md) | P2P 同步服务 | ✅ 完成 |
| [peer_discovery.md](./architecture/sync/peer_discovery.md) | mDNS 对等发现 | ✅ 完成 |
| [conflict_resolution.md](./architecture/sync/conflict_resolution.md) | CRDT 冲突解决 | ✅ 完成 |
| [subscription.md](./architecture/sync/subscription.md) | Loro 订阅机制 | ✅ 完成 |

#### Security (安全)
| 文档 | 描述 | 状态 |
|------|------|------|
| [password.md](./architecture/security/password.md) | bcrypt 密码管理 | ✅ 完成 |
| [keyring.md](./architecture/security/keyring.md) | Keyring 密钥存储 | ✅ 完成 |
| [privacy.md](./architecture/security/privacy.md) | mDNS 隐私保护 | ✅ 完成 |

#### Bridge (桥接)
| 文档 | 描述 | 状态 |
|------|------|------|
| [flutter_rust_bridge.md](./architecture/bridge/flutter_rust_bridge.md) | Flutter-Rust 集成 | ✅ 完成 |

### ✨ Features Layer (功能层)

**用途**: 描述完整的用户功能和业务流程，从用户视角出发。

| 文档 | 描述 | 状态 |
|------|------|------|
| [card_management/spec.md](./features/card_management/spec.md) | 卡片管理功能 | ✅ 完成 |
| [pool_management/spec.md](./features/pool_management/spec.md) | 池管理功能 | ✅ 完成 |
| [p2p_sync/spec.md](./features/p2p_sync/spec.md) | P2P 同步功能 | ✅ 完成 |
| [search_and_filter/spec.md](./features/search_and_filter/spec.md) | 搜索和过滤功能 | ✅ 完成 |
| [settings/spec.md](./features/settings/spec.md) | 设置功能 | ✅ 完成 |

### 🎨 UI Layer (UI 层)

**用途**: 定义 UI 组件和屏幕，按平台分离（mobile/desktop/shared）。

#### Screens (屏幕)
| 文档 | 平台 | 状态 |
|------|------|------|
| [mobile/home_screen.md](./ui/screens/mobile/home_screen.md) | Mobile | ✅ 完成 |
| [desktop/home_screen.md](./ui/screens/desktop/home_screen.md) | Desktop | ✅ 完成 |
| [mobile/card_editor_screen.md](./ui/screens/mobile/card_editor_screen.md) | Mobile | ✅ 完成 |
| [desktop/card_editor_screen.md](./ui/screens/desktop/card_editor_screen.md) | Desktop | ✅ 完成 |
| [mobile/card_detail_screen.md](./ui/screens/mobile/card_detail_screen.md) | Mobile | ✅ 完成 |
| [mobile/sync_screen.md](./ui/screens/mobile/sync_screen.md) | Mobile | ✅ 完成 |
| [mobile/settings_screen.md](./ui/screens/mobile/settings_screen.md) | Mobile | ✅ 完成 |
| [desktop/settings_screen.md](./ui/screens/desktop/settings_screen.md) | Desktop | ✅ 完成 |
| [shared/onboarding_screen.md](./ui/screens/shared/onboarding_screen.md) | Shared | ✅ 完成 |

#### Components (组件)
| 文档 | 平台 | 状态 |
|------|------|------|
| [mobile/card_list_item.md](./ui/components/mobile/card_list_item.md) | Mobile | ✅ 完成 |
| [desktop/card_list_item.md](./ui/components/desktop/card_list_item.md) | Desktop | ✅ 完成 |
| [mobile/mobile_nav.md](./ui/components/mobile/mobile_nav.md) | Mobile | ✅ 完成 |
| [desktop/desktop_nav.md](./ui/components/desktop/desktop_nav.md) | Desktop | ✅ 完成 |
| [mobile/fab.md](./ui/components/mobile/fab.md) | Mobile | ✅ 完成 |
| [mobile/gestures.md](./ui/components/mobile/gestures.md) | Mobile | ✅ 完成 |
| [desktop/toolbar.md](./ui/components/desktop/toolbar.md) | Desktop | ✅ 完成 |
| [desktop/context_menu.md](./ui/components/desktop/context_menu.md) | Desktop | ✅ 完成 |
| [shared/note_card.md](./ui/components/shared/note_card.md) | Shared | ✅ 完成 |
| [shared/fullscreen_editor.md](./ui/components/shared/fullscreen_editor.md) | Shared | ✅ 完成 |
| [shared/sync_status_indicator.md](./ui/components/shared/sync_status_indicator.md) | Shared | ✅ 完成 |
| [shared/sync_details_dialog.md](./ui/components/shared/sync_details_dialog.md) | Shared | ✅ 完成 |
| [shared/device_manager_panel.md](./ui/components/shared/device_manager_panel.md) | Shared | ✅ 完成 |
| [shared/settings_panel.md](./ui/components/shared/settings_panel.md) | Shared | ✅ 完成 |

#### Adaptive System (自适应系统)
| 文档 | 描述 | 状态 |
|------|------|------|
| [adaptive/layouts.md](./ui/adaptive/layouts.md) | 自适应布局系统 | ✅ 完成 |
| [adaptive/components.md](./ui/adaptive/components.md) | 自适应组件 | ✅ 完成 |
| [adaptive/platform_detection.md](./ui/adaptive/platform_detection.md) | 平台检测逻辑 | ✅ 完成 |

### 🔌 Legacy (遗留文档)

| 文档 | 描述 | 状态 |
|------|------|------|
| [api/api_spec.md](./api/api_spec.md) | Rust API 统一规格 | ✅ 完成 |
| [ui_system/design_tokens.md](./ui_system/design_tokens.md) | 设计令牌 | ✅ 完成 |
| [ui_system/responsive_layout.md](./ui_system/responsive_layout.md) | 响应式布局 | ✅ 完成 |
| [ui_system/adaptive_ui_components.md](./ui_system/adaptive_ui_components.md) | 自适应组件 | ✅ 完成 |
| [ui_system/shared_widgets.md](./ui_system/shared_widgets.md) | 共享组件 | 📝 占位符 |

---

## 🚀 快速开始

### 1. 查看规格文档

```bash
# Domain Layer (领域层)
cat openspec/specs/domain/pool/model.md
cat openspec/specs/domain/card/model.md

# Architecture Layer (架构层)
cat openspec/specs/architecture/storage/dual_layer.md
cat openspec/specs/architecture/sync/service.md

# Features Layer (功能层)
cat openspec/specs/features/card_management/spec.md
cat openspec/specs/features/p2p_sync/spec.md

# UI Layer (UI 层)
cat openspec/specs/ui/screens/mobile/home_screen.md
cat openspec/specs/ui/components/shared/note_card.md
cat openspec/specs/ui/adaptive/layouts.md
```

### 2. 运行可执行规格

```bash
# 后端规格测试
cd rust
cargo test --test pool_model_test
cargo test --test sync_service_test
cargo test --test device_config_test

# Flutter 规格测试
flutter test test/specs/
```

---

## 📖 规格文档结构

每个规格文档遵循统一格式：

```markdown
## 📋 规格编号: SP-XXX-XXX
**版本**: 1.0.0
**状态**: 待实施/进行中/已完成
**依赖**: 依赖的其他规格

## 1. 概述
目标、背景和动机

## 2. 数据模型规格
数据结构定义和约束

## 3. 方法规格
每个方法的：
- 前置条件
- 操作步骤
- 后置条件
- 测试用例（Spec-XXX 格式）

## 4. 集成规格
与其他模块的交互

## 5. 验证清单
测试覆盖检查清单
```

---

## 🎯 实施检查清单

### 当前阶段：规格实施 🔄

所有规格文档已创建完成（100%覆盖），下一步是按照规格实现代码。

| 优先级 | 任务 | 状态 |
|--------|------|------|
| 高 | 修改 Rust 数据模型（domain/ 规格） | 待实施 |
| 高 | 更新 API 层（api/ 规格） | 待实施 |
| 高 | 修改 Flutter UI（features/ 规格） | 待实施 |
| 中 | 补充单元测试 | 进行中 |
| 中 | 完善集成测试 | 进行中 |
| 低 | 规格文档网站生成 | 待规划 |

**参考**: 完整路线图见 [产品路线图](../docs/roadmap.md)

---

## 🛠️ 使用工具

### 快速查找规格

```bash
# 查找所有与 pool 相关的规格
grep -r "pool" openspec/specs/domain/

# 查看所有功能规格
ls openspec/specs/features/

# 查找特定功能
find openspec/specs/features -name "*card_editor*"
```

### Git 集成

```bash
# 检查未关联规格的代码修改
git status --porcelain | grep "\.rs$" | while read line; do
  # 验证是否有对应规格
  echo "检查: $line"
done
```

---

## 📊 规格统计

**当前（2026-01-23）**:
- 架构决策记录 (ADR): 5 个
- Domain 规格: 5 个（领域模型和业务规则）
- Architecture 规格: 15 个（技术实现）
- Features 规格: 5 个（用户功能）
- UI 规格: 32 个（屏幕 + 组件 + 自适应）
- Legacy 规格: 5 个（API + UI System）
- **总计**: 67 个规格文档

**目标**:
- 规格覆盖率: 100%
- 测试通过率: 100%
- 文档更新率: 实时同步

---

## 🤝 贡献指南

### 添加新规格

1. 确定规格类别（engineering / domain / api / features / ui_system）
2. 在对应目录创建新规格文档
3. 遵循命名约定（详见 [engineering/directory_conventions.md](./engineering/directory_conventions.md)）
4. 编写完整测试用例
5. 添加到本索引

### 命名约定

- **Domain/API/UI System**: `snake_case.md`
- **Features**:
  - 目录: `lowercase_with_underscores/`
  - 文件: `logic.md`, `ui_mobile.md`, `ui_desktop.md`, `ui_shared.md`

### 测试命名规范

```dart
// Spec Coding 风格（推荐）
test('it_should_allow_joining_first_pool_successfully', () { ... });

// 传统风格（仍然支持）
test('test_device_can_join_pool', () { ... });
```

---

## 🔗 相关文档

### 规格文档
- [Spec Coding 指南](./engineering/guide.md) - Spec Coding 方法论
- [实施总结](./engineering/summary.md) - Spec Coding 完整指南
- [目录结构约定](./engineering/directory_conventions.md) - 新结构说明

### 用户文档
- [产品愿景](../../docs/requirements/product_vision.md) - 产品定位和目标
- [产品路线图](../../docs/roadmap.md) - v1.0-v2.0 规划
- [用户手册](../../docs/user_guide.md) - 完整使用指南

### AI 开发指南
- [CLAUDE.md](../../CLAUDE.md) - Claude Code 工作指南

---

## 📫 支持

### 需要帮助？

1. **查看目录约定**: `openspec/specs/engineering/directory_conventions.md`
2. **查看实施总结**: `openspec/specs/engineering/summary.md`
3. **运行示例**: `cargo test --test pool_model_test`
4. **查看配置**: `openspec/.openspec/config.json`

### 常见问题

**Q**: 规格文档和代码注释有什么区别？
**A**: 规格文档描述"应该做什么"，代码注释描述"如何做的"。规格是需求，注释是实现。

**Q**: 如何保持规格和代码同步？
**A**: 通过可执行规格（测试用例）自动验证，每次 PR 必须包含规格实施状态。

**Q**: 为什么要按领域驱动重组？
**A**: 旧结构按技术栈分类（rust / flutter），导致相关功能分散。新结构按领域和用户能力组织，更易查找和维护。详见 [engineering/directory_conventions.md](./engineering/directory_conventions.md)。

**Q**: 旧的 rust/ 和 flutter/ 目录怎么办？
**A**: 已标记为弃用，保留一段时间后将移除。所有内容已迁移到新结构。

---

## 📝 最近更新

### 2026-01-23: 重组为四层架构（第四次重构）

**重大变更**: 从领域驱动 → 四层架构组织

#### 新目录结构
- ✅ `domain/` - 领域层（业务模型和规则）
- ✅ `architecture/` - 架构层（技术实现）
- ✅ `features/` - 功能层（用户功能）
- ✅ `ui/` - UI 层（界面组件，按平台分离）

#### 迁移内容
- Domain: 5 个文档（card, pool, sync 领域模型）
- Architecture: 15 个文档（storage, sync, security, bridge）
- Features: 5 个文档（card_management, pool_management, p2p_sync, search_and_filter, settings）
- UI: 32 个文档（screens, components, adaptive）

#### 变更原因
旧结构混合了领域模型和技术实现，导致：
1. 业务规则和技术细节混在一起
2. 难以区分"做什么"和"怎么做"
3. UI 组件按功能分散，难以按平台查找

新结构清晰分层：
1. **Domain**: 纯业务语言，描述"是什么"
2. **Architecture**: 技术细节，描述"怎么实现"
3. **Features**: 用户视角，描述"做什么"
4. **UI**: 按平台组织，清晰的 mobile/desktop/shared 分离

#### 迁移指南

**查找旧文档**:
- `domain/pool_model.md` → `domain/pool/model.md`
- `domain/common_types.md` → `domain/types.md`
- `domain/card_store.md` → `architecture/storage/card_store.md`（技术实现）或 `domain/card/rules.md`（业务规则）
- `domain/device_config.md` → `architecture/storage/device_config.md`
- `domain/sync_protocol.md` → `architecture/sync/service.md`

**按平台查找 UI**:
- Mobile 屏幕: `ui/screens/mobile/`
- Desktop 屏幕: `ui/screens/desktop/`
- 共享屏幕: `ui/screens/shared/`
- Mobile 组件: `ui/components/mobile/`
- Desktop 组件: `ui/components/desktop/`
- 共享组件: `ui/components/shared/`

---

### 2026-01-20: 迁移到领域驱动结构（第三次重构）

**重大变更**: 从技术栈驱动 → 领域驱动组织

旧结构（rust / flutter）按技术栈组织，导致相关功能分散。新结构按领域和用户能力组织，相关规格集中在一起。

详见 [engineering/directory_conventions.md](../engineering/directory_conventions.md)

---

**最后更新**: 2026-01-23
**维护者**: CardMind Team
**规范的规范**: 本文档本身也是规格 🤯
