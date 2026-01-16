# CardMind AI Agent 指南

## 项目概述

**CardMind** = Flutter + Rust 离线优先的卡片笔记应用
- MVP v1.0.0 完成 ✅
- 当前: Phase 6R - Spec Coding 重构 🔄
- **核心**: 双层架构 (Loro CRDT → SQLite), P2P 同步 (libp2p)

---

## 快速开始

**每次任务开始前**，按顺序阅读：
1. `openspec/specs/README.md` - 规范中心索引
2. `project-guardian.toml` - 代码约束配置
3. `docs/requirements/product_vision.md` - 产品愿景

---

## 工具链

### OpenSpec - 规范驱动开发

**用途**: 管理 API 规范和架构决策

**关键文件**:
- `openspec/specs/` - 11 个功能规范 + 5 个 ADR
- `openspec/specs/SPEC_CODING_GUIDE.md` - Spec Coding 方法论

**工作流**:
```
1. 查看规范 → 2. 编写测试 → 3. 实现代码 → 4. 验证
```

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
| 架构决策 | `openspec/specs/adr/` |
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
