# CardMind 规格中心

> **Spec Coding 方法论**: 测试即规格，规格即文档

主规格文档入口，所有功能规格都集中在这里管理。

---

## 📋 规格文档索引

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

### Flutter UI 规格

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| SP-FLUT-003 | [ui_interaction_spec.md](./flutter/ui_interaction_spec.md) | UI 交互规格 | ✅ 完成 |
| SP-FLUT-007 | [onboarding_spec.md](./flutter/onboarding_spec.md) | 初始化流程规格 | ✅ 完成 |
| SP-FLUT-008 | [home_screen_spec.md](./flutter/home_screen_spec.md) | 主页交互规格 | ✅ 完成 |
| SP-FLUT-009 | [card_creation_spec.md](./flutter/card_creation_spec.md) | 卡片创建交互规格 | ✅ 完成 |
| SP-FLUT-010 | [sync_feedback_spec.md](./flutter/sync_feedback_spec.md) | 同步反馈交互规格 | ✅ 完成 |

### 平台自适应 UI 规格

| 编号 | 文档 | 描述 | 状态 |
|-----|------|------|------|
| SP-ADAPT-001 | [platform-detection/spec.md](./platform-detection/spec.md) | 平台检测规格 | ✅ 完成 |
| SP-ADAPT-002 | [adaptive-ui-framework/spec.md](./adaptive-ui-framework/spec.md) | 自适应 UI 框架规格 | ✅ 完成 |
| SP-ADAPT-003 | [keyboard-shortcuts/spec.md](./keyboard-shortcuts/spec.md) | 键盘快捷键规格 | ✅ 完成 |
| SP-ADAPT-004 | [mobile-ui-patterns/spec.md](./mobile-ui-patterns/spec.md) | 移动端 UI 模式规格 | ✅ 完成 |
| SP-ADAPT-005 | [desktop-ui-patterns/spec.md](./desktop-ui-patterns/spec.md) | 桌面端 UI 模式规格 | ✅ 完成 |

---

## 🚀 快速开始

### 1. 查看规格文档

```bash
# Rust 规格
cat specs/rust/single_pool_model_spec.md

# Flutter 规格
cat specs/flutter/ui_interaction_spec.md

# 实施总结
cat specs/SPEC_CODING_SUMMARY.md
```

### 2. 运行可执行规格

```bash
# 单池模型流程示例
cd rust
cargo run --example single_pool_flow_spec
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
grep -r "Spec-.*pool" specs/

# 查看所有测试用例
grep -r "it_should_" specs/

# 统计规格覆盖率
specs/stats.sh  # (待创建)
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

**当前（2026-01-17）**:
- 功能规格文档: 14 个（新增 5 个平台自适应规格）
- 工具文档: 5 个
- Spec 测试: 79 个（全部通过）
- 代码示例: 6 个业务场景

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
4. 添加到本索引

### 规格编号规则

```
SP     - 规格前缀
XXX    - 模块识别码
       - SPM: Single Pool Model（单池模型）
       - DEV: Device Config（设备配置）
       - POOL: Pool Model（池模型）
       - CARD: Card Store（卡片存储）
       - API: API Layer（API 层）
       - SYNC: Sync Layer（同步层）
       - FLUT: Flutter UI
       - ADAPT: Adaptive UI（平台自适应 UI）

XXX    - 序号（001, 002, 003...）
```

**示例**: `SP-SPM-001` = 单池模型 - 第一个规格

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
- [实施指南](./SPEC_CODING_SUMMARY.md) - Spec Coding 完整指南
- [测试命名规范](./test_naming_plan.md) - it_should_xxx 风格指南

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

1. **查看实施总结**: `specs/SPEC_CODING_SUMMARY.md`
2. **运行示例**: `cargo run --example single_pool_flow_spec`
3. **查看完整规格**: `specs/rust/single_pool_model_spec.md`

### 常见问题

**Q**: 规格文档和代码注释有什么区别？  
**A**: 规格文档描述"应该做什么"，代码注释描述"如何做的"。规格是需求，注释是实现。

**Q**: 如何保持规格和代码同步？  
**A**: 通过可执行规格（测试用例）自动验证，每次 PR 必须包含规格实施状态。

---

**最后更新**: 2026-01-17
**维护者**: CardMind Team
**规范的规范**: 本文档本身也是规格 🤯

