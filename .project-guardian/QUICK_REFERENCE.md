# Project Guardian 快速参考

一页纸速查表，用于日常开发。

---

## 🚀 快速命令

```bash
# 快速验证（仅检查代码模式）
dart tool/validate_constraints.dart

# 完整验证（包括编译和测试）
dart tool/validate_constraints.dart --full

# 仅验证 Rust
dart tool/validate_constraints.dart --rust-only

# 仅验证 Dart
dart tool/validate_constraints.dart --dart-only
```

---

## ❌ Rust 禁止模式

| 模式 | 替代方案 | 示例 |
|------|---------|------|
| `unwrap()` | `?` 或 `match` | `let x = foo()?;` |
| `expect()` | `?` 或 `match` | `let x = foo()?;` |
| `panic!()` | 返回 `Result` | `return Err(...)` |
| 直接修改 SQLite | 通过 Loro | `loro_doc.commit()` |
| `todo!()` | 完成实现 | 实现功能 |
| `unimplemented!()` | 完成实现 | 实现功能 |

---

## ✅ Rust 必须模式

| 要求 | 说明 | 示例 |
|------|------|------|
| `Result<T, Error>` | API 函数返回类型 | `pub fn foo() -> Result<(), Error>` |
| `#[derive(Debug)]` | 数据模型必须实现 | `#[derive(Debug, Clone)]` |
| `loro_doc.commit()` | Loro 修改后调用 | 修改后立即 commit |

---

## ❌ Dart 禁止模式

| 模式 | 替代方案 | 示例 |
|------|---------|------|
| `print()` | `debugPrint()` | `debugPrint('message')` |
| `// TODO:` | 完成或移除 | 实现功能 |
| `// FIXME:` | 完成或移除 | 修复问题 |

---

## ✅ Dart 必须模式

| 要求 | 说明 | 示例 |
|------|------|------|
| `{Key? key}` | Widget 构造函数 | `const MyWidget({Key? key})` |
| `if (!mounted) return` | 异步操作后检查 | 在 `setState` 前检查 |

---

## 🔧 验证命令

### Rust
```bash
cd rust && cargo check
cd rust && cargo clippy --all-targets --all-features -- -D warnings
cd rust && cargo test --all-features
```

### Dart
```bash
flutter analyze
flutter test
dart tool/check_lint.dart
```

---

## 📋 提交前检查清单

- [ ] 所有验证命令通过（0 错误，0 警告）
- [ ] 测试覆盖率 >80%（新代码）
- [ ] 没有绕过 Loro 直接写 SQLite
- [ ] 没有使用 unwrap()、expect()、panic!()
- [ ] 所有 API 函数返回 Result 类型
- [ ] 架构文档已更新（如果修改架构）
- [ ] Spec 文档已更新（如果修改 API）
- [ ] 没有提交 TODO/FIXME 注释

---

## 🎯 常见场景速查

### 场景 1: 修改 Rust 数据模型

```rust
// ✅ 正确
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MyModel {
    pub id: String,
    pub name: String,
}

impl MyModel {
    pub fn new(name: String) -> Result<Self, CardMindError> {
        if name.is_empty() {
            return Err(CardMindError::InvalidInput("name cannot be empty".into()));
        }

        Ok(Self {
            id: Uuid::now_v7().to_string(),
            name,
        })
    }
}
```

### 场景 2: 修改 Loro 数据

```rust
// ✅ 正确
pub fn update_card_title(card_id: &str, title: &str) -> Result<(), CardMindError> {
    // 1. 加载 Loro 文档
    let loro_doc = load_loro_doc(card_id)?;

    // 2. 修改数据
    let title_text = loro_doc.get_text("title");
    title_text.clear()?;
    title_text.insert(0, title)?;

    // 3. 提交变更（触发订阅）
    loro_doc.commit();

    // 4. 持久化
    save_loro_doc(&loro_doc, card_id)?;

    Ok(())
}
```

### 场景 3: Flutter 异步操作

```dart
// ✅ 正确
Future<void> loadData() async {
  setState(() => _isLoading = true);

  try {
    final data = await api.getData();

    if (!mounted) return;  // ✅ 检查 mounted

    setState(() {
      _data = data;
      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;  // ✅ 检查 mounted

    setState(() => _isLoading = false);
    debugPrint('Error: $e');  // ✅ 使用 debugPrint
  }
}
```

### 场景 4: 错误处理

```rust
// ❌ 错误
let value = some_function().unwrap();

// ✅ 正确 - 使用 ?
let value = some_function()?;

// ✅ 正确 - 使用 match
let value = match some_function() {
    Ok(v) => v,
    Err(e) => {
        error!("Failed: {:?}", e);
        return Err(e);
    }
};

// ✅ 正确 - 使用 ok_or
let value = some_option.ok_or_else(|| {
    CardMindError::NotFound("value not found".into())
})?;
```

---

## 📚 快速链接

| 资源 | 路径 |
|------|------|
| 主配置 | `project-guardian.toml` |
| 使用指南 | `.project-guardian/README.md` |
| 最佳实践 | `.project-guardian/best-practices.md` |
| 反模式 | `.project-guardian/anti-patterns.md` |
| 工作流示例 | `.project-guardian/workflow-examples.md` |
| 失败日志 | `.project-guardian/failures.log` |
| 验证脚本 | `tool/validate_constraints.dart` |

---

## 🆘 遇到问题？

1. **约束违规**: 查看 `.project-guardian/anti-patterns.md`
2. **不知道怎么写**: 查看 `.project-guardian/best-practices.md`
3. **工作流不清楚**: 查看 `.project-guardian/workflow-examples.md`
4. **配置问题**: 查看 `project-guardian.toml`
5. **历史违规**: 查看 `.project-guardian/failures.log`

---

## 💡 记住这些原则

1. **Loro 优先**: 所有数据写入通过 Loro，SQLite 只读
2. **错误传播**: 使用 `?` 而不是 `unwrap()`
3. **类型安全**: API 函数返回 `Result<T, Error>`
4. **测试优先**: 先写测试再写实现（TDD）
5. **文档同步**: 修改 API 时更新 Spec 文档

---

## 🎯 一句话总结

**在编写代码前，先想想 Project Guardian 会怎么检查它。**

---

*打印此页，贴在显示器旁边！*

*最后更新: 2026-01-16*
