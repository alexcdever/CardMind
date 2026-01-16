# Project Guardian 使用指南

本文档说明如何在 CardMind 项目中使用 Project Guardian 技能。

---

## 📋 什么是 Project Guardian？

Project Guardian 是一个通用的项目约束注入系统，帮助 LLM 在编写代码时：

1. **自动发现**项目特定的约束规则
2. **动态注入**约束到 LLM 上下文
3. **强制执行**验证命令
4. **记录经验**，避免重复犯错

---

## 🚀 快速开始

### 对于 LLM

当你开始在 CardMind 项目中工作时：

1. **读取配置文件**: `project-guardian.toml`
2. **加载约束规则**: 根据操作类型（编辑 Rust/Dart/文档）
3. **应用约束**: 在编写代码时自我检查
4. **执行验证**: 修改完成后运行验证命令
5. **记录结果**: 成功/失败都记录到日志

### 对于开发者

```bash
# 1. 查看配置
cat project-guardian.toml

# 2. 查看最佳实践
cat .project-guardian/best-practices.md

# 3. 查看反模式
cat .project-guardian/anti-patterns.md

# 4. 查看失败日志
cat .project-guardian/failures.log
```

---

## 📖 配置文件结构

### 项目信息
```toml
[project]
name = "CardMind"
type = "flutter-rust"
```

### 代码编辑约束
```toml
[constraints.code_edit.rust]
forbidden_patterns = [...]  # 禁止的代码模式
required_patterns = [...]   # 必须包含的模式
validation_commands = [...]  # 验证命令
```

### 命令执行约束
```toml
[constraints.command_execution]
forbidden_commands = [...]        # 禁止的命令
require_confirmation = [...]      # 需要确认的命令
```

### 提交约束
```toml
[constraints.submission]
required_checklist = [...]  # 提交前检查清单
```

---

## 🎯 使用场景

### 场景 1: 修改 Rust 代码

**LLM 工作流程**:

1. **读取约束**:
   ```
   操作类型: code_edit
   文件类型: rust
   适用约束: constraints.code_edit.rust
   ```

2. **检查禁止模式**:
   - ❌ 不能使用 `unwrap()`
   - ❌ 不能直接修改 SQLite
   - ❌ 不能使用 `panic!()`

3. **检查必须模式**:
   - ✅ API 函数必须返回 `Result<T, Error>`
   - ✅ 修改 Loro 后必须调用 `commit()`
   - ✅ 数据模型必须实现 `Debug`

4. **编写代码**:
   ```rust
   pub fn update_card(card_id: &str, title: &str) -> Result<(), CardMindError> {
       let loro_doc = load_loro_doc(card_id)?;
       loro_doc.get_text("title").insert(0, title)?;
       loro_doc.commit(); // ✅ 必须 commit
       Ok(())
   }
   ```

5. **执行验证**:
   ```bash
   cd rust && cargo check
   cd rust && cargo clippy --all-targets --all-features -- -D warnings
   cd rust && cargo test --all-features
   ```

6. **报告结果**:
   ```
   ✅ cargo check - 通过
   ✅ cargo clippy - 0 警告
   ✅ cargo test - 128/128 通过
   ```

---

### 场景 2: 修改 Flutter 代码

**LLM 工作流程**:

1. **读取约束**:
   ```
   操作类型: code_edit
   文件类型: dart
   适用约束: constraints.code_edit.dart
   ```

2. **检查禁止模式**:
   - ❌ 不能使用 `print()`，使用 `debugPrint()`

3. **检查必须模式**:
   - ✅ Widget 必须有 `key` 参数
   - ✅ 异步操作必须检查 `mounted`

4. **编写代码**:
   ```dart
   class CardWidget extends StatelessWidget {
     const CardWidget({Key? key, required this.card}) : super(key: key);

     final Card card;

     Future<void> loadCard() async {
       final card = await api.getCard(cardId);
       if (!mounted) return; // ✅ 检查 mounted
       setState(() => _card = card);
     }
   }
   ```

5. **执行验证**:
   ```bash
   flutter analyze
   flutter test
   dart tool/check_lint.dart
   ```

---

### 场景 3: 执行危险命令

**LLM 工作流程**:

1. **检查命令约束**:
   ```
   命令: git push --force
   约束: require_confirmation
   ```

2. **请求用户确认**:
   ```
   ⚠️ 此命令需要人工确认:
   命令: git push --force
   原因: 可能覆盖远程历史
   是否继续? (y/n)
   ```

3. **记录执行**:
   ```
   [2026-01-16 17:20:00] [WARN] [command_execution]
   命令: git push --force
   用户确认: 是
   状态: 已执行
   ```

---

## 🔍 约束检查流程

### 编写代码时的自我检查

```python
# LLM 内部逻辑（伪代码）
def write_code(file_path, code):
    # 1. 分类操作
    operation_type = classify_operation(file_path)

    # 2. 加载约束
    constraints = load_constraints(operation_type, file_path)

    # 3. 检查禁止模式
    for pattern in constraints.forbidden_patterns:
        if re.search(pattern.pattern, code):
            raise ConstraintViolation(pattern.message)

    # 4. 检查必须模式
    for pattern in constraints.required_patterns:
        if not re.search(pattern.pattern, code):
            raise ConstraintViolation(pattern.message)

    # 5. 写入代码
    write_file(file_path, code)

    # 6. 执行验证
    for cmd in constraints.validation_commands:
        result = run_command(cmd)
        if result.failed:
            # 尝试自动修复
            auto_fix(file_path, result.errors)

    # 7. 记录结果
    log_result(file_path, operation_type, result)
```

---

## 📊 经验库

### 最佳实践 (best-practices.md)

记录推荐的代码模式：

- **BP-001**: Loro 修改流程
- **BP-002**: 订阅机制
- **BP-003**: 错误处理
- **BP-004**: 测试命名
- ...

### 反模式 (anti-patterns.md)

记录常见错误：

- **AP-001**: 直接修改 SQLite
- **AP-002**: 忘记 commit()
- **AP-003**: 使用 unwrap()
- **AP-004**: 硬删除数据
- ...

### 失败日志 (failures.log)

记录约束违规：

```
[时间戳] [级别] [操作] [文件]
描述: ...
约束: ...
修复: ...
状态: ...
```

---

## 🎓 学习模式

### LLM 如何学习

1. **首次违规**: 检测到违规 → 记录到 failures.log
2. **自动修复**: 尝试修复 → 记录修复方案
3. **模式识别**: 分析 failures.log → 识别常见错误
4. **更新约束**: 将新模式添加到配置文件
5. **持续改进**: 跨会话学习，避免重复犯错

### 示例学习循环

```
第1次: 使用 unwrap() → 违规 → 修复为 ? → 记录
第2次: 使用 expect() → 违规 → 修复为 ? → 记录
第3次: 识别模式 → 添加约束 "禁止 unwrap/expect"
第4次: 自动检测 → 直接使用 ? → 无违规
```

---

## 🔧 自定义约束

### 添加新的禁止模式

编辑 `project-guardian.toml`:

```toml
[constraints.code_edit.rust]
forbidden_patterns = [
  # 现有模式...

  # 添加新模式
  { pattern = "unsafe \\{", message = "❌ 禁止使用 unsafe 代码块" },
]
```

### 添加新的验证命令

```toml
[constraints.code_edit.rust]
validation_commands = [
  # 现有命令...

  # 添加新命令
  "cd rust && cargo audit",  # 安全审计
]
```

### 添加新的规则

```toml
[[rules.security]]
name = "密码加密"
description = "密码必须使用 bcrypt 加密"
enforcement = "strict"
violation_action = "block"
```

---

## 📈 统计和报告

### 查看统计信息

```bash
# 查看失败次数
grep -c "ERROR" .project-guardian/failures.log

# 查看最常见违规
grep "约束:" .project-guardian/failures.log | sort | uniq -c | sort -rn

# 查看修复率
grep "状态: 已修复" .project-guardian/failures.log | wc -l
```

### 生成报告

```bash
# 生成每周报告
cat << EOF
Project Guardian 周报
==================
总违规次数: $(grep -c "ERROR" .project-guardian/failures.log)
已修复: $(grep -c "已修复" .project-guardian/failures.log)
待修复: $(grep -c "待修复" .project-guardian/failures.log)
最常见违规: $(grep "约束:" .project-guardian/failures.log | head -1)
EOF
```

---

## 🎯 核心价值

### 对 LLM
- 从"记住规则" → "调用技能，技能注入规则"
- 从"被动遵守" → "主动应用约束"
- 从"固定工具链" → "动态发现可用工具"

### 对开发者
- 一套技能，所有项目通用
- 新项目 5 分钟配置完成
- 约束清晰透明（在 toml 中）
- 强制执行，质量可控

### 对项目
- 约束即代码（版本控制）
- 历史经验可积累
- 团队成员统一标准
- 新人快速上手

---

## 🚀 下一步

1. **阅读配置**: `cat project-guardian.toml`
2. **查看示例**: 阅读 best-practices.md 和 anti-patterns.md
3. **开始使用**: LLM 自动应用约束
4. **持续改进**: 根据 failures.log 优化约束

---

## 📞 支持

- **配置问题**: 检查 `project-guardian.toml` 语法
- **约束问题**: 查看 `best-practices.md` 和 `anti-patterns.md`
- **验证失败**: 查看 `failures.log` 了解原因

---

*最后更新: 2026-01-16*
