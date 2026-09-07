# CardMind 规格-测试验证计划
# Spec-Test Validation Plan

**创建日期**: 2026-02-01
**状态**: 待执行
**执行方式**: Superpowers ExecutePlan 工作流

---

## 执行摘要

### 目标

对 CardMind 项目的所有测试代码进行全面验证，确保测试实现与规格文档完全一致。

### 背景

CardMind 采用 Spec Coding 方法论（测试即规格，规格即文档），拥有 67 个规格文档，分布在四层架构中：
- **Domain Layer**: 5 个规格（领域模型和业务规则）
- **Architecture Layer**: 15 个规格（技术实现）
- **Features Layer**: 5 个规格（用户功能）
- **UI Layer**: 32 个规格（屏幕 + 组件 + 自适应）
- **Legacy**: 5 个规格（API + UI System）

### 问题陈述

目前缺乏系统化的验证机制，无法确保测试代码是否完整覆盖规格文档中定义的所有场景、前置条件和后置条件。这可能导致：
1. 规格文档与实际测试不一致
2. 关键场景缺少测试覆盖
3. 测试命名不规范，难以追溯到规格
4. GIVEN-WHEN-THEN 三段式不完整

### 预期成果

1. **验证报告**: 生成详细的 Markdown 报告（`docs/reports/spec-test-validation-report.md`）
2. **不符合项清单**: 清晰列出所有不符合项，包括：
   - 缺失的测试文件
   - 缺失的场景测试
   - 不符合命名规范的测试
   - 不完整的 GIVEN-WHEN-THEN 结构
   - 不充分的断言
3. **改进建议**: 为每个不符合项提供具体的改进建议和优先级
4. **统计摘要**: 提供覆盖率、合规率等关键指标

---

## 实施策略

### 验证方法论

采用**四阶段验证流程**：

#### 阶段 1: 规格-测试映射分析
- 扫描 `openspec/specs/` 下所有规格文档
- 识别每个规格中定义的 Requirements 和 Scenarios
- 查找对应的测试文件（通过 `Related Tests` 字段或命名约定）
- 生成规格-测试映射表

**工具**:
- `find` + `grep`: 查找规格文档
- `grep -E "## Requirement:|### Scenario:"`: 提取场景
- `grep -E "Related Tests:"`: 提取测试文件路径

#### 阶段 2: 场景覆盖度验证
- 对每个规格中的 Scenario，检查是否有对应的测试用例
- 验证测试命名是否符合 `it_should_xxx()` 规范
- 检查 GIVEN-WHEN-THEN 三段式是否完整
- 识别缺失的场景测试

**工具**:
- `ast-grep`: 搜索 Rust 测试函数
- `grep -E "#\[test\]"`: 查找 Rust 测试
- `grep -E "test\('.*'\)"`: 查找 Dart 测试
- 正则表达式匹配 `it_should_xxx` 模式

#### 阶段 3: 测试实现质量检查
- 分析测试代码的断言（assertions）
- 验证是否正确测试了后置条件（THEN）
- 检查边界条件和错误处理
- 评估测试的完整性

**工具**:
- `grep -E "assert|expect"`: 查找断言
- `grep -E "// Given:|// When:|// Then:"`: 检查注释
- LSP 工具: 分析代码结构

#### 阶段 4: 报告生成
- 汇总所有不符合项
- 按严重程度分类（Critical/High/Medium/Low）
- 为每个问题提供具体的代码位置和改进建议
- 生成统计摘要（覆盖率、合规率等）

---

## 验证范围

### Rust 测试验证（高优先级）

**目标文件**: `rust/tests/*_spec.rs` 和 `rust/tests/*_test.rs`

**对应规格**: Domain Layer + Architecture Layer

**关键规格文件**:
- `domain/pool/model.md` → `rust/tests/sp_spm_001_spec.rs`
- `domain/card/model.md` → `rust/tests/card_model_test.rs`
- `architecture/sync/service.md` → `rust/tests/sp_sync_006_spec.rs`
- `architecture/sync/peer_discovery.md` → `rust/tests/sp_mdns_001_spec.rs`
- `architecture/storage/dual_layer.md` → 相关测试

**验证重点**:
- 测试命名规范 (`it_should_xxx()`)
- GIVEN-WHEN-THEN 注释完整性
- Result<T, Error> 错误处理测试
- 断言覆盖所有后置条件

### Flutter 测试验证（中优先级）

**目标文件**: `test/**/*_test.dart`

**对应规格**: Features Layer + UI Layer

**关键规格文件**:
- `features/card_management/spec.md`
- `features/pool_management/spec.md`
- `ui/screens/mobile/home_screen.md`
- `ui/components/shared/note_card.md`

**验证重点**:
- Widget 测试覆盖
- 用户交互场景测试
- 状态管理测试
- 测试命名规范

### 优先级排序

1. **Critical**: Domain Layer 规格（业务核心逻辑）
2. **High**: Architecture Layer 规格（技术实现）
3. **Medium**: Features Layer 规格（用户功能）
4. **Low**: UI Layer 规格（界面组件）

### 排除项

- Legacy 规格（标记为弃用）
- 占位符规格（状态为 📝）
- 没有 `Related Tests` 字段且尚未实现的规格

---

## 不符合项分类体系

### 类型 A: 缺失的测试文件
- **严重程度**: Critical
- **描述**: 规格文档指定了测试文件，但文件不存在
- **示例**: `domain/card/model.md` 指定 `Related Tests: rust/tests/card_model_test.rs`，但文件缺失
- **改进建议**: 创建测试文件并实现所有场景

### 类型 B: 缺失的场景测试
- **严重程度**: High
- **描述**: 规格定义了 Scenario，但没有对应的测试用例
- **示例**: 规格定义 "Scenario: Device rejects joining second pool"，但测试文件中没有 `it_should_reject_joining_second_pool_xxx()` 测试
- **改进建议**: 添加缺失的测试用例

### 类型 C: 测试命名不规范
- **严重程度**: Medium
- **描述**: 测试存在但命名不符合 `it_should_xxx()` 规范
- **示例**: `test_device_can_join_pool()` 应改为 `it_should_allow_joining_first_pool_successfully()`
- **改进建议**: 重命名测试函数

### 类型 D: GIVEN-WHEN-THEN 不完整
- **严重程度**: Medium
- **描述**: 测试代码缺少前置条件、操作或预期结果的注释或实现
- **示例**: 测试只有 WHEN 和 THEN，缺少 GIVEN 注释
- **改进建议**: 补充完整的三段式结构

### 类型 E: 断言不充分
- **严重程度**: Low
- **描述**: 测试没有验证规格中定义的所有后置条件
- **示例**: 规格要求验证 "pool_id == Some(...)" AND "sync begins"，但测试只验证了 pool_id
- **改进建议**: 添加缺失的断言

---

## 详细任务分解

### 阶段 1: 准备工作（预计 30 分钟）

#### 任务 1.1: 扫描所有规格文档
- **输入**: `openspec/specs/` 目录
- **输出**: 规格文档列表（67 个文档）
- **工具**: `find openspec/specs -name "*.md"`

#### 任务 1.2: 提取 Requirements 和 Scenarios
- **输入**: 每个规格文档
- **输出**: Requirements 和 Scenarios 列表
- **工具**: `grep -E "## Requirement:|### Scenario:"`

#### 任务 1.3: 识别测试文件路径
- **输入**: 规格文档中的 `Related Tests` 字段
- **输出**: 规格-测试映射表
- **工具**: `grep -E "Related Tests:"`

#### 任务 1.4: 扫描所有测试文件
- **输入**: `rust/tests/` 和 `test/` 目录
- **输出**: 测试文件列表
- **工具**: `find rust/tests -name "*_spec.rs" -o -name "*_test.rs"` 和 `find test -name "*_test.dart"`

---

### 阶段 2: Domain Layer 验证（预计 45 分钟）

#### 任务 2.1: 验证 domain/pool/model.md
- **规格文件**: `openspec/specs/domain/pool/model.md`
- **测试文件**: `rust/tests/sp_spm_001_spec.rs`
- **验证内容**:
  - ✅ 测试文件存在
  - ✅ Scenario: "Device joins first pool successfully" → `it_should_allow_joining_first_pool_successfully()`
  - ✅ Scenario: "Device rejects joining second pool" → `it_should_reject_joining_second_pool_when_already_joined()`
  - ❓ Scenario: "Device leaves pool and clears data" → 检查是否有对应测试
  - ❓ Scenario: "Create card auto-joins the pool" → 检查是否有对应测试
  - ❓ Scenario: "Create card fails when no pool joined" → 检查是否有对应测试

#### 任务 2.2: 验证 domain/card/model.md
- **规格文件**: `openspec/specs/domain/card/model.md`
- **测试文件**: 待查找
- **验证内容**:
  - ❓ 测试文件是否存在
  - ❓ 所有 Scenarios 是否有对应测试

#### 任务 2.3: 验证 domain/card/rules.md
- **规格文件**: `openspec/specs/domain/card/rules.md`
- **测试文件**: 待查找
- **验证内容**:
  - ❓ 测试文件是否存在
  - ❓ 所有 Scenarios 是否有对应测试

#### 任务 2.4: 验证 domain/sync/model.md
- **规格文件**: `openspec/specs/domain/sync/model.md`
- **测试文件**: 待查找
- **验证内容**:
  - ❓ 测试文件是否存在
  - ❓ 所有 Scenarios 是否有对应测试

#### 任务 2.5: 验证 domain/types.md
- **规格文件**: `openspec/specs/domain/types.md`
- **测试文件**: 待查找
- **验证内容**:
  - ❓ 是否需要测试（类型定义可能不需要独立测试）

---

### 阶段 3: Architecture Layer 验证（预计 60 分钟）

#### 任务 3.1: 验证 Storage 规格（6 个文档）
- `architecture/storage/dual_layer.md`
- `architecture/storage/card_store.md`
- `architecture/storage/pool_store.md`
- `architecture/storage/device_config.md`
- `architecture/storage/loro_integration.md`
- `architecture/storage/sqlite_cache.md`

**验证内容**:
- ❓ 每个规格是否有对应测试文件
- ❓ 所有 Scenarios 是否有对应测试
- ❓ 测试命名是否规范

#### 任务 3.2: 验证 Sync 规格（4 个文档）
- `architecture/sync/service.md` → `rust/tests/sp_sync_006_spec.rs`
- `architecture/sync/peer_discovery.md` → `rust/tests/sp_mdns_001_spec.rs`
- `architecture/sync/conflict_resolution.md`
- `architecture/sync/subscription.md`

**验证内容**:
- ✅ `sp_sync_006_spec.rs` 和 `sp_mdns_001_spec.rs` 存在
- ❓ 其他规格是否有对应测试
- ❓ 所有 Scenarios 是否有对应测试

#### 任务 3.3: 验证 Security 规格（3 个文档）
- `architecture/security/password.md`
- `architecture/security/keyring.md`
- `architecture/security/privacy.md`

**验证内容**:
- ❓ 每个规格是否有对应测试文件
- ❓ 所有 Scenarios 是否有对应测试

#### 任务 3.4: 验证 Bridge 规格（1 个文档）
- `architecture/bridge/flutter_rust_bridge.md`

**验证内容**:
- ❓ 是否有集成测试
- ❓ FFI 接口是否有测试覆盖

---

### 阶段 4: Features Layer 验证（预计 45 分钟）

#### 任务 4.1: 验证 card_management 规格
- **规格文件**: `features/card_management/spec.md`
- **测试文件**: 待查找（可能在 `test/features/` 或 `test/integration/`）
- **验证内容**:
  - ❓ 测试文件是否存在
  - ❓ 所有用户场景是否有对应测试

#### 任务 4.2: 验证 pool_management 规格
- **规格文件**: `features/pool_management/spec.md`
- **测试文件**: 待查找
- **验证内容**:
  - ❓ 测试文件是否存在
  - ❓ 所有用户场景是否有对应测试

#### 任务 4.3: 验证 p2p_sync 规格
- **规格文件**: `features/p2p_sync/spec.md`
- **测试文件**: 待查找
- **验证内容**:
  - ❓ 测试文件是否存在
  - ❓ 所有用户场景是否有对应测试

#### 任务 4.4: 验证 search_and_filter 规格
- **规格文件**: `features/search_and_filter/spec.md`
- **测试文件**: 待查找
- **验证内容**:
  - ❓ 测试文件是否存在
  - ❓ 所有用户场景是否有对应测试

#### 任务 4.5: 验证 settings 规格
- **规格文件**: `features/settings/spec.md`
- **测试文件**: 待查找
- **验证内容**:
  - ❓ 测试文件是否存在
  - ❓ 所有用户场景是否有对应测试

---

### 阶段 5: UI Layer 验证（预计 60 分钟）

#### 任务 5.1: 验证 Screens 规格（9 个文档）
- `ui/screens/mobile/home_screen.md`
- `ui/screens/desktop/home_screen.md`
- `ui/screens/mobile/card_editor_screen.md`
- `ui/screens/desktop/card_editor_screen.md`
- `ui/screens/mobile/card_detail_screen.md`
- `ui/screens/mobile/sync_screen.md`
- `ui/screens/mobile/settings_screen.md`
- `ui/screens/desktop/settings_screen.md`
- `ui/screens/shared/onboarding_screen.md`

**验证内容**:
- ❓ 每个屏幕是否有 Widget 测试
- ❓ 用户交互场景是否有测试覆盖
- ❓ 测试文件位置是否符合约定（`test/ui/screens/`）

#### 任务 5.2: 验证 Components 规格（14 个文档）
- Mobile 组件（5 个）
- Desktop 组件（4 个）
- Shared 组件（5 个）

**验证内容**:
- ❓ 每个组件是否有 Widget 测试
- ❓ 组件行为是否有测试覆盖
- ❓ 测试文件位置是否符合约定（`test/ui/components/`）

#### 任务 5.3: 验证 Adaptive System 规格（3 个文档）
- `ui/adaptive/layouts.md`
- `ui/adaptive/components.md`
- `ui/adaptive/platform_detection.md`

**验证内容**:
- ❓ 自适应逻辑是否有测试
- ❓ 平台检测是否有测试
- ❓ 响应式布局是否有测试

---

### 阶段 6: 报告生成（预计 30 分钟）

#### 任务 6.1: 汇总所有不符合项
- **输入**: 阶段 2-5 的验证结果
- **输出**: 不符合项列表（按类型分类）
- **格式**: 
  ```
  {
    "type": "A|B|C|D|E",
    "severity": "Critical|High|Medium|Low",
    "spec_file": "path/to/spec.md",
    "test_file": "path/to/test.rs",
    "scenario": "Scenario name",
    "description": "详细描述",
    "suggestion": "改进建议"
  }
  ```

#### 任务 6.2: 计算统计数据
- **指标**:
  - 规格文档总数: 67
  - 测试文件总数: ?
  - 场景总数: ?
  - 测试用例总数: ?
  - 不符合项总数: ?
  - 合规率: (场景总数 - 不符合项) / 场景总数 * 100%
  - 按类型统计: A/B/C/D/E 各多少项
  - 按严重程度统计: Critical/High/Medium/Low 各多少项

#### 任务 6.3: 生成 Markdown 报告
- **输出文件**: `docs/reports/spec-test-validation-report.md`
- **报告结构**: 见下文"报告结构模板"

#### 任务 6.4: 生成改进建议优先级列表
- **排序规则**:
  1. Critical 优先
  2. High 次之
  3. Medium 再次
  4. Low 最后
- **输出**: 按优先级排序的改进建议列表

---

## 报告结构模板

```markdown
# CardMind 规格-测试验证报告
# Spec-Test Validation Report

**验证日期**: YYYY-MM-DD
**验证范围**: 所有测试（Rust + Flutter）
**验证深度**: 完整验证

---

## 执行摘要

### 验证统计

| 指标 | 数量 |
|------|------|
| 规格文档总数 | 67 |
| 测试文件总数 | ? |
| 场景总数 | ? |
| 测试用例总数 | ? |
| 不符合项总数 | ? |
| 合规率 | ?% |

### 不符合项分类

| 类型 | 严重程度 | 数量 |
|------|----------|------|
| A: 缺失的测试文件 | Critical | ? |
| B: 缺失的场景测试 | High | ? |
| C: 测试命名不规范 | Medium | ? |
| D: GIVEN-WHEN-THEN 不完整 | Medium | ? |
| E: 断言不充分 | Low | ? |

---

## 详细验证结果

### Domain Layer (5 个规格)

#### ✅ domain/pool/model.md
- **测试文件**: `rust/tests/sp_spm_001_spec.rs`
- **状态**: 部分符合
- **不符合项**:
  - [B-High] 缺失场景: "Device leaves pool and clears data"
  - [E-Low] 断言不充分: "Create card auto-joins the pool" 场景未验证同步开始

#### ❌ domain/card/model.md
- **测试文件**: 未找到
- **状态**: 不符合
- **不符合项**:
  - [A-Critical] 缺失测试文件

#### ...

### Architecture Layer (15 个规格)

#### ✅ architecture/sync/service.md
- **测试文件**: `rust/tests/sp_sync_006_spec.rs`
- **状态**: 符合
- **不符合项**: 无

#### ...

### Features Layer (5 个规格)

#### ...

### UI Layer (32 个规格)

#### ...

---

## 改进建议优先级列表

### Critical (必须立即修复)

1. **[A-Critical] 创建缺失的测试文件**
   - `domain/card/model.md` → 创建 `rust/tests/card_model_test.rs`
   - `domain/card/rules.md` → 创建 `rust/tests/card_rules_test.rs`
   - ...

### High (应尽快修复)

2. **[B-High] 补充缺失的场景测试**
   - `domain/pool/model.md` → 添加 "Device leaves pool and clears data" 测试
   - ...

### Medium (建议修复)

3. **[C-Medium] 规范化测试命名**
   - `test_join_pool()` → `it_should_allow_joining_first_pool_successfully()`
   - ...

4. **[D-Medium] 补充 GIVEN-WHEN-THEN 注释**
   - ...

### Low (可选修复)

5. **[E-Low] 增强断言覆盖**
   - ...

---

## 附录

### A. 验证方法说明

本报告使用以下方法进行验证：
1. 规格-测试映射分析
2. 场景覆盖度验证
3. 测试实现质量检查
4. 报告生成

详细方法请参见 `docs/plans/2026-02-01-spec-test-validation-plan.md`。

### B. 规格-测试映射表

| 规格文件 | 测试文件 | 状态 |
|---------|---------|------|
| domain/pool/model.md | rust/tests/sp_spm_001_spec.rs | ✅ |
| domain/card/model.md | - | ❌ |
| ... | ... | ... |

### C. 测试命名规范

**推荐命名**: `it_should_<behavior>_when_<condition>()`

**示例**:
- ✅ `it_should_allow_joining_first_pool_successfully()`
- ✅ `it_should_reject_joining_second_pool_when_already_joined()`
- ❌ `test_join_pool()`
- ❌ `test_device_can_join_pool()`

---

**报告生成时间**: YYYY-MM-DD HH:MM:SS
**生成工具**: CardMind Spec-Test Validator
```

---

## 验收标准

### 必须满足的条件

- ✅ 所有 67 个规格文档都已验证
- ✅ 生成完整的 Markdown 报告
- ✅ 每个不符合项都有详细说明和改进建议
- ✅ 报告包含统计摘要和合规率
- ✅ 报告保存到 `docs/reports/spec-test-validation-report.md`
- ✅ 不符合项按严重程度分类
- ✅ 改进建议按优先级排序

### 质量标准

- ✅ 报告清晰易读，结构合理
- ✅ 不符合项描述准确，有具体代码位置
- ✅ 改进建议可操作，有明确的修复方向
- ✅ 统计数据准确，计算方法透明

---

## 风险和限制

### 已知限制

1. **自动化程度**: 本次验证为一次性手动验证，未创建自动化工具
2. **测试执行**: 仅验证测试代码是否存在和结构是否正确，不执行测试
3. **语义分析**: 无法深度分析测试逻辑的正确性，仅检查结构和命名
4. **Flutter 测试**: Flutter Widget 测试的验证可能不如 Rust 测试详细

### 潜在风险

1. **规格文档不完整**: 部分规格可能缺少 `Related Tests` 字段
2. **测试文件命名不一致**: 可能存在未按约定命名的测试文件
3. **时间估算**: 实际执行时间可能超过预估（总计约 4.5 小时）

---

## 后续行动

### 立即行动

1. **执行验证**: 使用 Superpowers ExecutePlan 执行本计划
2. **生成报告**: 完成验证后生成 Markdown 报告
3. **审查报告**: 与团队一起审查验证结果

### 短期行动（1-2 周）

1. **修复 Critical 问题**: 创建缺失的测试文件
2. **修复 High 问题**: 补充缺失的场景测试
3. **规范化命名**: 统一测试命名风格

### 长期行动（1-3 个月）

1. **创建自动化工具**: 将验证流程自动化，集成到 CI/CD
2. **持续监控**: 定期运行验证，确保规格-测试一致性
3. **完善规格**: 补充缺失的规格文档

---

## 参考文档

- `../../openspec/specs/engineering/guide.md`（原路径，v1 清理后已移除）
- `../testing/TESTING_GUIDE.md`（原路径，v1 清理后已移除）
- [CLAUDE.md](../../CLAUDE.md)
- [AGENTS.md](../../AGENTS.md)

---

**最后更新**: 2026-02-01
**维护者**: CardMind Team
**状态**: 待执行
