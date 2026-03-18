# 测试边界守护者设计文档

**日期**: 2024-03-18  
**状态**: 待实施  
**作者**: AI Assistant  

---

## 1. 背景与问题

### 1.1 当前状况

CardMind 项目使用 Flutter + Rust 混合架构，已有 41 个测试文件。但在实际开发中发现了测试盲区：

- **焦点管理缺陷**: 输入框输入数字会触发全局快捷键，导致 tab 跳转
- **边界测试缺失**: 键盘导航测试只验证了空白区域，未验证输入框获得焦点时的行为
- **测试盲区**: 79 个现有测试未能覆盖 8 大类边界条件

### 1.2 根本原因

1. 缺乏系统性的边界检查机制
2. AI 开发流程中没有强制检查边界的步骤
3. 代码变更后无法自动识别新增的边界条件

### 1.3 目标

建立一个**自动化、智能化**的测试边界守护系统，确保：
- 每次代码变更都能识别边界条件
- 未覆盖的边界被显式记录和处理
- AI 开发流程自然融入边界检查

---

## 2. 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│  代码变更触发                                                │
│  (开发完成 / 功能修改 / 重构)                                 │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  1. 代码静态分析器                                           │
│     (test_boundary_scanner.dart)                             │
│     - 解析 Dart/Rust AST                                     │
│     - 识别 8 大类边界条件                                     │
│     - 对比现有测试覆盖情况                                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  2. 质量门禁 (quality.dart)                                  │
│     - 运行测试边界扫描                                        │
│     - 生成报告到 /tmp/cardmind_test_boundary_report.md       │
│     - 输出边界覆盖统计                                        │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│  3. AI 开发流程 (AGENTS.md)                                  │
│     - 运行 quality.dart 检查                                 │
│     - 分析边界覆盖报告                                        │
│     - 执行 /checkpoint 存档                                  │
│     - 记录边界覆盖情况到 memory                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 组件设计

### 3.1 代码边界扫描器

**文件**: `tool/test_boundary_scanner.dart`

**功能**:
- 扫描 `lib/` 和 `rust/` 目录的变更文件
- 识别 8 大类边界条件（见 3.2）
- 对比 `test/` 目录中的测试覆盖情况
- 生成人类可读的边界覆盖报告

**输入**: Git diff 或文件路径列表  
**输出**: `/tmp/cardmind_test_boundary_report.md`

**报告格式**:
```markdown
# 测试边界覆盖报告
生成时间: 2024-03-18 14:30:00

## 统计
- 总边界数: 12
- 已覆盖: 9 (75%)
- 未覆盖: 3 (25%)

## 未覆盖边界（按优先级排序）

### 🔴 高优先级
1. **空值边界** - `lib/features/cards/cards_page.dart:175`
   - 代码: `if (query.isEmpty) return allCards;`
   - 建议: 测试空搜索关键词返回全部卡片

### 🟡 中优先级
2. **异常边界** - `lib/features/pool/pool_controller.dart:89`
   - 代码: `try { await api.join(); } catch (e) { ... }`
   - 建议: 测试网络超时处理

### 🟢 低优先级
3. **防抖边界** - `lib/features/cards/search_field.dart:45`
   - 代码: `debounce(Duration(milliseconds: 300), ...)`
   - 建议: 测试 300ms 内的多次输入合并

## 已覆盖边界 ✅
- 焦点边界: cards_page 输入框焦点管理
- 异步边界: pool_controller 加载状态
```

### 3.2 边界类型定义

扫描器识别以下 8 大类边界条件：

| 类别 | 识别模式 | 示例 | 优先级 |
|------|---------|------|--------|
| **条件分支** | if/else/switch | `if (query.isEmpty)` | 高 |
| **空值边界** | null check, ?. | `title?.isNotEmpty ?? false` | 高 |
| **异常边界** | try/catch | `try { ... } catch (e)` | 高 |
| **输入边界** | TextField, onChanged | `onChanged: (value) {...}` | 高 |
| **异步边界** | async/await, Future | `await controller.load()` | 中 |
| **集合边界** | empty check, index | `if (list.isEmpty)` | 中 |
| **状态边界** | initState, dispose | `@override void dispose()` | 中 |
| **UI 交互** | Focus, KeyEvent | `onKeyEvent: (e) {...}` | 高 |

### 3.3 质量检查集成

**修改文件**: `tool/quality.dart`

**新增功能**:
```dart
// 在现有质量检查流程后添加
if (hasCodeChanges) {
  await runTestBoundaryScanner();
  await displayBoundaryReport();
}
```

**输出示例**:
```
✅ flutter analyze 通过
✅ flutter test 通过 (45/45)
⚠️  边界扫描：发现 3 个未覆盖边界
   - 高优先级: 1
   - 中优先级: 1
   - 低优先级: 1
   详细报告: /tmp/cardmind_test_boundary_report.md
```

### 3.4 AI 开发流程集成

**修改文件**: `AGENTS.md`

在 **Development Workflow** 章节中，第 3 步"运行质量检查"和第 4 步"分析边界覆盖"之间，自然融入边界扫描：

```markdown
### 3. 运行质量检查

```bash
dart run tool/quality.dart <flutter|rust|all>
```

quality.dart 会自动：
- 运行代码分析和测试
- **执行边界扫描**（新增）
- 生成报告到 `/tmp/cardmind_test_boundary_report.md`

### 4. 分析边界覆盖

读取 `/tmp/cardmind_test_boundary_report.md`，检查：
- 是否有高优先级边界未覆盖
- 是否需要补充测试
- 低优先级边界是否记录到待办
```

---

## 4. 数据流

### 4.1 正常流程

```
开发完成 → quality.dart → 边界扫描 → 报告到 /tmp → AI 分析 → /checkpoint → commit
```

### 4.2 发现未覆盖边界

```
开发完成 → quality.dart → 边界扫描 → 发现高优先级未覆盖 → AI 补充测试 → 重新检查 → /checkpoint → commit
```

### 4.3 接受低优先级边界

```
开发完成 → quality.dart → 边界扫描 → 发现低优先级未覆盖 → 记录到 docs/plans/test-backlog.md → /checkpoint → commit
```

---

## 5. 配置与阈值

### 5.1 扫描器配置

**文件**: `tool/test_boundary_config.yaml`（可选）

```yaml
# 边界扫描配置
scanner:
  # 扫描目录
  include:
    - lib/
    - rust/src/
  exclude:
    - lib/bridge_generated/
    - test/
  
  # 边界类型权重（影响优先级）
  weights:
    condition: 1.0      # 条件分支
    null: 1.0           # 空值
    exception: 1.0      # 异常
    input: 1.0          # 输入
    async: 0.7          # 异步
    collection: 0.7     # 集合
    lifecycle: 0.7      # 生命周期
    interaction: 1.0    # UI 交互
  
  # 忽略模式（正则）
  ignore_patterns:
    - "test/"           # 测试文件
    - "\.g\.dart$"      # 生成文件
```

### 5.2 质量门禁阈值

**文件**: `tool/quality.dart` 内置

```dart
// 质量检查阈值
const double minBoundaryCoverage = 0.7;  // 70% 边界覆盖率
const int maxHighPriorityUncovered = 0;   // 高优先级边界必须全部覆盖
```

---

## 6. 错误处理

### 6.1 扫描器错误

- **AST 解析失败**: 跳过该文件，记录警告
- **测试文件不存在**: 标记为未覆盖
- **报告生成失败**: 输出到 stdout，不阻断流程

### 6.2 质量检查错误

- **测试失败**: 阻断提交，必须修复
- **边界覆盖率不足**: 警告，AI 决定是否处理
- **高优先级边界未覆盖**: 建议补充测试

---

## 7. 测试策略

### 7.1 扫描器自身测试

**文件**: `test/tool/test_boundary_scanner_test.dart`

测试内容：
- 正确识别各类边界条件
- 准确计算覆盖率
- 正确生成报告格式
- 处理边缘情况（空文件、语法错误等）

### 7.2 集成测试

**文件**: `test/integration/test_boundary_flow_test.dart`

测试内容：
- 完整流程：代码变更 → 扫描 → 报告 → 存档
- 与 quality.dart 集成
- 与 AGENTS.md 工作流集成

---

## 8. 配套文档：测试规范

测试边界守护系统需要配套的测试规范文档，明确测试分类和命名约定。

### 8.1 需要创建的文档

**文件**: `docs/standards/testing.md`

**内容框架**:

#### 1. 测试分类体系

**Flutter 测试** (`test/` 目录):
```
test/
├── unit/           # 单元测试：纯 Dart 逻辑，无 UI
│   ├── domain/     # 领域模型测试
│   ├── data/       # 数据层测试
│   └── application/# 应用服务测试
├── widget/         # 组件测试：单个 Widget
│   ├── pages/      # 页面级组件
│   └── components/ # 可复用组件
├── integration/    # 集成测试：多组件协作
│   ├── features/   # 功能流测试
│   └── infrastructure/ # 基础设施测试
├── contract/       # 契约测试：API 契约
│   └── api/        # API 契约测试
└── e2e/           # 端到端测试：完整用户流程
```

**Rust 测试** (`rust/tests/` 目录):
```
rust/tests/
├── unit/           # 单元测试：纯函数和结构体
├── integration/    # 集成测试：模块间协作
├── contract/       # 契约测试：FFI 接口契约
└── performance/    # 性能测试：基准测试
```

#### 2. 文件命名规范

**Dart 测试文件**:
- 格式: `{被测对象}_{测试类型}_test.dart`
- 示例:
  - `cards_controller_test.dart` - 控制器单元测试
  - `cards_page_test.dart` - 卡片页面组件测试
  - `cards_pool_filter_test.dart` - 卡片池过滤集成测试
  - `cards_api_contract_test.dart` - 卡片 API 契约测试

**Rust 测试文件**:
- 格式: `{被测对象}_{测试类型}_test.rs`
- 示例:
  - `card_model_test.rs` - 卡片模型单元测试
  - `pool_network_flow_test.rs` - 组网流程集成测试
  - `sync_api_contract_test.rs` - 同步 API 契约测试

#### 3. 测试函数命名

**Dart**:
```dart
// 格式: test_{被测行为}_{预期结果}
test('search_withEmptyQuery_returnsAllCards', () { ... });
test('search_withInvalidInput_showsErrorMessage', () { ... });
test('save_whenNetworkError_retriesThreeTimes', () { ... });
```

**Rust**:
```rust
// 格式: {被测行为}_{预期结果}
#[test]
fn search_with_empty_query_returns_all_cards() { ... }

#[test]
fn save_when_network_error_retries_three_times() { ... }
```

#### 4. 与边界扫描的关联

测试规范中定义的测试分类，将作为边界扫描器识别"测试覆盖"的依据：

- 识别到 `if (query.isEmpty)` 边界
- 扫描器查找匹配测试：`test/*search*test.dart` 或 `test/*query*test.dart`
- 检查测试函数名是否包含 `empty` 或 `invalid`
- 生成覆盖报告

### 8.2 实施方式

测试规范文档与测试边界守护系统**并行实施**：

1. **阶段 1** 同时创建 `docs/standards/testing.md`
2. 根据现有测试目录结构，整理并规范命名
3. 边界扫描器参考规范进行测试匹配

---

## 9. 实施计划

### 阶段 1: 基础扫描器 + 测试规范（1.5 天）

**任务**:
1. 创建 `docs/standards/testing.md` 测试规范文档
   - 定义测试分类体系
   - 规范文件命名约定
   - 规范测试函数命名
2. 实现 Dart AST 解析器
3. 实现 8 类边界识别器
4. 实现测试覆盖对比逻辑（参考测试规范）
5. 实现报告生成器

**产出**:
- `docs/standards/testing.md` 测试规范文档
- `tool/test_boundary_scanner.dart`（基础版）
- 可识别简单边界条件
- 生成文本报告

### 阶段 2: 质量集成（0.5 天）

**任务**:
1. 扩展 `quality.dart`，添加边界扫描调用
2. 配置报告输出到 `/tmp`
3. 在质量报告中显示边界统计

**产出**:
- 修改后的 `tool/quality.dart`
- 集成后的质量检查流程

### 阶段 3: AI 工作流（0.5 天）

**任务**:
1. 更新 `AGENTS.md`，添加 Development Workflow 章节
2. 整合现有内容，避免重复
3. 添加边界检查清单
4. 编写示例工作流程

**产出**:
- 更新后的 `AGENTS.md`
- 完整的开发流程文档

### 阶段 4: 测试与优化（0.5 天）

**任务**:
1. 编写扫描器单元测试
2. 运行集成测试
3. 优化边界识别准确率
4. 处理边界情况

**产出**:
- 测试文件
- 优化后的扫描器
- 实施总结文档

---

## 9. 风险评估

### 9.1 技术风险

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|----------|
| AST 解析复杂度高 | 中 | 中 | 使用 analyzer 包，逐步支持 |
| 误报率高 | 中 | 低 | 可调配置，AI 人工判断 |
| 性能问题 | 低 | 中 | 增量扫描，缓存结果 |

### 9.2 流程风险

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|----------|
| AI 不遵循流程 | 中 | 高 | 明确文档，示例引导 |
| 增加开发负担 | 中 | 中 | 自动化，低优先级可跳过 |
| 报告被忽视 | 中 | 中 | 集成到 checkpoint 流程 |

---

## 10. 成功指标

### 10.1 定量指标

- 边界覆盖率从当前 ?% 提升到 80%+
- 高优先级边界 100% 覆盖
- 未发现的边界缺陷减少 90%

### 10.2 定性指标

- AI 开发流程自然融入边界检查
- 代码审查时边界测试成为习惯
- 新功能开发时边界考虑前置

---

## 11. 附录

### 11.1 相关文档

- `docs/standards/tdd.md` - TDD 开发规范
- `docs/standards/test-boundary-checklist.md` - 边界检查清单（待创建）
- `AGENTS.md` - AI 工作流文档

### 11.2 参考实现

- Dart analyzer 包: https://pub.dev/packages/analyzer
- Rust syn 包: https://docs.rs/syn/ (如需扫描 Rust)

### 11.3 变更日志

- 2024-03-18: 初版设计文档

---

**设计完成，等待实施计划。**
