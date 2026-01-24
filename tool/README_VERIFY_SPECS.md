# 规格验证工具使用文档

## 概述

`verify_spec_sync.dart` 是一个用于验证 CardMind 项目中规格文档与代码实现同步性的自动化工具。

## 功能

工具执行三层验证：

1. **覆盖率检查（Coverage Check）**
   - 扫描 Rust 模块和 Flutter 组件
   - 检查每个代码模块是否有对应的规格文档
   - 识别孤立的规格（有规格但无代码实现）
   - 计算规格覆盖率百分比

2. **结构验证（Structure Validation）**
   - 验证规格文档是否遵循命名约定（snake_case）
   - 检查规格是否包含必需的章节（Requirements）
   - 检测技术栈前缀（rust_/flutter_）的使用

3. **迁移验证（Migration Validation）**
   - 验证新领域驱动结构的完整性
   - 检查旧规格目录是否标记为 DEPRECATED
   - 检测引用到旧位置的问题

## 使用方法

### 基本用法

```bash
# 全量验证
dart tool/verify_spec_sync.dart

# 详细输出
dart tool/verify_spec_sync.dart --verbose
```

### 选择性扫描

```bash
# 仅验证领域模块（Rust + domain specs）
dart tool/verify_spec_sync.dart --scope=domain

# 仅验证功能组件（Flutter + feature specs）
dart tool/verify_spec_sync.dart --scope=features

# 验证特定模块
dart tool/verify_spec_sync.dart --module=card_store
```

### 命令行选项

| 选项 | 简写 | 说明 | 默认值 |
|------|------|------|--------|
| `--scope` | `-s` | 验证范围: all, domain, features | all |
| `--module` | `-m` | 仅验证指定模块 | - |
| `--verbose` | `-v` | 详细输出 | false |
| `--help` | `-h` | 显示帮助信息 | - |

## 输出报告

工具生成两种格式的报告：

### 1. Markdown 报告 (`SPEC_SYNC_REPORT.md`)

人类可读的详细报告，包含以下章节：

- **Summary**: 覆盖率统计和问题总数
- **Missing Specs**: 有代码但缺少规格的模块列表
- **Orphaned Specs**: 有规格但无代码实现的列表
- **Structure Issues**: 规格文档结构问题
- **Migration Issues**: 迁移相关问题

### 2. JSON 报告 (`spec_sync_report.json`)

机器可解析的数据，适用于自动化处理和集成。

## 理解报告

### 问题优先级

- **CRITICAL**: 必须修复的严重问题
  - Rust 模块缺少规格（领域逻辑必须有文档）
  - 关键目录缺失

- **WARNING**: 应该关注的警告
  - Flutter 组件缺少规格
  - 规格文档结构不规范
  - 引用旧位置的问题

### 覆盖率解读

```
覆盖率: 45.9% (28/61 模块有规格)
```

- **28**: 有对应规格的代码模块数量
- **61**: 总代码模块数量
- **45.9%**: 覆盖率百分比

理想覆盖率目标：
- 领域模块（Rust）: 100%
- 核心功能组件: 80%+
- 辅助组件: 60%+

## 常见使用场景

### 场景 1: 重大重构后验证

```bash
# 完成重构后，运行全量验证
dart tool/verify_spec_sync.dart --verbose

# 查看报告
cat SPEC_SYNC_REPORT.md

# 根据报告补充缺失的规格
```

### 场景 2: 新功能开发前检查

```bash
# 检查相关模块是否有规格
dart tool/verify_spec_sync.dart --module=card_store

# 如果缺少规格，先补充规格再开发
```

### 场景 3: 定期维护

```bash
# 每周/月运行一次，确保规格不过时
dart tool/verify_spec_sync.dart

# 跟踪覆盖率变化趋势
```

## 工作原理

### 代码扫描

1. **Rust 模块扫描**
   - 扫描 `rust/src/` 目录下的 `.rs` 文件
   - 排除测试文件（`test/` 目录）
   - 提取模块名称（文件基础名）

2. **Flutter 组件扫描**
   - 扫描 `lib/widgets/`, `lib/screens/`, `lib/adaptive/` 目录
   - 排除生成文件（`.g.dart`, `.freezed.dart`, `.mocks.dart`）
   - 提取组件名称

### 规格映射

工具使用以下映射规则查找对应的规格：

| 代码类型 | 规格位置 |
|---------|---------|
| Rust 模块 | `openspec/specs/domain/<module>.md` 或 `api/api_spec.md` |
| Flutter 组件 | `openspec/specs/features/*/<component>.md` 或 `ui_system/<component>.md` |

### 验证逻辑

1. 扫描所有代码模块
2. 对每个模块，查找对应的规格文件
3. 记录缺失的规格（有代码无规格）
4. 扫描所有规格文件，检查是否有对应的代码
5. 记录孤立的规格（有规格无代码）
6. 验证规格文档的结构和命名约定
7. 检查迁移相关问题

## 注意事项

### 误报处理

某些情况下可能出现误报：

1. **特殊文件**: 工具会跳过 README, DEPRECATED 等特殊文件
2. **抽象规格**: 如 `common_types.md` 可能没有对应的单独文件
3. **UI 规格**: 可能描述多个组件的协作，而非单一组件

遇到误报时：
- 确认是否真的是误报
- 如果是合理的设计，可以忽略该警告
- 如果需要调整，修改工具的扫描逻辑

### 最佳实践

1. **定期运行**: 建议在重大变更后运行验证
2. **优先修复 CRITICAL**: 先处理严重问题
3. **渐进改进**: 不必一次性达到 100% 覆盖率
4. **保持同步**: 代码变更时同步更新规格

## 集成到工作流

### Pre-commit Hook（可选）

```bash
# .git/hooks/pre-commit
dart tool/verify_spec_sync.dart --scope=domain
```

### CI/CD（可选）

```yaml
# .github/workflows/spec-validation.yml
- name: Verify Spec Sync
  run: dart tool/verify_spec_sync.dart
```

## 故障排查

### 工具运行失败

```bash
# 检查 Dart 是否安装
dart --version

# 确保在项目根目录运行
ls pubspec.yaml

# 检查依赖
flutter pub get
```

### 报告异常

如果报告内容异常，检查：
1. 是否在正确的分支上
2. 是否有未提交的文件变更
3. 规格文档是否使用正确的格式

## 更新历史

- **2026-01-20**: 初始版本，支持三层验证
- **2026-01-20**: 添加选择性扫描支持

## 参考

- 设计文档: `openspec/changes/verify-spec-code-sync/design.md`
- 规格文档: `openspec/changes/verify-spec-code-sync/specs/`
- 目录约定: `openspec/specs/engineering/directory_conventions.md`
