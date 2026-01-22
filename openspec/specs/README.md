# CardMind 规格中心

> **Spec Coding 方法论**: 测试即规格,规格即文档

主规格文档入口，所有功能规格都集中在这里管理。

---

## 🔔 重要通知：目录结构已迁移

**迁移日期**: 2026-01-20
**新结构**: 领域驱动组织 (Domain-Driven Organization)

旧的 `rust/` 和 `flutter/` 目录已弃用，所有规格已迁移到新的领域驱动结构：
- 📐 `engineering/` - 工程实践
- 🏗️ `domain/` - 领域模型
- 🔌 `api/` - 公共接口
- ✨ `features/` - 用户功能
- 🎨 `ui_system/` - UI 系统

详细约定见 [engineering/directory_conventions.md](./engineering/directory_conventions.md)

---

## 📂 新目录结构

```
openspec/specs/
├── engineering/       # 工程实践和架构模式
├── domain/            # 领域模型和业务逻辑
├── api/               # 公共 API 和 FFI 接口
├── features/          # 用户功能（按能力组织）
├── ui_system/         # UI 设计系统
└── adr/               # 架构决策记录
```

---

## 📋 规格文档索引

### 🏛️ 架构决策记录 (ADR)

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| ADR-0001 | [0001-single-pool-ownership.md](./adr/0001-single-pool-ownership.md) | 单池所有权模型 | ✅ 已接受 |
| ADR-0002 | [0002-dual-layer-architecture.md](./adr/0002-dual-layer-architecture.md) | 双层数据架构 | ✅ 已接受 |
| ADR-0003 | [0003-tech-constraints.md](./adr/0003-tech-constraints.md) | 技术约束 | ✅ 已接受 |
| ADR-0004 | [0004-ui-design.md](./adr/0004-ui-design.md) | UI 设计原则 | ✅ 已接受 |
| ADR-0005 | [0005-logging.md](./adr/0005-logging.md) | 日志规范 | ✅ 已接受 |

### 📐 Engineering (工程实践)

| 文档 | 描述 | 状态 |
|------|------|------|
| [guide.md](./engineering/guide.md) | Spec Coding 指南 | ✅ 完成 |
| [summary.md](./engineering/summary.md) | Spec Coding 快速参考 | ✅ 完成 |
| [architecture_patterns.md](./engineering/architecture_patterns.md) | 分层架构模式 | ✅ 完成 |
| [tech_stack.md](./engineering/tech_stack.md) | 技术栈约束 | ✅ 完成 |
| [directory_conventions.md](./engineering/directory_conventions.md) | 目录结构约定 | ✅ 完成 |
| [spec_format_standard.md](./engineering/spec_format_standard.md) | 主规格格式标准 | ✅ 完成 |

### 🏗️ Domain (领域模型)

| 文档 | 描述 | 状态 |
|------|------|------|
| [common_types.md](./domain/common_types.md) | 通用类型系统 | ✅ 完成 |
| [pool_model.md](./domain/pool_model.md) | 单池模型核心规格 | ✅ 完成 |
| [device_config.md](./domain/device_config.md) | 设备配置规格 | ✅ 完成 |
| [card_store.md](./domain/card_store.md) | 卡片存储规格 | ✅ 完成 |
| [sync_protocol.md](./domain/sync_protocol.md) | 同步协议规格 | ✅ 完成 |

### 🔌 API (公共接口)

| 文档 | 描述 | 状态 |
|------|------|------|
| [api_spec.md](./api/api_spec.md) | Rust API 统一规格 | ✅ 完成 |

### ✨ Features (用户功能)

按用户能力组织，每个功能可包含 `logic.md` (后端逻辑)、`ui_mobile.md` (移动端 UI)、`ui_desktop.md` (桌面端 UI)、`ui_shared.md` (共享 UI)。

#### 📝 Card Editor (卡片编辑器)

| 文档 | 平台 | 状态 |
|------|------|------|
| [ui_mobile.md](./features/card_editor/ui_mobile.md) | Mobile | ✅ 完成 |
| [ui_desktop.md](./features/card_editor/ui_desktop.md) | Desktop | ✅ 完成 |

#### 📋 Card List (卡片列表)

| 文档 | 平台 | 状态 |
|------|------|------|
| [ui_mobile.md](./features/card_list/ui_mobile.md) | Mobile | ✅ 完成 |
| [ui_desktop.md](./features/card_list/ui_desktop.md) | Desktop | ✅ 完成 |

#### 🔍 Search (搜索)

| 文档 | 平台 | 状态 |
|------|------|------|
| [ui_mobile.md](./features/search/ui_mobile.md) | Mobile | ✅ 完成 |
| [ui_desktop.md](./features/search/ui_desktop.md) | Desktop | ✅ 完成 |

#### 🌟 Onboarding (初始化引导)

| 文档 | 平台 | 状态 |
|------|------|------|
| [ui_shared.md](./features/onboarding/ui_shared.md) | Shared | ✅ 完成 |

#### 🏠 Home Screen (主页)

| 文档 | 平台 | 状态 |
|------|------|------|
| [ui_shared.md](./features/home_screen/ui_shared.md) | Shared | ✅ 完成 |

#### 🔄 Sync Feedback (同步反馈)

| 文档 | 平台 | 状态 |
|------|------|------|
| [ui_shared.md](./features/sync_feedback/ui_shared.md) | Shared | ✅ 完成 |

#### 🧭 Navigation (导航)

| 文档 | 平台 | 状态 |
|------|------|------|
| [ui_mobile.md](./features/navigation/ui_mobile.md) | Mobile | ✅ 完成 |

#### ✋ Gestures (手势)

| 文档 | 平台 | 状态 |
|------|------|------|
| [ui_mobile.md](./features/gestures/ui_mobile.md) | Mobile | ✅ 完成 |

#### ➕ FAB (浮动按钮)

| 文档 | 平台 | 状态 |
|------|------|------|
| [ui_mobile.md](./features/fab/ui_mobile.md) | Mobile | ✅ 完成 |

#### 🛠️ Toolbar (工具栏)

| 文档 | 平台 | 状态 |
|------|------|------|
| [ui_desktop.md](./features/toolbar/ui_desktop.md) | Desktop | ✅ 完成 |

#### 📌 Context Menu (右键菜单)

| 文档 | 平台 | 状态 |
|------|------|------|
| [ui_desktop.md](./features/context_menu/ui_desktop.md) | Desktop | ✅ 完成 |

### 🎨 UI System (UI 系统)

| 文档 | 描述 | 状态 |
|------|------|------|
| [design_tokens.md](./ui_system/design_tokens.md) | 设计令牌（颜色、字体等） | ✅ 完成 |
| [responsive_layout.md](./ui_system/responsive_layout.md) | 响应式布局系统 | ✅ 完成 |
| [shared_widgets.md](./ui_system/shared_widgets.md) | 共享组件 | 📝 占位符 |

### 🧪 UI 组件规格（测试即规格）

> 注：以下规格遵循 Spec Coding 方法论，测试文件本身即为规格文档

| 编号 | 测试文件 | 描述 | 状态 |
|-----|---------|------|------|
| SP-UI-001 | [adaptive_ui_system_spec_test.dart](../../test/specs/adaptive_ui_system_spec_test.dart) | 自适应 UI 系统规格 | ✅ 完成 |
| SP-UI-002 | [card_editor_spec_test.dart](../../test/specs/card_editor_spec_test.dart) | 卡片编辑器 UI 规格 | ✅ 完成 |
| SP-UI-003 | [device_manager_ui_spec_test.dart](../../test/specs/device_manager_ui_spec_test.dart) | 设备管理面板 UI 规格 | ✅ 完成 |
| SP-UI-004 | [fullscreen_editor_spec_test.dart](../../test/specs/fullscreen_editor_spec_test.dart) | 全屏编辑器 UI 规格 | ✅ 完成 |
| SP-UI-005 | [home_screen_ui_spec_test.dart](../../test/specs/home_screen_ui_spec_test.dart) | 主页 UI 规格 | ✅ 完成 |
| SP-UI-006 | [mobile_navigation_spec_test.dart](../../test/specs/mobile_navigation_spec_test.dart) | 移动端导航 UI 规格 | ✅ 完成 |
| SP-UI-007 | [note_card_component_spec_test.dart](../../test/specs/note_card_component_spec_test.dart) | 笔记卡片组件规格 | ✅ 完成 |
| SP-UI-008 | [sync_status_indicator_component_spec_test.dart](../../test/specs/sync_status_indicator_component_spec_test.dart) | 同步状态指示器规格 | ✅ 完成 |
| SP-UI-009 | [toast_notification_spec_test.dart](../../test/specs/toast_notification_spec_test.dart) | Toast 通知规格 | ✅ 完成 |

---

## 🚀 快速开始

### 1. 查看规格文档

```bash
# Engineering (工程实践)
cat openspec/specs/engineering/guide.md

# Domain (领域模型)
cat openspec/specs/domain/pool_model.md
cat openspec/specs/domain/sync_protocol.md

# API (公共接口)
cat openspec/specs/api/api_spec.md

# Features (用户功能)
cat openspec/specs/features/card_editor/ui_mobile.md
cat openspec/specs/features/card_list/ui_desktop.md

# UI System (UI 系统)
cat openspec/specs/ui_system/design_tokens.md
```

### 2. 运行可执行规格

```bash
# 后端规格测试
cd rust
cargo test --test sp_spm_001_spec
cargo test --test sp_sync_006_spec

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

**当前（2026-01-22）**:
- 架构决策记录 (ADR): 5 个
- Engineering 规格: 6 个
- Domain 规格: 5 个
- API 规格: 1 个
- Feature 规格: 14 个（11 个功能）
- UI System 规格: 3 个
- UI 组件规格（测试即规格）: 9 个
- **总计**: 43 个规格文档

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
3. **运行示例**: `cargo test --test sp_spm_001_spec`
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

### 2026-01-20: 迁移到领域驱动结构（第三次重构）

**重大变更**: 从技术栈驱动 → 领域驱动组织

#### 新目录结构
- ✅ 创建 `engineering/` - 工程实践
- ✅ 创建 `domain/` - 领域模型
- ✅ 创建 `api/` - 公共接口
- ✅ 创建 `features/` - 用户功能（11 个功能目录）
- ✅ 创建 `ui_system/` - UI 系统

#### 迁移内容
- Engineering: 6 个文档（guide, summary, architecture_patterns, tech_stack, directory_conventions, spec_format_standard）
- Domain: 5 个文档（common_types, pool_model, device_config, card_store, sync_protocol）
- API: 1 个文档（api_spec）
- Features: 14 个文档（11 个功能，每个 1-2 个平台规格）
- UI System: 3 个文档（design_tokens, responsive_layout, shared_widgets）

#### 变更原因
旧结构（rust / flutter）按技术栈组织，导致：
1. 相关功能分散在不同目录
2. 难以按用户能力查找规格
3. 技术栈前缀冗长（SP-FLT-MOB-001）

新结构按领域和用户能力组织：
1. 相关规格集中在一起（如 `features/card_editor/`）
2. 清晰的关注点分离（engineering / domain / features）
3. 简洁的文件名（ui_mobile.md, ui_desktop.md）

#### 迁移指南
详见 [engineering/directory_conventions.md](./engineering/directory_conventions.md)

---

**最后更新**: 2026-01-22
**维护者**: CardMind Team
**规范的规范**: 本文档本身也是规格 🤯
