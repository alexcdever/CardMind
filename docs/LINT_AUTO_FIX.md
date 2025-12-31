# 自动化Lint修复指南

本项目配置了完善的自动化lint修复工具，可以自动检测和修复Flutter和Rust代码中的大部分问题。

## 快速开始

### 一键修复所有问题

```bash
dart tool/fix_lint.dart
```

这个命令会：
1. 格式化所有Dart代码（`dart format`）
2. 应用Dart自动修复（`dart fix --apply`）
3. 运行Flutter静态分析（`flutter analyze`）
4. 格式化所有Rust代码（`cargo fmt`）
5. 运行Rust检查（`cargo check`）
6. 运行Clippy并自动修复（`cargo clippy --fix`）

### 只检查不修复

```bash
dart tool/check_lint.dart
```

这个命令会检查所有问题但不会修改文件，适合在CI或提交前验证。

### 分别处理Flutter和Rust

```bash
# 只修复Flutter/Dart代码
dart tool/fix_lint.dart --flutter-only

# 只修复Rust代码
dart tool/fix_lint.dart --rust-only
```

## VSCode集成

### 保存时自动格式化

项目已配置 `.vscode/settings.json`，会在保存文件时自动：
- 格式化代码
- 组织imports
- 修复简单的lint问题

### 使用任务面板

按 `Ctrl+Shift+P`（Mac: `Cmd+Shift+P`），输入 "Run Task"，然后选择：

- **Lint: Fix All** - 修复所有lint问题
- **Lint: Check Only** - 只检查不修复
- **Lint: Fix Flutter Only** - 只修复Flutter
- **Lint: Fix Rust Only** - 只修复Rust
- **Flutter: Analyze** - 运行flutter analyze
- **Rust: Clippy** - 运行cargo clippy
- **Rust: Check** - 运行cargo check

## Git Pre-commit Hook

项目配置了pre-commit hook，在每次提交前自动运行检查。如果检查失败，提交会被阻止。

如果你想跳过hook（不推荐），可以使用：
```bash
git commit --no-verify
```

## 常见问题解决

### 问题1: IDE显示错误但代码可以编译

**症状**: VSCode显示红色波浪线，但`flutter analyze`和`cargo check`都通过。

**解决方法**:
1. 重启VSCode
2. 运行 `dart tool/fix_lint.dart`
3. 在VSCode中运行 "Dart: Restart Analysis Server" 或 "Rust Analyzer: Reload Workspace"

### 问题2: `use_build_context_synchronously` 警告

**症状**: 在异步操作后使用`BuildContext`时出现警告。

**解决方法**:
在使用`context`之前添加`mounted`检查：
```dart
// 错误
final result = await someAsyncOperation();
Navigator.pop(context);

// 正确
final result = await someAsyncOperation();
if (!mounted) return;
Navigator.pop(context);
```

### 问题3: `avoid_slow_async_io` 警告

**症状**: 使用`await directory.exists()`等异步IO方法时出现警告。

**解决方法**:
使用同步版本：
```dart
// 警告
if (await directory.exists()) { }

// 正确
if (directory.existsSync()) { }
```

### 问题4: Rust `unexpected_cfgs` 警告

**症状**: IDE显示关于`frb_expand`的cfg警告。

**解决方法**:
已在`rust/Cargo.toml`中配置，如果仍有问题，运行：
```bash
cd rust && cargo check
```

## 配置文件说明

### Flutter/Dart配置
- **analysis_options.yaml** - Dart静态分析规则
- **.vscode/settings.json** - VSCode编辑器配置

### Rust配置
- **rust/Cargo.toml** - `[lints.rust]`和`[lints.clippy]`部分
- **rust/src/lib.rs** - `#![allow(unexpected_cfgs)]`

### 自动化脚本
- **tool/fix_lint.dart** - 主要的自动修复脚本
- **tool/check_lint.dart** - 只检查不修复的脚本
- **.git/hooks/pre-commit** - Git提交前检查

## 最佳实践

1. **编写代码时**: 让VSCode自动格式化和修复（保存时触发）
2. **提交代码前**: 运行 `dart tool/check_lint.dart` 验证
3. **CI/CD中**: 使用 `dart tool/check_lint.dart --check-only` 验证
4. **修复批量问题**: 运行 `dart tool/fix_lint.dart`

## 命令速查表

| 目的 | 命令 |
|------|------|
| 修复所有问题 | `dart tool/fix_lint.dart` |
| 只检查不修复 | `dart tool/check_lint.dart` |
| 只修复Flutter | `dart tool/fix_lint.dart --flutter-only` |
| 只修复Rust | `dart tool/fix_lint.dart --rust-only` |
| Flutter分析 | `flutter analyze` |
| Dart格式化 | `dart format .` |
| Dart自动修复 | `dart fix --apply` |
| Rust检查 | `cd rust && cargo check` |
| Rust格式化 | `cd rust && cargo fmt` |
| Rust Clippy | `cd rust && cargo clippy` |
| Clippy自动修复 | `cd rust && cargo clippy --fix` |

## 扩展阅读

- [Dart lint规则文档](https://dart.dev/tools/linter-rules)
- [Flutter lint包](https://pub.dev/packages/flutter_lints)
- [Cargo Clippy文档](https://doc.rust-lang.org/clippy/)
- [Rust编译器lint](https://doc.rust-lang.org/rustc/lints/index.html)
