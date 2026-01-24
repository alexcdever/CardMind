# Spec Coding 实施指南

**版本**: 1.0.0
**最后更新**: 2026-01-23

---

## 什么是 Spec Coding

### 核心理念

> **Spec Coding = 测试即规格，规格即文档**

Spec Coding 是一种规格驱动的开发方法论，强调：

1. **测试是精确的行为规格** - 测试用例就是可执行的规格
2. **先定义行为，再实现代码** - 明确"应该做什么"
3. **规格可自动验证** - 通过测试保证实现符合规格
4. **知识沉淀** - 规格文档永远不会过时

### 与其他方法的对比

| 维度 | 传统开发 | TDD | Spec Coding |
|------|---------|-----|-------------|
| 顺序 | 代码 → 测试 | 测试 → 代码 → 重构 | 规格 → 测试 → 代码 |
| 关注点 | 让代码工作 | 让测试通过 | **明确期望行为** |
| 文档 | 分离，易过期 | 无或分离 | **测试即文档** |
| 可执行性 | ❌ | ✅ | ✅✅ (规格+测试) |

---

## 工作流程

### 核心循环

```
1. 编写规格文档
   ↓
   - 定义数据结构
   - 明确 API 前置/后置条件
   - 编写测试场景 (Given-When-Then)

2. 编写规格测试（可执行）
   ↓
   - 使用 it_should_xxx() 命名风格
   - 清晰的 Given/When/Then 结构

3. 编写实现代码
   ↓
   - 最小代码让测试通过
   - 遵循规格定义的约束

4. 验证与文档
   ↓
   - 运行测试
   - 生成 API 文档
   - 提交 PR
```

---

## 规格文档编写指南

### 文档结构

一个完整的规格文档应包含：

```markdown
# [功能名称] 规格

## 概述
简要描述功能的目的和范围

## 数据结构
定义核心数据类型和字段

## API 定义
列出所有公共接口及其签名

## 需求
### 需求：[需求名称]
系统应该 [行为描述]

#### 场景：[场景名称]
- **前置条件**：[初始状态]
- **操作**：[触发动作]
- **预期结果**：[期望状态]
- **并且**：[额外验证]

## 错误处理
定义所有错误码和错误场景

## 测试用例
列出对应的测试函数名称
```

### 编写原则

**1. 使用 SHALL 表达强制要求**

```markdown
✅ 好的写法：
系统应该（SHALL）在创建卡片时生成 UUID v7 格式的 ID

❌ 不好的写法：
系统可以生成 ID
```

**2. 场景使用 Given-When-Then 结构**

```markdown
#### 场景：创建卡片成功
- **前置条件**：设备已加入一个池
- **操作**：用户创建新卡片
- **预期结果**：卡片应被创建
- **并且**：卡片应属于已加入的池
- **并且**：卡片 ID 应为 UUID v7 格式
```

**3. 明确错误场景**

```markdown
#### 场景：未加入池时创建卡片失败
- **前置条件**：设备未加入任何池
- **操作**：用户尝试创建卡片
- **预期结果**：系统应返回错误
- **并且**：错误码应为 NO_POOL_JOINED
```

---

## 测试编写指南

### 命名规范

使用 `it_should_xxx()` 风格，清晰表达测试意图：

**Rust 示例**：
```rust
#[test]
fn it_should_create_card_in_joined_pool() {
    // Given: 设备已加入池
    let pool_id = create_pool("test_pool");
    join_pool(pool_id);

    // When: 创建卡片
    let result = create_card("test content");

    // Then: 卡片应被创建并属于该池
    assert!(result.is_ok());
    let card = result.unwrap();
    assert_eq!(card.pool_id, pool_id);
}

#[test]
fn it_should_reject_card_creation_without_joined_pool() {
    // Given: 设备未加入池
    // (无需额外设置)

    // When: 尝试创建卡片
    let result = create_card("test content");

    // Then: 应返回错误
    assert!(result.is_err());
    assert_eq!(result.unwrap_err().code, ErrorCode::NoPoolJoined);
}
```

**Flutter 示例**：
```dart
test('it should create card in joined pool', () async {
  // Given: 设备已加入池
  final poolId = await createPool('test_pool');
  await joinPool(poolId);

  // When: 创建卡片
  final result = await createCard('test content');

  // Then: 卡片应被创建并属于该池
  expect(result.isSuccess, true);
  expect(result.data.poolId, poolId);
});

test('it should reject card creation without joined pool', () async {
  // Given: 设备未加入池
  // (无需额外设置)

  // When: 尝试创建卡片
  final result = await createCard('test content');

  // Then: 应返回错误
  expect(result.isError, true);
  expect(result.error.code, ErrorCode.noPoolJoined);
});
```

### 测试结构

每个测试应该清晰分为三个部分：

```rust
#[test]
fn it_should_do_something() {
    // Given: 前置条件
    // 设置测试所需的初始状态

    // When: 操作
    // 执行被测试的功能

    // Then: 验证
    // 断言期望的结果
}
```

### 测试覆盖

确保覆盖以下场景：

1. **正常路径** - 功能按预期工作
2. **边界条件** - 空值、最大值、最小值
3. **错误场景** - 各种错误情况
4. **并发场景** - 多线程/异步操作（如适用）

---

## 实施代码指南

### 最小实现原则

只编写让测试通过的最小代码：

```rust
// ❌ 过度设计
pub fn create_card(content: String, tags: Vec<String>,
                   metadata: HashMap<String, String>) -> Result<Card> {
    // 规格中没有要求 tags 和 metadata
}

// ✅ 最小实现
pub fn create_card(content: String) -> Result<Card> {
    // 只实现规格要求的功能
}
```

### 遵循规格约束

实现必须严格遵循规格定义：

```rust
// 规格要求：卡片 ID 必须是 UUID v7 格式
pub fn create_card(content: String) -> Result<Card> {
    let id = Uuid::now_v7(); // ✅ 使用 UUID v7
    // let id = Uuid::new_v4(); // ❌ 违反规格

    Ok(Card { id, content })
}
```

### 错误处理

所有 API 必须返回 `Result<T, Error>`：

```rust
// ✅ 正确的错误处理
pub fn create_card(content: String) -> Result<Card, Error> {
    if !has_joined_pool() {
        return Err(Error::NoPoolJoined);
    }
    // ...
}

// ❌ 使用 panic
pub fn create_card(content: String) -> Card {
    if !has_joined_pool() {
        panic!("No pool joined"); // 不要这样做
    }
    // ...
}
```

---

## 验证与文档

### 运行测试

```bash
# Rust 测试
cd rust && cargo test

# Flutter 测试
flutter test

# 测试覆盖率
flutter test --coverage
```

### 测试通过标准

- ✅ 所有测试通过
- ✅ 测试覆盖率 > 80%
- ✅ 无编译警告
- ✅ `cargo clippy` 和 `flutter analyze` 零警告

### 文档生成

规格文档本身就是最好的文档，但也可以生成 API 文档：

```bash
# Rust API 文档
cargo doc --open

# Flutter API 文档
dart doc .
```

---

## 最佳实践

### 1. 规格先行

在写任何代码之前，先完成规格文档。这迫使你思考：
- 这个功能到底要做什么？
- 有哪些边界条件？
- 可能出现哪些错误？

### 2. 测试即规格

测试用例应该直接对应规格中的场景。如果规格中有 5 个场景，就应该有 5 个测试。

### 3. 保持同步

当需求变更时：
1. 先更新规格文档
2. 更新测试用例
3. 修改实现代码

### 4. 代码审查

PR 审查时，检查：
- 规格文档是否清晰完整
- 测试是否覆盖所有场景
- 实现是否符合规格约束

### 5. 持续重构

规格和测试保持不变，可以放心重构实现代码。只要测试通过，重构就是安全的。

---

## 常见问题

**Q: Spec Coding 和 TDD 有什么区别？**

A: TDD 关注"测试先行"，Spec Coding 关注"规格先行"。Spec Coding 多了一步：先写规格文档，明确期望行为，然后再写测试。

**Q: 规格文档会不会过时？**

A: 不会。因为规格文档直接对应测试用例，如果规格过时，测试就会失败。这迫使我们保持规格和代码同步。

**Q: 写规格文档会不会很慢？**

A: 前期会慢一些，但长期来看更快。清晰的规格减少了返工、bug 和沟通成本。

**Q: 所有功能都需要写规格吗？**

A: 核心功能和公共 API 必须写规格。内部工具函数可以只写测试。

**Q: 规格文档应该多详细？**

A: 详细到能让不熟悉代码的人理解功能行为。如果有疑问，就写详细一点。

---

## 相关文档

- [完整规格编写指南](./spec_writing_guide.md) - 包含模板、示例、最佳实践
- [目录结构约定](./directory_conventions.md)

---

**最后更新**: 2026-01-23
