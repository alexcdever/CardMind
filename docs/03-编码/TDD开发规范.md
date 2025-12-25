# TDD开发规范

## 1. 文档说明

本文档定义了CardMind项目的测试驱动开发（Test-Driven Development, TDD）规范。**所有开发者必须遵循TDD原则进行开发**，以确保代码质量、可维护性和稳定性。

**适用范围**：
- 所有Rust后端代码（Controller/Service/DAO三层架构）
- Flutter前端业务逻辑代码
- 所有新功能开发和Bug修复

**TDD核心原则**：
> **测试先行，红绿重构** - 先写测试，后写实现，持续重构

---

## 2. TDD开发流程

### 2.1 红-绿-重构循环（Red-Green-Refactor）

TDD遵循严格的三步循环：

```
🔴 Red（红灯）→ 🟢 Green（绿灯）→ 🔵 Refactor（重构）
     ↑                                      ↓
     └──────────────────────────────────────┘
```

#### 步骤1：🔴 Red - 编写失败的测试

**目标**：明确需求，定义期望行为

```rust
#[tokio::test]
async fn test_create_card_should_succeed() {
    // Arrange：准备测试数据
    let service = setup_test_service().await;

    // Act：执行被测试的操作
    let result = service.create_card(
        "测试标题".to_string(),
        "测试内容".to_string()
    ).await;

    // Assert：验证期望结果
    assert!(result.is_ok());
    let card = result.unwrap();
    assert_eq!(card.title, "测试标题");
    assert_eq!(card.content, "测试内容");
    assert!(!card.is_deleted);
    assert!(card.created_at > 0);
}
```

**验证**：运行测试，确认失败（因为实现尚未编写）
```bash
cargo test test_create_card_should_succeed
# 预期输出：FAILED
```

#### 步骤2：🟢 Green - 编写最小实现使测试通过

**目标**：快速实现功能，使测试通过（不追求完美）

```rust
pub async fn create_card(
    &self,
    title: String,
    content: String
) -> Result<Card, ServiceError> {
    // 最简单的实现
    let card_id = Uuid::now_v7();
    let card = Card {
        id: card_id.to_string(),
        title,
        content,
        is_deleted: false,
        created_at: chrono::Utc::now().timestamp_millis(),
        updated_at: chrono::Utc::now().timestamp_millis(),
    };

    self.dao.insert(card.clone()).await?;
    Ok(card)
}
```

**验证**：再次运行测试，确认通过
```bash
cargo test test_create_card_should_succeed
# 预期输出：PASSED
```

#### 步骤3：🔵 Refactor - 重构代码

**目标**：在保持测试通过的前提下，优化代码质量

- 消除重复代码
- 改进命名
- 提取公共方法
- 优化性能
- 改善可读性

**验证**：重构后再次运行所有测试，确保没有破坏现有功能
```bash
cargo test
# 所有测试应该PASSED
```

### 2.2 开发工作流

每个功能的开发严格遵循以下流程：

```
1. 理解需求
   ↓
2. 编写测试用例（先写失败的测试）
   ↓
3. 运行测试（确认失败）
   ↓
4. 编写最小实现代码
   ↓
5. 运行测试（确认通过）
   ↓
6. 重构代码（保持测试通过）
   ↓
7. 提交代码（测试+实现）
```

**重要规则**：
- ❌ **禁止**先写实现再补测试
- ❌ **禁止**跳过测试直接写代码
- ❌ **禁止**提交未测试的代码
- ✅ **必须**先写测试再写实现
- ✅ **必须**确保所有测试通过才能提交

---

## 3. 测试分层策略

CardMind采用分层测试策略，不同层级使用不同类型的测试。

### 3.1 测试金字塔

```
          /\
         /  \        E2E测试（少量）
        /    \       - 完整用户流程
       /------\      - 跨设备同步场景
      /        \
     /          \    集成测试（适量）
    /            \   - 三层架构协作
   /--------------\  - Loro + SQLite集成
  /                \
 /                  \ 单元测试（大量）
/____________________\ - Service业务逻辑
                       - DAO数据访问
                       - Entity模型方法
```

### 3.2 单元测试（Unit Tests）

**目标**：测试单个函数/方法的行为

**范围**：
- Service层的业务逻辑方法
- DAO层的数据访问方法
- Entity的模型方法
- 工具函数和辅助方法

**特点**：
- 快速执行（<100ms/测试）
- 隔离外部依赖（使用Mock）
- 覆盖率目标：≥80%

**示例**：

```rust
// rust/src/service/card_service.rs

#[cfg(test)]
mod tests {
    use super::*;
    use mockall::predicate::*;
    use mockall::mock;

    // Mock DAO
    mock! {
        CardDao {}

        impl CardDao {
            async fn insert(&self, card: Card) -> Result<Card, DaoError>;
            async fn find_by_id(&self, id: &str) -> Result<Option<Card>, DaoError>;
        }
    }

    #[tokio::test]
    async fn test_create_card_success() {
        // Arrange
        let mut mock_dao = MockCardDao::new();
        mock_dao
            .expect_insert()
            .times(1)
            .returning(|card| Ok(card));

        let service = CardService::new(Arc::new(mock_dao));

        // Act
        let result = service.create_card(
            "标题".to_string(),
            "内容".to_string()
        ).await;

        // Assert
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_create_card_with_dao_error() {
        // 测试DAO层错误传播
        let mut mock_dao = MockCardDao::new();
        mock_dao
            .expect_insert()
            .times(1)
            .returning(|_| Err(DaoError::DatabaseError("连接失败".to_string())));

        let service = CardService::new(Arc::new(mock_dao));

        let result = service.create_card(
            "标题".to_string(),
            "内容".to_string()
        ).await;

        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), ServiceError::DaoError(_)));
    }
}
```

### 3.3 集成测试（Integration Tests）

**目标**：测试多个模块协作的行为

**范围**：
- Controller → Service → DAO完整调用链
- Loro CRDT + SQLite双存储集成
- Subscribe机制触发和同步
- 事务边界和错误回滚

**特点**：
- 使用真实数据库（测试环境）
- 测试完整业务流程
- 覆盖率目标：关键业务场景100%

**示例**：

```rust
// rust/tests/card_integration_test.rs

use cardmind::infrastructure::dependency_injection::AppContainer;
use cardmind::entity::card::Card;

async fn setup_test_container() -> AppContainer {
    // 使用临时目录初始化测试环境
    let temp_dir = tempfile::tempdir().unwrap();
    let db_path = temp_dir.path().join("test.db");
    AppContainer::new(db_path.to_str().unwrap()).await.unwrap()
}

#[tokio::test]
async fn test_card_full_lifecycle() {
    // Arrange：初始化测试容器
    let container = setup_test_container().await;
    let card_service = container.get_card_service();

    // Act & Assert：创建卡片
    let card = card_service
        .create_card("测试标题".to_string(), "测试内容".to_string())
        .await
        .expect("创建卡片失败");

    assert_eq!(card.title, "测试标题");
    assert!(!card.is_deleted);

    // Act & Assert：查询卡片
    let fetched_card = card_service
        .get_card_by_id(&card.id)
        .await
        .expect("查询卡片失败")
        .expect("卡片不存在");

    assert_eq!(fetched_card.id, card.id);

    // Act & Assert：更新卡片
    let updated_card = card_service
        .update_card(&card.id, "新标题".to_string(), "新内容".to_string())
        .await
        .expect("更新卡片失败");

    assert_eq!(updated_card.title, "新标题");

    // Act & Assert：软删除卡片
    card_service
        .soft_delete_card(&card.id)
        .await
        .expect("删除卡片失败");

    let all_cards = card_service
        .get_cards()
        .await
        .expect("查询卡片列表失败");

    assert!(!all_cards.iter().any(|c| c.id == card.id), "软删除的卡片不应出现在列表中");
}

#[tokio::test]
async fn test_resident_network_auto_association() {
    // 测试常驻网络自动关联功能
    let container = setup_test_container().await;
    let card_service = container.get_card_service();
    let network_service = container.get_network_service();

    // 创建常驻网络
    let resident_network = network_service
        .create_network("常驻网络".to_string(), true)
        .await
        .expect("创建网络失败");

    // 创建卡片，应自动加入常驻网络
    let card = card_service
        .create_card("新卡片".to_string(), "内容".to_string())
        .await
        .expect("创建卡片失败");

    // 验证卡片已加入常驻网络
    let networks = network_service
        .get_networks_by_card(&card.id)
        .await
        .expect("查询网络失败");

    assert!(
        networks.iter().any(|n| n.id == resident_network.id),
        "新卡片应自动加入常驻网络"
    );
}
```

### 3.4 端到端测试（E2E Tests）

**目标**：测试完整用户场景

**范围**：
- 跨设备同步场景
- 完整的卡片编辑流程
- 冲突解决场景

**特点**：
- 模拟真实用户操作
- 最慢但最接近生产环境
- 覆盖率目标：核心用户流程100%

**示例**：

```rust
// rust/tests/e2e_sync_test.rs

#[tokio::test]
async fn test_two_device_sync_without_conflict() {
    // 模拟设备A和设备B同步场景
    let device_a = setup_device("device_a").await;
    let device_b = setup_device("device_b").await;

    // 设备A创建卡片
    let card_on_a = device_a.card_service
        .create_card("标题A".to_string(), "内容A".to_string())
        .await
        .unwrap();

    // 模拟同步：导出设备A的更新
    let updates = device_a.sync_service
        .export_updates(&card_on_a.id)
        .await
        .unwrap();

    // 设备B导入更新
    device_b.sync_service
        .import_updates(&card_on_a.id, updates)
        .await
        .unwrap();

    // 验证设备B已同步卡片
    let card_on_b = device_b.card_service
        .get_card_by_id(&card_on_a.id)
        .await
        .unwrap()
        .expect("设备B应该有卡片");

    assert_eq!(card_on_b.title, "标题A");
    assert_eq!(card_on_b.content, "内容A");
}
```

---

## 4. 测试覆盖率要求

### 4.1 代码覆盖率标准

**强制要求**：

| 层级 | 最低覆盖率 | 目标覆盖率 |
|------|-----------|-----------|
| Service层 | 80% | 90% |
| DAO层 | 80% | 90% |
| Controller层 | 70% | 85% |
| 关键业务逻辑 | 100% | 100% |
| 错误处理路径 | 90% | 95% |

**关键业务逻辑包括**：
- 常驻网络自动关联
- 软删除机制
- Loro与SQLite同步
- CRDT冲突解决
- 设备注册和健康检查

### 4.2 覆盖率检查命令

```bash
# 安装tarpaulin（覆盖率工具）
cargo install cargo-tarpaulin

# 运行覆盖率检查
cargo tarpaulin --out Html --output-dir coverage

# 查看报告
open coverage/index.html
```

### 4.3 CI/CD集成

每次Pull Request必须包含覆盖率报告，未达标的PR将被拒绝合并。

```yaml
# .github/workflows/test.yml
name: Test Coverage

on: [pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run tests with coverage
        run: |
          cargo tarpaulin --out Xml
      - name: Upload to Codecov
        uses: codecov/codecov-action@v2
      - name: Check coverage threshold
        run: |
          # 如果覆盖率低于80%则失败
          if [ $(grep -oP 'line-rate="\K[^"]+' cobertura.xml | awk '{sum+=$1} END {print sum/NR*100}') -lt 80 ]; then
            echo "Coverage below 80%"
            exit 1
          fi
```

---

## 5. 测试命名规范

### 5.1 命名模式

测试函数命名遵循：`test_<方法名>_<场景>_<期望结果>`

**示例**：

```rust
#[tokio::test]
async fn test_create_card_with_valid_input_should_succeed() { }

#[tokio::test]
async fn test_create_card_with_empty_title_should_fail() { }

#[tokio::test]
async fn test_update_card_with_nonexistent_id_should_return_not_found() { }

#[tokio::test]
async fn test_soft_delete_card_should_mark_as_deleted_and_remove_from_networks() { }
```

### 5.2 Given-When-Then模式

测试代码结构使用Given-When-Then（或Arrange-Act-Assert）模式：

```rust
#[tokio::test]
async fn test_create_card_in_resident_network() {
    // Given（Arrange）：准备测试环境和数据
    let container = setup_test_container().await;
    let network_service = container.get_network_service();
    let card_service = container.get_card_service();

    let resident_network = network_service
        .create_network("常驻网络".to_string(), true)
        .await
        .unwrap();

    // When（Act）：执行被测试的操作
    let card = card_service
        .create_card("测试卡片".to_string(), "内容".to_string())
        .await
        .unwrap();

    // Then（Assert）：验证期望结果
    let networks = network_service
        .get_networks_by_card(&card.id)
        .await
        .unwrap();

    assert_eq!(networks.len(), 1);
    assert_eq!(networks[0].id, resident_network.id);
}
```

---

## 6. Mock和Stub策略

### 6.1 使用mockall进行Mock

对于外部依赖（如DAO、第三方服务），使用Mock隔离测试：

```rust
use mockall::{automock, predicate::*};

#[automock]
pub trait CardDao {
    async fn insert(&self, card: Card) -> Result<Card, DaoError>;
    async fn find_by_id(&self, id: &str) -> Result<Option<Card>, DaoError>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_with_mock_dao() {
        let mut mock = MockCardDao::new();

        // 设置期望：insert方法应被调用1次
        mock.expect_insert()
            .times(1)
            .returning(|card| Ok(card));

        // 使用mock进行测试
        let service = CardService::new(Arc::new(mock));
        let result = service.create_card("标题".to_string(), "内容".to_string()).await;

        assert!(result.is_ok());
    }
}
```

### 6.2 何时使用Mock vs 真实对象

| 场景 | 使用Mock | 使用真实对象 |
|------|---------|------------|
| 单元测试Service | ✅ Mock DAO | ❌ |
| 单元测试DAO | ❌ | ✅ 真实数据库（in-memory） |
| 集成测试 | ❌ | ✅ 真实对象 |
| 测试外部API | ✅ Mock HTTP客户端 | ❌ |
| 测试文件系统 | 视情况 | ✅ 临时目录 |

---

## 7. 测试数据管理

### 7.1 测试数据隔离

每个测试使用独立的数据环境，避免测试间相互影响：

```rust
async fn setup_test_container() -> AppContainer {
    let temp_dir = tempfile::tempdir().unwrap();
    let db_path = temp_dir.path().join("test.db");
    let loro_path = temp_dir.path().join("loro");

    AppContainer::new(db_path.to_str().unwrap())
        .with_loro_path(loro_path.to_str().unwrap())
        .await
        .unwrap()
}

#[tokio::test]
async fn test_example() {
    let container = setup_test_container().await;
    // 每个测试有独立的临时数据库和Loro目录
    // 测试结束后自动清理
}
```

### 7.2 测试数据工厂（Test Fixtures）

创建统一的测试数据工厂，避免重复代码：

```rust
// rust/tests/fixtures/mod.rs

pub struct TestFixtures;

impl TestFixtures {
    pub fn create_test_card(title: &str) -> Card {
        Card {
            id: Uuid::now_v7().to_string(),
            title: title.to_string(),
            content: format!("测试内容：{}", title),
            is_deleted: false,
            created_at: chrono::Utc::now().timestamp_millis(),
            updated_at: chrono::Utc::now().timestamp_millis(),
        }
    }

    pub fn create_test_network(name: &str, is_resident: bool) -> Network {
        Network {
            id: Uuid::now_v7().to_string(),
            name: name.to_string(),
            is_resident,
            created_at: chrono::Utc::now().timestamp_millis(),
            updated_at: chrono::Utc::now().timestamp_millis(),
        }
    }
}
```

---

## 8. 异常和边界测试

### 8.1 必须测试的异常场景

每个功能必须包含以下异常测试：

- ✅ 空输入测试
- ✅ 无效格式测试
- ✅ 资源不存在测试
- ✅ 权限不足测试
- ✅ 数据库错误测试
- ✅ 网络错误测试
- ✅ 并发冲突测试

**示例**：

```rust
#[tokio::test]
async fn test_create_card_with_empty_title_should_fail() {
    let service = setup_test_service().await;

    let result = service.create_card("".to_string(), "内容".to_string()).await;

    assert!(result.is_err());
    assert!(matches!(result.unwrap_err(), ServiceError::ValidationError(_)));
}

#[tokio::test]
async fn test_update_nonexistent_card_should_return_not_found() {
    let service = setup_test_service().await;

    let result = service.update_card(
        "nonexistent-id".to_string(),
        "标题".to_string(),
        "内容".to_string()
    ).await;

    assert!(result.is_err());
    assert!(matches!(result.unwrap_err(), ServiceError::NotFound(_)));
}

#[tokio::test]
async fn test_dao_database_connection_failure() {
    // 模拟数据库连接失败
    let mut mock_dao = MockCardDao::new();
    mock_dao
        .expect_insert()
        .returning(|_| Err(DaoError::DatabaseError("连接超时".to_string())));

    let service = CardService::new(Arc::new(mock_dao));
    let result = service.create_card("标题".to_string(), "内容".to_string()).await;

    assert!(result.is_err());
}
```

### 8.2 边界值测试

测试边界条件：

```rust
#[tokio::test]
async fn test_card_title_max_length() {
    let service = setup_test_service().await;

    // 测试边界：标题长度为256字符（假设限制为255）
    let long_title = "a".repeat(256);
    let result = service.create_card(long_title, "内容".to_string()).await;

    assert!(result.is_err());
}

#[tokio::test]
async fn test_card_title_exactly_max_length() {
    let service = setup_test_service().await;

    // 测试边界：标题长度正好255字符
    let title = "a".repeat(255);
    let result = service.create_card(title.clone(), "内容".to_string()).await;

    assert!(result.is_ok());
    assert_eq!(result.unwrap().title, title);
}
```

---

## 9. TDD最佳实践

### 9.1 测试应该具备的特性（FIRST原则）

- **Fast（快速）**：单元测试应在毫秒级完成
- **Independent（独立）**：测试间不能相互依赖
- **Repeatable（可重复）**：任何环境下都应得到相同结果
- **Self-Validating（自验证）**：测试结果应是明确的Pass/Fail
- **Timely（及时）**：测试应在实现之前编写

### 9.2 测试代码质量要求

测试代码与生产代码同等重要，应遵循相同的代码质量标准：

- ✅ 清晰的命名
- ✅ 避免重复代码（使用测试工具函数）
- ✅ 适当的注释说明测试意图
- ✅ 一个测试只验证一个行为
- ❌ 不要使用`unwrap()`，应使用`expect()`并提供错误消息

**示例**：

```rust
// ❌ 不好的测试
#[tokio::test]
async fn test_card() {
    let service = setup().await;
    let card = service.create_card("t".to_string(), "c".to_string()).await.unwrap();
    assert_eq!(card.title, "t");
    let updated = service.update_card(card.id, "new".to_string(), "c".to_string()).await.unwrap();
    assert_eq!(updated.title, "new");
    service.delete_card(card.id).await.unwrap();
}

// ✅ 好的测试
#[tokio::test]
async fn test_create_card_should_set_correct_title() {
    // Arrange
    let service = setup_test_service().await;
    let expected_title = "测试标题";

    // Act
    let result = service.create_card(
        expected_title.to_string(),
        "测试内容".to_string()
    ).await;

    // Assert
    let card = result.expect("创建卡片应该成功");
    assert_eq!(card.title, expected_title, "卡片标题应该与输入一致");
}
```

### 9.3 避免常见反模式

#### ❌ 反模式1：先写实现再补测试

```rust
// 错误做法：先写完整实现
pub async fn create_card(&self, title: String) -> Result<Card> {
    // 100行实现代码...
}

// 然后匆忙补一个测试
#[tokio::test]
async fn test_create_card() {
    // 简单测试，覆盖率低
}
```

#### ✅ 正确做法：小步前进

```rust
// 1. 先写测试
#[tokio::test]
async fn test_create_card_should_generate_uuid() {
    let card = service.create_card("标题".to_string()).await.unwrap();
    assert!(Uuid::parse_str(&card.id).is_ok());
}

// 2. 最小实现
pub async fn create_card(&self, title: String) -> Result<Card> {
    let id = Uuid::now_v7().to_string();
    Ok(Card { id, ..Default::default() })
}

// 3. 继续添加测试和实现...
```

#### ❌ 反模式2：测试过多实现细节

```rust
// 不好：测试内部实现
#[tokio::test]
async fn test_create_card_calls_dao_insert() {
    let mut mock = MockCardDao::new();
    mock.expect_insert()
        .with(predicate::function(|card: &Card| {
            // 测试过多内部细节
            card.id.len() == 36 &&
            card.created_at > 0 &&
            card.updated_at == card.created_at
        }))
        .returning(|c| Ok(c));
    // ...
}
```

#### ✅ 正确做法：测试行为而非实现

```rust
// 好：测试预期行为
#[tokio::test]
async fn test_create_card_returns_valid_card() {
    let service = setup_test_service().await;

    let card = service.create_card("标题".to_string(), "内容".to_string())
        .await
        .expect("创建应该成功");

    assert_eq!(card.title, "标题");
    assert!(!card.is_deleted);
    // 只验证公开契约，不关心内部实现
}
```

---

## 10. 持续集成和自动化

### 10.1 Pre-commit Hook

在提交前自动运行测试：

```bash
# .git/hooks/pre-commit

#!/bin/bash
echo "Running tests before commit..."

cargo test --quiet

if [ $? -ne 0 ]; then
    echo "❌ Tests failed! Commit aborted."
    exit 1
fi

echo "✅ All tests passed!"
exit 0
```

### 10.2 CI/CD Pipeline

```yaml
# .github/workflows/rust-ci.yml

name: Rust CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v2

    - name: Setup Rust
      uses: actions-rs/toolchain@v1
      with:
        toolchain: stable

    - name: Run tests
      run: cargo test --verbose

    - name: Check coverage
      run: |
        cargo install cargo-tarpaulin
        cargo tarpaulin --out Xml --output-dir ./coverage

    - name: Upload coverage
      uses: codecov/codecov-action@v2
      with:
        files: ./coverage/cobertura.xml
        fail_ci_if_error: true
```

---

## 11. 文档和知识传承

### 11.1 测试即文档

好的测试本身就是最好的文档：

```rust
/// 测试常驻网络的自动关联功能
///
/// 业务规则：当创建新卡片时，应自动加入所有标记为is_resident=true的网络
///
/// 验证步骤：
/// 1. 创建一个常驻网络
/// 2. 创建一张新卡片
/// 3. 验证卡片已自动加入常驻网络
#[tokio::test]
async fn test_new_card_auto_joins_resident_networks() {
    // 测试代码...
}
```

### 11.2 测试用例作为需求验收标准

每个需求的验收标准应转化为测试用例：

**需求**：卡片软删除功能
- AC1：软删除后卡片不出现在列表中
- AC2：软删除后卡片从所有网络中移除
- AC3：软删除的卡片可以恢复

**对应测试**：

```rust
#[tokio::test]
async fn test_soft_deleted_card_not_in_list() { /* AC1 */ }

#[tokio::test]
async fn test_soft_deleted_card_removed_from_networks() { /* AC2 */ }

#[tokio::test]
async fn test_restore_soft_deleted_card() { /* AC3 */ }
```

---

## 12. 常见问题

### Q1: 写测试太慢，影响开发效率怎么办？

**A**: TDD初期可能感觉慢，但长期来看会大幅提升效率：
- 减少调试时间（测试快速定位问题）
- 减少返工（先明确需求再实现）
- 减少回归bug（测试保护已有功能）
- 提升重构信心（测试覆盖保障）

**建议**：
1. 从简单功能开始练习TDD
2. 使用测试模板和工具函数减少重复
3. 团队结对编程互相学习

### Q2: 如何测试异步代码？

**A**: 使用`tokio::test`宏和`.await`：

```rust
#[tokio::test]
async fn test_async_function() {
    let result = async_function().await;
    assert!(result.is_ok());
}
```

### Q3: 如何测试Loro CRDT的同步逻辑？

**A**: 使用集成测试模拟多设备场景：

```rust
#[tokio::test]
async fn test_loro_sync() {
    let device_a = setup_device("a").await;
    let device_b = setup_device("b").await;

    // 设备A修改
    device_a.update_card(...).await;

    // 导出更新
    let updates = device_a.export_updates().await;

    // 设备B导入
    device_b.import_updates(updates).await;

    // 验证同步成功
    assert_eq!(device_a.get_card(), device_b.get_card());
}
```

### Q4: 测试覆盖率达不到要求怎么办？

**A**:
1. 运行`cargo tarpaulin --out Html`生成覆盖率报告
2. 查看报告中未覆盖的代码行
3. 补充测试用例覆盖缺失场景
4. 重点关注关键业务逻辑和错误处理路径

---

## 13. 资源和工具

### 13.1 推荐工具

- **cargo-tarpaulin**: 代码覆盖率工具
- **mockall**: Mock框架
- **tempfile**: 临时文件和目录
- **tokio-test**: 异步测试工具
- **criterion**: 性能基准测试

### 13.2 学习资源

- [Rust官方测试指南](https://doc.rust-lang.org/book/ch11-00-testing.html)
- [Test-Driven Development: By Example (Kent Beck)](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)
- [Growing Object-Oriented Software, Guided by Tests](https://www.amazon.com/Growing-Object-Oriented-Software-Guided-Tests/dp/0321503627)

---

## 14. 检查清单

在提交代码前，请确认：

- [ ] 所有新功能都先写了测试
- [ ] 所有测试都通过（`cargo test`）
- [ ] 代码覆盖率达标（≥80%）
- [ ] 测试命名清晰，遵循规范
- [ ] 测试使用AAA模式（Arrange-Act-Assert）
- [ ] 异常场景有对应测试
- [ ] 测试间相互独立，无依赖
- [ ] 没有被注释掉的测试代码
- [ ] 测试数据清理完整

---

**记住**：测试不是负担，而是对代码质量的投资。TDD让我们写出更好、更可维护的代码。
