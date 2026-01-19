# CardMind 规格中心

> **Spec Coding 方法论**: 测试即规格，规格即文档

主规格文档入口，所有功能规格都集中在这里管理。

---

## 📋 规格文档索引

### 架构决策记录 (ADR)

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| ADR-0001 | [0001-single-pool-ownership.md](./adr/0001-single-pool-ownership.md) | 单池所有权模型 | ✅ 已接受 |
| ADR-0002 | [0002-dual-layer-architecture.md](./adr/0002-dual-layer-architecture.md) | 双层数据架构 | ✅ 已接受 |
| ADR-0003 | [0003-tech-constraints.md](./adr/0003-tech-constraints.md) | 技术约束 | ✅ 已接受 |
| ADR-0004 | [0004-ui-design.md](./adr/0004-ui-design.md) | UI 设计原则 | ✅ 已接受 |
| ADR-0005 | [0005-logging.md](./adr/0005-logging.md) | 日志规范 | ✅ 已接受 |

### Rust 后端规格

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| SP-TYPE-000 | [common_types_spec.md](./rust/common_types_spec.md) | 通用类型系统 | ✅ 完成 |
| SP-ARCH-000 | [architecture_patterns_spec.md](./rust/architecture_patterns_spec.md) | 分层架构模式 | ✅ 完成 |
| SP-SPM-001 | [single_pool_model_spec.md](./rust/single_pool_model_spec.md) | 单池模型核心规格 | ✅ 完成 |
| SP-DEV-002 | [device_config_spec.md](./rust/device_config_spec.md) | DeviceConfig 改造规格 | ✅ 完成 |
| SP-POOL-003 | [pool_model_spec.md](./rust/pool_model_spec.md) | Pool 模型 CRUD 规格 | ✅ 完成 |
| SP-CARD-004 | [card_store_spec.md](./rust/card_store_spec.md) | CardStore 改造规格 | ✅ 完成 |
| SP-API-005 | [api_spec.md](./rust/api_spec.md) | API 层统一规格 | ✅ 完成 |
| SP-SYNC-006 | [sync_spec.md](./rust/sync_spec.md) | 同步层简化规格 | ✅ 完成 |
| SP-SYNC-007 | [sync_status_stream_spec.md](./rust/sync_status_stream_spec.md) | 同步状态 Stream 规格 | ✅ 完成 |

### Flutter 前端规格

> 详细索引见 [flutter/README.md](./flutter/README.md)

#### UI 交互规格

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| SP-FLUT-003 | [ui-interaction/overview.md](./flutter/ui-interaction/overview.md) | UI 交互规格总览 | ✅ 完成 |
| SP-FLUT-007 | [ui-interaction/onboarding.md](./flutter/ui-interaction/onboarding.md) | 初始化流程规格 | ✅ 完成 |
| SP-FLUT-008 | [ui-interaction/home-screen.md](./flutter/ui-interaction/home-screen.md) | 主页交互规格 | ✅ 完成 |
| SP-FLUT-011 | [ui-interaction/mobile.md](./flutter/ui-interaction/mobile.md) | 移动端 UI 交互规格 | ✅ 完成 |
| SP-FLUT-012 | [ui-interaction/desktop.md](./flutter/ui-interaction/desktop.md) | 桌面端 UI 交互规格 | ✅ 完成 |
| ~~SP-FLUT-009~~ | ~~[ui-interaction/card-creation.md](./flutter/ui-interaction/card-creation.md)~~ | ~~卡片创建交互规格~~ | ⚠️ 已废弃 → SP-FLUT-011/012 |
| SP-FLUT-010 | [ui-interaction/sync-feedback.md](./flutter/ui-interaction/sync-feedback.md) | 同步反馈交互规格 | ✅ 完成 |

#### 自适应 UI 规格

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| SP-ADAPT-001 | [adaptive-ui/platform-detection.md](./flutter/adaptive-ui/platform-detection.md) | 平台检测规格 | ✅ 完成 |
| SP-ADAPT-002 | [adaptive-ui/framework.md](./flutter/adaptive-ui/framework.md) | 自适应 UI 框架规格 | ✅ 完成 |
| SP-ADAPT-003 | [adaptive-ui/keyboard-shortcuts.md](./flutter/adaptive-ui/keyboard-shortcuts.md) | 键盘快捷键规格 | ✅ 完成 |
| SP-ADAPT-004 | [adaptive-ui/mobile-patterns.md](./flutter/adaptive-ui/mobile-patterns.md) | 移动端 UI 模式规格 | ✅ 完成 |
| SP-ADAPT-005 | [adaptive-ui/desktop-patterns.md](./flutter/adaptive-ui/desktop-patterns.md) | 桌面端 UI 模式规格 | ✅ 完成 |

#### 测试规格（测试即规格）

> 注：以下规格遵循 Spec Coding 方法论，测试文件本身即为规格文档

| 编号 | 文档 | 描述 | 对应测试文件 | 状态 |
|-----|------|------|-------------|------|
| SP-TEST-001 | [testing/ui-component.md](./flutter/testing/ui-component.md) | UI 组件测试规格 | `test/specs/*_spec_test.dart` | ✅ 完成 |
| SP-TEST-002 | [testing/ui-interaction.md](./flutter/testing/ui-interaction.md) | UI 交互测试规格 | `test/specs/ui_interaction_spec_test.dart` | ✅ 完成 |
| SP-TEST-003 | [testing/home-screen.md](./flutter/testing/home-screen.md) | 主页测试规格 | `test/specs/home_screen_*_spec_test.dart` | ✅ 完成 |
| SP-TEST-004 | [testing/onboarding.md](./flutter/testing/onboarding.md) | 初始化测试规格 | `test/specs/onboarding_spec_test.dart` | ✅ 完成 |
| SP-TEST-005 | [testing/platform-adaptive.md](./flutter/testing/platform-adaptive.md) | 平台自适应测试规格 | `test/specs/platform_*_spec_test.dart` | ✅ 完成 |
| SP-TEST-006 | [testing/responsive-layout.md](./flutter/testing/responsive-layout.md) | 响应式布局测试规格 | `test/specs/responsive_layout_spec_test.dart` | ✅ 完成 |
| SP-TEST-007 | [testing/integration.md](./flutter/testing/integration.md) | 集成测试规格 | `test/integration/` | ✅ 完成 |
| SP-TEST-008 | [testing/test-spec-mapping.md](./flutter/testing/test-spec-mapping.md) | 测试规格映射关系 | - | ✅ 完成 |

#### UI 组件规格（直接测试文件）

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
# Rust 规格
cat openspec/specs/rust/single_pool_model_spec.md

# Flutter 规格
cat openspec/specs/flutter/ui-interaction/overview.md

# 自适应 UI 规格
cat openspec/specs/flutter/adaptive-ui/framework.md

# 实施总结
cat openspec/specs/SPEC_CODING_SUMMARY.md
```

### 2. 运行可执行规格

```bash
# 单池模型流程示例
cd rust
cargo run --example single_pool_flow_spec

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
| 高 | 修改 Rust 数据模型（按照 SP-SPM-001） | 待实施 |
| 高 | 更新 DeviceConfig（按照 SP-DEV-002） | 待实施 |
| 高 | 修改 Flutter UI（按照 SP-FLUT-003/007/008） | 待实施 |
| 中 | 补充单元测试 | 进行中 |
| 中 | 完善集成测试 | 进行中 |
| 低 | 规格文档网站生成 | 待规划 |

**参考**: 完整路线图见 [产品路线图](../docs/roadmap.md) Phase 6R

---

## 🛠️ 使用工具

### 快速查找规格

```bash
# 查找所有与 pool 相关的规格
grep -r "Spec-.*pool" openspec/specs/

# 查看所有测试用例
grep -r "it_should_" openspec/specs/

# 查看 Flutter 规格索引
cat openspec/specs/flutter/README.md
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

**当前（2026-01-19）**:
- 架构决策记录: 5 个
- Rust 后端规格: 9 个
- Flutter UI 交互规格: 7 个（1 个已废弃）
- Flutter 自适应 UI 规格: 5 个
- Flutter 测试规格: 8 个
- UI 组件测试规格: 9 个
- **总计**: 43 个规格文档

**目标**:
- 规格覆盖率: 100%
- 测试通过率: 100%
- 文档更新率: 实时同步

---

## 🤝 贡献指南

### 添加新规格

1. 在对应目录创建新规格文档
2. 分配规格编号（遵循 SP-XXX-XXX 格式）
3. 编写完整测试用例
4. 添加到本索引和对应的子索引（如 flutter/README.md）

### 规格编号规则

```
SP     - 规格前缀
XXX    - 模块识别码
       - TYPE: Type System（类型系统）
       - ARCH: Architecture（架构）
       - SPM: Single Pool Model（单池模型）
       - DEV: Device Config（设备配置）
       - POOL: Pool Model（池模型）
       - CARD: Card Store（卡片存储）
       - API: API Layer（API 层）
       - SYNC: Sync Layer（同步层）
       - FLUT: Flutter UI（Flutter UI）
       - ADAPT: Adaptive UI（平台自适应 UI）
       - TEST: Testing（测试）
       - UI: UI Components（UI 组件）

XXX    - 序号（001, 002, 003...）
```

**示例**: 
- `SP-SPM-001` = 单池模型 - 第一个规格
- `SP-FLUT-003` = Flutter UI - 第三个规格
- `SP-ADAPT-001` = 自适应 UI - 第一个规格

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
- [Spec Coding 指南](./SPEC_CODING_GUIDE.md) - Spec Coding 方法论
- [实施总结](./SPEC_CODING_SUMMARY.md) - Spec Coding 完整指南
- [Flutter 规格索引](./flutter/README.md) - Flutter 规格详细索引

### 用户文档
- [产品愿景](../../docs/requirements/product_vision.md) - 产品定位和目标
- [产品路线图](../../docs/roadmap.md) - v1.0-v2.0 规划
- [用户手册](../../docs/user_guide.md) - 完整使用指南

### AI 开发指南
- [CLAUDE.md](../../CLAUDE.md) - Claude Code 工作指南
- [AGENTS.md](../../AGENTS.md) - AI Agent 指南

---

## 📫 支持

### 需要帮助？

1. **查看实施总结**: `openspec/specs/SPEC_CODING_SUMMARY.md`
2. **运行示例**: `cargo run --example single_pool_flow_spec`
3. **查看完整规格**: `openspec/specs/rust/single_pool_model_spec.md`
4. **查看 Flutter 规格**: `openspec/specs/flutter/README.md`

### 常见问题

**Q**: 规格文档和代码注释有什么区别？  
**A**: 规格文档描述"应该做什么"，代码注释描述"如何做的"。规格是需求，注释是实现。

**Q**: 如何保持规格和代码同步？  
**A**: 通过可执行规格（测试用例）自动验证，每次 PR 必须包含规格实施状态。

**Q**: Flutter 规格为什么分成三个子目录？  
**A**: 按功能分类（UI 交互 / 自适应 UI / 测试），便于查找和维护。详见 [flutter/README.md](./flutter/README.md)。

---

**最后更新**: 2026-01-19
**维护者**: CardMind Team
**规范的规范**: 本文档本身也是规格 🤯

---

## 📝 最近更新

### 2026-01-19: 规格文档重组
- ✅ 重组 Flutter 规格为三个子目录（ui-interaction / adaptive-ui / testing）
- ✅ 统一文件命名规范（使用 `-` 分隔符）
- ✅ 创建 Flutter 规格索引（flutter/README.md）
- ✅ 消除散落的独立规格目录（13 个 → 3 个）
- ✅ 集中管理测试规格

**原因**: 原结构混乱，同一层级既有集合目录（adr/rust/flutter）又有独立规格目录（platform-detection 等），导致查找困难。重组后按技术栈分层，Flutter 内部按功能分类，结构清晰。

### 2026-01-19: UI 规格平台拆分
- ✅ 新增 SP-FLUT-011: 移动端 UI 交互规格
- ✅ 新增 SP-FLUT-012: 桌面端 UI 交互规格
- ✅ 更新 SP-FLUT-003: 改为总览文档
- ⚠️ 废弃 SP-FLUT-009: 拆分为 SP-FLUT-011 和 SP-FLUT-012

**原因**: 原规格混合了移动端和桌面端交互，导致实现不清晰。拆分后每个平台有独立的完整规格。

**详情**: 查看 [openspec/changes/split-ui-interaction-specs/SUMMARY.md](../changes/split-ui-interaction-specs/SUMMARY.md)

