# Git Hooks 集成指南

本文档说明如何将 Project Guardian 集成到 Git hooks 中，实现自动化约束验证。

---

## 📋 可用的 Hooks

### 1. Pre-commit Hook

**功能**: 在提交前自动运行约束验证

**位置**: `.project-guardian/hooks/pre-commit`

**作用**:
- 自动检测代码中的约束违规
- 阻止不符合约束的代码提交
- 提供清晰的错误信息和修复建议

---

## 🚀 安装 Hooks

### 方法 1: 手动安装（推荐）

```bash
# 1. 复制 hook 到 .git/hooks/
cp .project-guardian/hooks/pre-commit .git/hooks/pre-commit

# 2. 设置可执行权限
chmod +x .git/hooks/pre-commit

# 3. 测试 hook
git commit --dry-run
```

### 方法 2: 使用符号链接

```bash
# 1. 创建符号链接
ln -s ../../.project-guardian/hooks/pre-commit .git/hooks/pre-commit

# 2. 设置可执行权限
chmod +x .git/hooks/pre-commit
```

### 方法 3: 使用 Git 配置（Git 2.9+）

```bash
# 设置 hooks 目录
git config core.hooksPath .project-guardian/hooks

# 设置可执行权限
chmod +x .project-guardian/hooks/pre-commit
```

---

## 🔧 Hook 工作流程

### Pre-commit Hook 流程

```
用户执行: git commit -m "message"
    ↓
Pre-commit hook 触发
    ↓
检查 project-guardian.toml 是否存在
    ↓
运行: dart tool/validate_constraints.dart
    ↓
┌─────────────────────────────────────┐
│ 验证结果                             │
├─────────────────────────────────────┤
│ ✅ 通过 → 允许提交                   │
│ ❌ 失败 → 阻止提交，显示错误信息      │
└─────────────────────────────────────┘
```

---

## 📊 使用示例

### 场景 1: 约束检查通过

```bash
$ git commit -m "feat: add new feature"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛡️  Project Guardian - Pre-commit Hook
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

运行约束验证...

检查 Project Guardian 配置
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 配置文件存在: project-guardian.toml

检查 Rust 代码约束
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 未发现 unwrap() 使用
✅ 未发现 expect() 使用
✅ 未发现 panic! 使用
✅ 未发现直接修改 SQLite

检查 Dart/Flutter 代码约束
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 未发现 print() 使用
✅ 未发现 TODO 注释

验证报告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
总检查项: 6
通过: 6
失败: 0

✅ 所有检查通过！✨

✅ 所有约束检查通过，允许提交

[dev abc1234] feat: add new feature
 2 files changed, 50 insertions(+)
```

### 场景 2: 约束检查失败

```bash
$ git commit -m "feat: add feature with unwrap"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛡️  Project Guardian - Pre-commit Hook
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

运行约束验证...

检查 Rust 代码约束
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ 发现 unwrap() 使用 (1 处)
  → rust/src/api/new_feature.rs:42:    let value = foo().unwrap();

验证报告
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
总检查项: 6
通过: 5
失败: 1

❌ 有 1 项检查失败

❌ 约束检查失败，提交被阻止

请修复以下问题后再提交：
1. 查看错误信息并修复代码
2. 查看 .project-guardian/failures.log 了解详情
3. 参考 .project-guardian/best-practices.md 获取帮助

如果需要跳过验证（不推荐），使用：
git commit --no-verify
```

---

## ⚙️ 配置选项

### 跳过 Hook 验证

如果确实需要跳过验证（例如紧急修复），可以使用：

```bash
# 跳过所有 hooks
git commit --no-verify -m "emergency fix"

# 或使用简写
git commit -n -m "emergency fix"
```

**⚠️ 警告**: 仅在紧急情况下使用，跳过验证可能导致代码质量问题。

### 自定义验证级别

可以在 hook 中添加环境变量控制验证级别：

```bash
# 仅快速检查（不运行编译）
GUARDIAN_QUICK=1 git commit -m "message"

# 完整验证（包括编译和测试）
GUARDIAN_FULL=1 git commit -m "message"
```

修改 `.project-guardian/hooks/pre-commit`:

```bash
# 在 dart tool/validate_constraints.dart 前添加
if [ "$GUARDIAN_FULL" = "1" ]; then
    dart tool/validate_constraints.dart --full
elif [ "$GUARDIAN_QUICK" = "1" ]; then
    dart tool/validate_constraints.dart
else
    dart tool/validate_constraints.dart
fi
```

---

## 🔍 故障排查

### 问题 1: Hook 未执行

**症状**: 提交时没有看到 Project Guardian 输出

**解决方案**:
```bash
# 检查 hook 是否存在
ls -la .git/hooks/pre-commit

# 检查是否有可执行权限
chmod +x .git/hooks/pre-commit

# 检查 Git 配置
git config core.hooksPath
```

### 问题 2: Hook 执行失败

**症状**: Hook 执行但报错

**解决方案**:
```bash
# 手动运行验证脚本测试
dart tool/validate_constraints.dart

# 检查 Dart 是否安装
dart --version

# 检查配置文件是否存在
ls -la project-guardian.toml
```

### 问题 3: Hook 太慢

**症状**: 每次提交都要等很久

**解决方案**:
```bash
# 使用快速模式（不运行编译）
# 修改 hook 使用默认快速模式

# 或者只在 CI 中运行完整验证
# 本地使用快速验证
```

---

## 🎯 最佳实践

### 1. 团队协作

在团队中使用 Project Guardian hooks：

```bash
# 在项目 README 中添加安装说明
echo "## 安装 Git Hooks" >> README.md
echo "" >> README.md
echo "```bash" >> README.md
echo "cp .project-guardian/hooks/pre-commit .git/hooks/pre-commit" >> README.md
echo "chmod +x .git/hooks/pre-commit" >> README.md
echo "```" >> README.md
```

### 2. CI/CD 集成

在 CI/CD 中也运行相同的验证：

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: dart-lang/setup-dart@v1
      - name: Run Project Guardian
        run: dart tool/validate_constraints.dart --full
```

### 3. 渐进式采用

如果项目已有大量代码违规：

```bash
# 1. 先安装 hook 但设置为警告模式
# 修改 hook 最后的 exit 1 为 exit 0

# 2. 逐步修复违规
dart tool/validate_constraints.dart > violations.txt
# 根据 violations.txt 逐个修复

# 3. 修复完成后启用强制模式
# 改回 exit 1
```

---

## 📚 相关资源

- **Hook 脚本**: `.project-guardian/hooks/pre-commit`
- **验证脚本**: `tool/validate_constraints.dart`
- **配置文件**: `project-guardian.toml`
- **使用指南**: `.project-guardian/README.md`
- **快速参考**: `.project-guardian/QUICK_REFERENCE.md`

---

## 🆘 获取帮助

如果遇到问题：

1. 查看 `.project-guardian/failures.log` 了解详细错误
2. 参考 `.project-guardian/best-practices.md` 获取修复建议
3. 查看 `.project-guardian/anti-patterns.md` 了解常见错误
4. 手动运行 `dart tool/validate_constraints.dart` 调试

---

*最后更新: 2026-01-16*
