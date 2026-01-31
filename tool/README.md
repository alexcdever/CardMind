# CardMind 工具脚本

本目录包含 CardMind 项目的开发工具脚本。

## 核心脚本

### quality_check.dart - 质量检查

**用途**: 运行完整的代码质量检查，包括静态分析和测试，收集所有错误信息。

**基本用法**:
```bash
# 完整质量检查（推荐）
dart tool/quality_check.dart

# 仅检查，不修复
dart tool/quality_check.dart --check-only

# 自动修复简单问题（格式化、lint）
dart tool/quality_check.dart --auto-fix

# 仅检查 Flutter 代码
dart tool/quality_check.dart --flutter-only

# 仅检查 Rust 代码
dart tool/quality_check.dart --rust-only

# 跳过测试，仅静态检查
dart tool/quality_check.dart --no-tests

# 不保存错误日志
dart tool/quality_check.dart --no-save-errors
```

**检查内容**:

**Flutter/Dart**:
- ✅ 代码格式化 (`dart format`)
- ✅ 自动修复 (`dart fix`, 仅 `--auto-fix` 模式)
- ✅ 静态分析 (`flutter analyze`)
- ✅ 单元测试 (`flutter test`)

**Rust**:
- ✅ 代码格式化 (`cargo fmt`)
- ✅ 编译检查 (`cargo check`)
- ✅ Clippy 检查 (`cargo clippy`)
- ✅ 单元测试 (`cargo test`)

**错误日志**:
- 所有错误自动保存到 `/tmp/cardmind_errors.log`
- 格式清晰，易于阅读和 AI 处理
- 包含错误分类和统计信息

**典型工作流**:
```bash
# 1. 运行质量检查
dart tool/quality_check.dart --check-only

# 2. 查看错误日志
cat /tmp/cardmind_errors.log

# 3. 修复错误（手动或通过 AI）
# 告诉 AI: "请根据 /tmp/cardmind_errors.log 中的错误逐一修复"

# 4. 再次检查
dart tool/quality_check.dart --check-only
```

---

### run_tests.dart - 测试运行器

**用途**: 快速运行测试，支持不同类型的测试和选项。

**基本用法**:
```bash
# 运行所有测试
dart tool/run_tests.dart all

# 运行规格测试
dart tool/run_tests.dart specs

# 运行组件测试
dart tool/run_tests.dart widgets

# 运行屏幕测试
dart tool/run_tests.dart screens

# 运行集成测试
dart tool/run_tests.dart integration

# 生成覆盖率报告
dart tool/run_tests.dart coverage

# 监听模式
dart tool/run_tests.dart watch
```

---

## 其他脚本

### build_all.dart
构建所有平台的应用。

### generate_bridge.dart
生成 Rust-Flutter 桥接代码。

### check_markdown_links.dart
检查 Markdown 文档中的链接有效性。

---

## 推荐工作流

### 开发前检查
```bash
dart tool/quality_check.dart --check-only --no-tests
```

### 提交前检查
```bash
dart tool/quality_check.dart
```

### 快速测试
```bash
dart tool/run_tests.dart all
```

### CI/CD 流程
```bash
dart tool/quality_check.dart --check-only
```

---

## 故障排除

### 问题: 格式化失败
**解决**: 使用 `--auto-fix` 自动修复
```bash
dart tool/quality_check.dart --auto-fix
```

### 问题: 测试超时
**解决**: 跳过测试，仅运行静态检查
```bash
dart tool/quality_check.dart --no-tests
```

### 问题: 错误日志太长
**解决**: 分别检查 Flutter 和 Rust
```bash
dart tool/quality_check.dart --flutter-only
dart tool/quality_check.dart --rust-only
```

---

**最后更新**: 2026-01-31
