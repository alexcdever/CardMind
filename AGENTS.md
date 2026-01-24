# CardMind AI Agent 指南

## 项目概述

**CardMind** = Flutter + Rust 离线优先的卡片笔记应用
- **核心**: 双层架构 (Loro CRDT → SQLite), P2P 同步 (libp2p)
- **特点**: 离线优先、CRDT 数据一致性、规范驱动开发

---

## 快速开始

**每次任务开始前**，按顺序阅读：
1. `openspec/specs/README.md` - 规范中心索引
2. `project-guardian.toml` - 代码约束配置
3. `docs/requirements/product_vision.md` - 产品愿景

---

## 工具链

### OpenSpec - 规范驱动开发

**用途**: 管理 API 规范和架构决策，通过结构化的 artifacts 管理变更

**关键文件**:
- `openspec/specs/` - 11 个功能规范 + 5 个 ADR
- `openspec/specs/SPEC_CODING_GUIDE.md` - Spec Coding 方法论
- `openspec/changes/` - 进行中的变更
- `openspec/changes/archive/` - 已完成的变更

**完整工作流**:
```
1. 开始新变更 → 2. 创建 artifacts → 3. 实施任务 → 4. 验证 → 5. 同步规格 → 6. 归档
```

#### OpenSpec 命令详解

**1️⃣ 开始新变更**
```bash
/opsx:new
```
- **作用**: 创建新的 change 目录和配置文件
- **生成**: `openspec/changes/<change-name>/` + `.openspec.yaml`
- **何时使用**: 开始实现新功能、修复复杂 bug、重构模块

**2️⃣ 探索模式（可选）**
```bash
/opsx:explore
```
- **作用**: 进入探索模式，深入思考和调研
- **适用**: 需求不清晰、技术方案不确定时
- **输出**: 思考过程、技术调研、方案对比

**3️⃣ 创建 artifacts**

**方式 A: 逐步创建（推荐复杂变更）**
```bash
/opsx:continue
```
- **作用**: 按顺序创建下一个 artifact
- **顺序**: `proposal.md` → `design.md` → `specs/` → `tasks.md`
- **优点**: 可以审查每个阶段的输出
- **何时使用**: 需要仔细审查每个阶段

**方式 B: 快速生成（推荐简单变更）**
```bash
/opsx:ff
```
- **作用**: 一次性生成所有 artifacts
- **优点**: 快速进入实施阶段
- **何时使用**: 需求明确、方案清晰

**4️⃣ 实施任务**
```bash
/opsx:apply
```
- **作用**: 根据 `tasks.md` 实现功能
- **方法**: Spec Coding（规格 → 测试 → 代码）
- **跟踪**: 自动跟踪任务进度
- **何时使用**: artifacts 创建完成，准备编码

**5️⃣ 验证实现**
```bash
/opsx:verify
```
- **作用**: 验证实现是否符合 specs
- **检查**: 测试覆盖率、任务完成度、规格一致性
- **何时使用**: 实施完成后，归档前

**6️⃣ 同步规格**
```bash
/opsx:sync
```
- **作用**: 将 delta specs 同步到 `openspec/specs/`
- **更新**: 规格索引 `openspec/specs/README.md`
- **何时使用**: change 中创建了新的规格文档

**7️⃣ 归档变更**
```bash
/opsx:archive
```
- **作用**: 将 change 移动到 archive 目录
- **标记**: 变更完成
- **何时使用**: 验证通过，准备提交 PR

#### 快速参考表

| 场景 | 命令 | 说明 |
|------|------|------|
| 开始新功能 | `/opsx:new` | 创建 change |
| 需求不清楚 | `/opsx:explore` | 探索和思考 |
| 逐步创建 | `/opsx:continue` | 创建下一个 artifact |
| 快速生成 | `/opsx:ff` | 生成所有 artifacts |
| 开始编码 | `/opsx:apply` | 实施任务 |
| 验证完成 | `/opsx:verify` | 验证实现 |
| 同步规格 | `/opsx:sync` | 同步到主规格 |
| 完成归档 | `/opsx:archive` | 归档 change |

#### 示例工作流

**简单功能（快速模式）**:
```bash
/opsx:new          # 创建 change
/opsx:ff           # 生成所有 artifacts
/opsx:apply        # 实施任务
/opsx:verify       # 验证
/opsx:archive      # 归档
```

**复杂功能（仔细模式）**:
```bash
/opsx:new          # 创建 change
/opsx:explore      # 探索方案
/opsx:continue     # 创建 proposal
# 审查 proposal.md
/opsx:continue     # 创建 design
# 审查 design.md
/opsx:continue     # 创建 specs
# 审查 specs/
/opsx:continue     # 创建 tasks
# 审查 tasks.md
/opsx:apply        # 实施任务
/opsx:verify       # 验证
/opsx:sync         # 同步规格
/opsx:archive      # 归档
```

**⚠️ 常见错误**:
- ❌ 跳过 `/opsx:new` 直接使用其他命令
- ❌ 在没有 artifacts 时使用 `/opsx:apply`
- ❌ 忘记使用 `/opsx:sync` 同步新规格
- ❌ 未验证就归档（跳过 `/opsx:verify`）

### Project Guardian - 约束自动执行

**用途**: 防止 LLM 幻觉和架构违规

**关键文件**:
- `project-guardian.toml` - 约束配置
- `.project-guardian/best-practices.md` - 最佳实践
- `.project-guardian/anti-patterns.md` - 反模式

**验证命令**:
```bash
dart tool/validate_constraints.dart
```

### LSP Code Analysis - 语义代码分析

**用途**: 通过 LSP 进行 Rust 代码的语义分析和导航

**使用方法**:
```bash
# 在 Claude Code 中使用技能
/lsp-code-analysis
```

**功能**:
- 查找定义、引用、实现
- 搜索符号（函数、结构体、trait 等）
- 预览重构操作
- 获取文件大纲
- 探索不熟悉的代码库

**适用场景**:
- 理解 `rust/` 目录中的代码结构
- 查找函数调用关系
- 安全重构代码

---

## 关键命令

### 测试
```bash
# Rust 测试
cd rust && cargo test

# Spec 测试
cd rust && cargo test --test sp_spm_001_spec
cd rust && cargo test --test sp_sync_006_spec
cd rust && cargo test --test sp_mdns_001_spec

# Flutter 测试
flutter test
```

### 构建
```bash
# 构建所有平台
dart tool/build_all.dart

# 生成 Rust Bridge
dart tool/generate_bridge.dart
```

### 代码质量
```bash
# 自动修复所有 lint 问题
dart tool/fix_lint.dart

# 验证约束
dart tool/validate_constraints.dart
```

---

## 架构规则（绝不违反）

### 双层架构
1. 所有写操作 → Loro CRDT（真相源）
2. 所有读操作 → SQLite（查询缓存）
3. 数据流: `loro_doc.commit()` → 订阅 → SQLite 更新
4. **绝不直接写 SQLite**（除订阅回调）

### 数据存储
- 每张卡片 = 独立的 LoroDoc 文件
- 路径: `data/loro/<base64(uuid)>/`
- 使用 UUID v7（时间排序）
- 软删除（`deleted: bool`）

### Spec Coding
- 测试 = 规范 = 文档
- 测试命名: `it_should_do_something()`
- Spec 文件: `sp_XXX_XXX_spec.rs`

---

## 代码风格

### 文件格式（关键）
```bash
# ⚠️ 所有文本文件必须使用 Unix 换行符（LF）
# ❌ 禁止使用 Windows 换行符（CRLF）

# 检查文件换行符
file <filename>  # 应显示 "UTF-8 text"，不应有 "CRLF"

# 转换为 Unix 换行符
dos2unix <filename>
# 或
sed -i 's/\r$//' <filename>
```

**原因**: OpenSpec 和其他工具依赖 Unix 换行符来正确解析文件。Windows 换行符会导致任务解析失败。

### Rust
```rust
// 错误处理: 使用 Result<T, CardMindError>
let store = get_store()?;

// 禁止 unwrap/expect/panic
// ❌ value.unwrap()
// ✅ value?

// 文档注释
/// Creates a new card
///
/// # Arguments
/// * `title` - Card title (max 256 chars)
```

### Dart/Flutter
```dart
// 使用 debugPrint，不用 print
debugPrint('Error: $error');

// Async: 检查 mounted
if (!mounted) return;
setState(() { /* ... */ });

// Widget: const constructor
const MyWidget({Key? key}) : super(key: key);
```

---

## 文档导航

| 需求 | 查看 |
|------|------|
| API 规范 | `openspec/specs/` |
| 架构决策 | `docs/adr/` |
| 代码约束 | `project-guardian.toml` |
| 产品愿景 | `docs/requirements/product_vision.md` |
| 构建指南 | `tool/BUILD_GUIDE.md` |

---

## 提交规范

**Conventional Commits**:
```
feat(p2p): add device discovery via mDNS
fix: resolve SQLite locking issue
refactor: simplify sync filter logic
test: add test for pool edge cases
docs: update API documentation
```

**PR 要求**:
- 测试通过 (`cargo test` + `flutter test`)
- Lint 通过 (`dart tool/fix_lint.dart`)
- 约束验证通过 (`dart tool/validate_constraints.dart`)

---

**最后更新**: 2026-01-16
**规则**: 有疑问时 → 查规范 → 查 ADR → 查约束 → 问用户
