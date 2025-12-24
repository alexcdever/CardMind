# API设计与实现规范

## 1. 文档说明

本文档定义了CardMind项目中Rust端API的设计原则和实现规范。开发者应严格遵循本规范编写代码，以确保代码质量和一致性。

**适用范围**：
- Rust端三层架构（Controller/Service/DAO）的所有代码
- Flutter端通过flutter_rust_bridge调用的所有API

**参考文档**：
- [架构设计文档](./架构设计文档.md) - 系统整体架构设计
- [需求文档](../01-需求/需求.md) - 产品需求和业务规则

---

## 2. API设计原则

### 2.1 命名规范

#### 2.1.1 函数命名
- 使用动词开头的snake_case命名
- CRUD操作统一使用：`create_`, `get_`, `update_`, `delete_`
- 查询列表使用复数：`get_cards()`, `get_spaces()`
- 单个查询使用单数：`get_card(id)`, `get_space(id)`

**示例**：
```rust
// ✅ 正确
pub async fn create_card(title: String, content: String) -> Result<Card>
pub async fn get_cards() -> Result<Vec<Card>>
pub async fn update_card(id: String, title: String) -> Result<Card>
pub async fn delete_card(id: String) -> Result<()>

// ❌ 错误
pub async fn CardCreate(title: String, content: String) -> Result<Card>
pub async fn getAllCards() -> Result<Vec<Card>>
```

#### 2.1.2 类型命名
- Entity：数据库实体，使用`Entity`后缀（如：`CardEntity`）
- Model：业务模型，不使用后缀（如：`Card`）
- Service：业务服务，使用`Service`后缀（如：`CardService`）
- DAO：数据访问对象，使用`Dao`后缀（如：`CardDao`）
- Error：错误类型，使用`Error`后缀（如：`ApiError`, `ServiceError`, `DaoError`）

#### 2.1.3 参数命名
- ID类型参数统一命名为`id`（不使用`card_id`、`cardId`等）
- 关联对象ID使用下划线连接：`space_id`, `device_id`
- 布尔参数使用`is_`前缀：`is_deleted`, `is_resident`

### 2.2 参数设计原则

1. **最小参数原则**：只传递必要参数，避免冗余
2. **类型明确性**：使用具体类型而非泛型（除非必要）
3. **可选参数**：使用`Option<T>`明确标识可选参数
4. **时间戳统一**：统一使用毫秒级时间戳（i64）

### 2.3 返回值设计原则

1. **统一使用Result**：所有API返回`Result<T, E>`类型
2. **错误类型分层**：每层定义自己的错误类型
3. **避免None语义模糊**：查询单个对象使用`Result<Option<T>>`明确表示"存在但找不到"

---

## 3. 三层架构实现规范

### 3.1 Controller层规范

#### 3.1.1 职责定义
- ✅ 通过`#[flutter_rust_bridge::frb]`暴露API
- ✅ 参数有效性验证（非空、格式校验等）
- ✅ 调用Service层处理业务逻辑
- ✅ 错误类型转换（ServiceError → ApiError）
- ❌ 不包含任何业务逻辑
- ❌ 不直接访问DAO层

#### 3.1.2 代码模板

```rust
// rust/src/api/card_controller.rs

use crate::service::card_service::CardService;
use crate::models::card::Card;
use crate::error::ApiError;
use std::sync::Arc;

/// 创建新卡片
///
/// # 参数
/// - title: 卡片标题
/// - content: 卡片内容
///
/// # 返回
/// - Ok(Card): 创建成功的卡片
/// - Err(ApiError): 创建失败的错误信息
#[flutter_rust_bridge::frb]
pub async fn create_card(
    title: String,
    content: String
) -> Result<Card, ApiError> {
    // 1. 参数验证
    if title.trim().is_empty() {
        return Err(ApiError::InvalidInput("标题不能为空".to_string()));
    }
    if content.trim().is_empty() {
        return Err(ApiError::InvalidInput("内容不能为空".to_string()));
    }

    // 2. 获取Service实例（通过依赖注入）
    let card_service = get_card_service();

    // 3. 调用Service层
    let card = card_service
        .create_card(title, content)
        .await
        .map_err(|e| ApiError::from(e))?;

    // 4. 返回结果
    Ok(card)
}

/// 获取卡片列表
#[flutter_rust_bridge::frb]
pub async fn get_cards() -> Result<Vec<Card>, ApiError> {
    let card_service = get_card_service();

    card_service
        .get_cards()
        .await
        .map_err(|e| ApiError::from(e))
}

/// 更新卡片
#[flutter_rust_bridge::frb]
pub async fn update_card(
    id: String,
    title: String,
    content: String
) -> Result<Card, ApiError> {
    // 参数验证
    if id.trim().is_empty() {
        return Err(ApiError::InvalidInput("卡片ID不能为空".to_string()));
    }

    let card_service = get_card_service();

    card_service
        .update_card(id, title, content)
        .await
        .map_err(|e| ApiError::from(e))
}

/// 软删除卡片
#[flutter_rust_bridge::frb]
pub async fn delete_card(id: String) -> Result<(), ApiError> {
    if id.trim().is_empty() {
        return Err(ApiError::InvalidInput("卡片ID不能为空".to_string()));
    }

    let card_service = get_card_service();

    card_service
        .soft_delete_card(id)
        .await
        .map_err(|e| ApiError::from(e))
}
```

#### 3.1.3 注意事项
- 所有API函数必须添加文档注释
- 参数验证失败返回`ApiError::InvalidInput`
- 使用`map_err`进行错误类型转换
- 不要在Controller层捕获错误并返回默认值

---

### 3.2 Service层规范

#### 3.2.1 职责定义
- ✅ 实现核心业务逻辑
- ✅ 协调多个DAO完成复杂操作
- ✅ 管理Loro文件系统操作
- ✅ 处理Subscribe机制触发
- ✅ 实现业务规则（如常驻空间、软删除）
- ✅ Service之间可以相互调用
- ❌ 不直接操作SQLite（通过DAO）
- ❌ 不包含参数验证逻辑（由Controller负责）

#### 3.2.2 代码模板

```rust
// rust/src/service/card_service.rs

use crate::dao::card_dao::CardDao;
use crate::dao::collaboration_space_dao::CollaborationSpaceDao;
use crate::loro_manager::LoroManager;
use crate::models::card::Card;
use crate::error::ServiceError;
use std::sync::Arc;
use uuid::Uuid;

pub struct CardService {
    card_dao: Arc<CardDao>,
    space_dao: Arc<CollaborationSpaceDao>,
    loro_manager: Arc<LoroManager>,
}

impl CardService {
    pub fn new(
        card_dao: Arc<CardDao>,
        space_dao: Arc<CollaborationSpaceDao>,
        loro_manager: Arc<LoroManager>
    ) -> Self {
        Self {
            card_dao,
            space_dao,
            loro_manager,
        }
    }

    /// 创建新卡片
    ///
    /// 业务规则：
    /// 1. 生成UUID v7作为卡片ID
    /// 2. 创建LoroDoc并保存到文件系统
    /// 3. 通过Subscribe自动同步到SQLite
    /// 4. 如果设置了常驻空间，自动加入所有常驻空间
    pub async fn create_card(
        &self,
        title: String,
        content: String
    ) -> Result<Card, ServiceError> {
        // 1. 生成UUID v7
        let card_id = Uuid::now_v7().to_string();

        // 2. 创建LoroDoc
        let loro_doc = self.loro_manager
            .create_card_doc(&card_id, &title, &content)
            .await?;

        // 3. 保存到文件系统
        self.loro_manager
            .save_doc(&card_id, &loro_doc)
            .await?;

        // 4. 查询常驻空间
        let resident_spaces = self.space_dao
            .find_resident_spaces()
            .await?;

        // 5. 自动加入常驻空间
        for space in resident_spaces {
            self.add_card_to_space_internal(&card_id, &space.id)
                .await?;
        }

        // 6. 从SQLite读取卡片（Subscribe已自动同步）
        let card = self.card_dao
            .find_by_id(&card_id)
            .await?
            .ok_or(ServiceError::NotFound("卡片创建失败".to_string()))?;

        Ok(card)
    }

    /// 获取所有未删除的卡片
    pub async fn get_cards(&self) -> Result<Vec<Card>, ServiceError> {
        self.card_dao
            .find_all_not_deleted()
            .await
            .map_err(|e| ServiceError::from(e))
    }

    /// 更新卡片
    pub async fn update_card(
        &self,
        id: String,
        title: String,
        content: String
    ) -> Result<Card, ServiceError> {
        // 1. 验证卡片存在
        let card = self.card_dao
            .find_by_id(&id)
            .await?
            .ok_or(ServiceError::NotFound("卡片不存在".to_string()))?;

        // 2. 加载LoroDoc
        let mut loro_doc = self.loro_manager
            .load_doc(&id)
            .await?;

        // 3. 更新LoroDoc
        self.loro_manager
            .update_card_doc(&mut loro_doc, &title, &content)
            .await?;

        // 4. 追加到updates.loro
        self.loro_manager
            .append_update(&id, &loro_doc)
            .await?;

        // 5. 从SQLite读取更新后的卡片（Subscribe已自动同步）
        let updated_card = self.card_dao
            .find_by_id(&id)
            .await?
            .ok_or(ServiceError::NotFound("卡片不存在".to_string()))?;

        Ok(updated_card)
    }

    /// 软删除卡片
    pub async fn soft_delete_card(&self, id: String) -> Result<(), ServiceError> {
        // 1. 验证卡片存在
        self.card_dao
            .find_by_id(&id)
            .await?
            .ok_or(ServiceError::NotFound("卡片不存在".to_string()))?;

        // 2. 加载LoroDoc
        let mut loro_doc = self.loro_manager
            .load_doc(&id)
            .await?;

        // 3. 设置删除标记
        self.loro_manager
            .set_deleted(&mut loro_doc, true)
            .await?;

        // 4. 追加更新
        self.loro_manager
            .append_update(&id, &loro_doc)
            .await?;

        // 5. 解除所有协作空间关联
        let spaces = self.space_dao
            .find_spaces_by_card(&id)
            .await?;

        for space in spaces {
            self.remove_card_from_space_internal(&id, &space.id)
                .await?;
        }

        Ok(())
    }

    /// 将卡片加入协作空间（内部方法）
    async fn add_card_to_space_internal(
        &self,
        card_id: &str,
        space_id: &str
    ) -> Result<(), ServiceError> {
        // 加载协作空间的LoroDoc
        let mut space_doc = self.loro_manager
            .load_doc(space_id)
            .await?;

        // 添加卡片ID到空间的卡片列表
        self.loro_manager
            .add_card_to_space(&mut space_doc, card_id)
            .await?;

        // 追加更新
        self.loro_manager
            .append_update(space_id, &space_doc)
            .await?;

        Ok(())
    }

    /// 从协作空间移除卡片（内部方法）
    async fn remove_card_from_space_internal(
        &self,
        card_id: &str,
        space_id: &str
    ) -> Result<(), ServiceError> {
        let mut space_doc = self.loro_manager
            .load_doc(space_id)
            .await?;

        self.loro_manager
            .remove_card_from_space(&mut space_doc, card_id)
            .await?;

        self.loro_manager
            .append_update(space_id, &space_doc)
            .await?;

        Ok(())
    }
}
```

#### 3.2.3 注意事项
- Service结构体必须包含所有依赖的DAO
- 使用`Arc`包装DAO实例以支持共享
- 复杂业务逻辑拆分为多个内部方法（`_internal`后缀）
- 所有数据库操作通过DAO完成
- 所有Loro操作通过LoroManager完成

---

### 3.3 DAO层规范

#### 3.3.1 职责定义
- ✅ SQLite数据库的CRUD操作
- ✅ Loro文件系统的读写操作
- ✅ 数据模型转换（Entity ↔ Model）
- ❌ 不包含任何业务逻辑
- ❌ 不调用其他DAO
- ❌ 不处理Subscribe机制（由LoroManager负责）

#### 3.3.2 代码模板

```rust
// rust/src/dao/card_dao.rs

use crate::entity::card_entity::CardEntity;
use crate::models::card::Card;
use crate::error::DaoError;
use sea_orm::{DatabaseConnection, EntityTrait, QueryFilter, ColumnTrait, QueryOrder};
use std::sync::Arc;

pub struct CardDao {
    db: Arc<DatabaseConnection>,
}

impl CardDao {
    pub fn new(db: Arc<DatabaseConnection>) -> Self {
        Self { db }
    }

    /// 插入新卡片
    pub async fn insert(&self, card: Card) -> Result<Card, DaoError> {
        let entity = CardEntity::from(card);

        let result = CardEntity::insert(entity.into_active_model())
            .exec(&*self.db)
            .await
            .map_err(|e| DaoError::DatabaseError(e.to_string()))?;

        self.find_by_id(&result.last_insert_id)
            .await?
            .ok_or(DaoError::NotFound("插入后查询失败".to_string()))
    }

    /// 更新卡片
    pub async fn update(&self, card: Card) -> Result<Card, DaoError> {
        let entity = CardEntity::from(card);

        CardEntity::update(entity.into_active_model())
            .exec(&*self.db)
            .await
            .map_err(|e| DaoError::DatabaseError(e.to_string()))?;

        self.find_by_id(&entity.id)
            .await?
            .ok_or(DaoError::NotFound("更新后查询失败".to_string()))
    }

    /// 根据ID查找卡片
    pub async fn find_by_id(&self, id: &str) -> Result<Option<Card>, DaoError> {
        let entity = CardEntity::find_by_id(id)
            .one(&*self.db)
            .await
            .map_err(|e| DaoError::DatabaseError(e.to_string()))?;

        Ok(entity.map(|e| Card::from(e)))
    }

    /// 查找所有未删除的卡片
    pub async fn find_all_not_deleted(&self) -> Result<Vec<Card>, DaoError> {
        let entities = CardEntity::find()
            .filter(card_entity::Column::IsDeleted.eq(false))
            .order_by_desc(card_entity::Column::UpdatedAt)
            .all(&*self.db)
            .await
            .map_err(|e| DaoError::DatabaseError(e.to_string()))?;

        Ok(entities.into_iter().map(|e| Card::from(e)).collect())
    }

    /// 删除卡片（物理删除，仅用于测试）
    #[cfg(test)]
    pub async fn delete(&self, id: &str) -> Result<(), DaoError> {
        CardEntity::delete_by_id(id)
            .exec(&*self.db)
            .await
            .map_err(|e| DaoError::DatabaseError(e.to_string()))?;

        Ok(())
    }
}
```

#### 3.3.3 注意事项
- DAO方法命名统一使用`find_`, `insert`, `update`, `delete`
- 所有数据库操作必须捕获并转换为DaoError
- 查询单个对象返回`Option<T>`
- 使用sea-orm的查询构建器而非原始SQL
- 物理删除方法仅用于测试（标注`#[cfg(test)]`）

---

## 4. 错误处理规范

### 4.1 错误类型定义

每层定义自己的错误类型，使用`thiserror`库简化错误定义。

```rust
// rust/src/error/api_error.rs
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ApiError {
    #[error("无效的输入参数: {0}")]
    InvalidInput(String),

    #[error("资源未找到: {0}")]
    NotFound(String),

    #[error("业务逻辑错误: {0}")]
    BusinessError(String),

    #[error("内部错误: {0}")]
    InternalError(String),
}

// 从ServiceError转换
impl From<ServiceError> for ApiError {
    fn from(err: ServiceError) -> Self {
        match err {
            ServiceError::NotFound(msg) => ApiError::NotFound(msg),
            ServiceError::ValidationError(msg) => ApiError::InvalidInput(msg),
            _ => ApiError::InternalError(err.to_string()),
        }
    }
}
```

```rust
// rust/src/error/service_error.rs
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ServiceError {
    #[error("资源未找到: {0}")]
    NotFound(String),

    #[error("验证失败: {0}")]
    ValidationError(String),

    #[error("Loro操作失败: {0}")]
    LoroError(String),

    #[error("数据访问失败: {0}")]
    DaoError(#[from] DaoError),
}
```

```rust
// rust/src/error/dao_error.rs
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DaoError {
    #[error("数据库错误: {0}")]
    DatabaseError(String),

    #[error("资源未找到: {0}")]
    NotFound(String),

    #[error("文件系统错误: {0}")]
    FileSystemError(String),
}
```

### 4.2 错误传播规则

1. **向上传播**：使用`?`操作符自动传播错误
2. **类型转换**：使用`map_err`或`From trait`进行错误类型转换
3. **错误上下文**：使用`.map_err(|e| Error::XXX(format!("操作失败: {}", e)))`添加上下文

---

## 5. 测试规范

### 5.1 单元测试

每个Service和DAO方法都应有对应的单元测试。

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_card() {
        // 准备测试数据
        let card_dao = Arc::new(MockCardDao::new());
        let loro_manager = Arc::new(MockLoroManager::new());
        let service = CardService::new(card_dao, loro_manager);

        // 执行测试
        let result = service.create_card(
            "测试标题".to_string(),
            "测试内容".to_string()
        ).await;

        // 验证结果
        assert!(result.is_ok());
        let card = result.unwrap();
        assert_eq!(card.title, "测试标题");
        assert_eq!(card.content, "测试内容");
        assert_eq!(card.is_deleted, false);
    }

    #[tokio::test]
    async fn test_create_card_with_empty_title() {
        // 测试空标题的情况
        // ...
    }
}
```

### 5.2 集成测试

```rust
// rust/tests/card_integration_test.rs

#[tokio::test]
async fn test_card_full_lifecycle() {
    // 1. 初始化测试环境
    let db = setup_test_database().await;

    // 2. 创建卡片
    let card = create_card("标题", "内容").await.unwrap();

    // 3. 查询卡片
    let fetched = get_card(&card.id).await.unwrap();
    assert_eq!(fetched.title, "标题");

    // 4. 更新卡片
    let updated = update_card(&card.id, "新标题", "新内容").await.unwrap();
    assert_eq!(updated.title, "新标题");

    // 5. 删除卡片
    delete_card(&card.id).await.unwrap();

    // 6. 验证软删除
    let cards = get_cards().await.unwrap();
    assert!(!cards.iter().any(|c| c.id == card.id));

    // 7. 清理测试数据
    cleanup_test_database(db).await;
}
```

### 5.3 测试覆盖率要求

- 单元测试覆盖率：≥80%
- 关键业务逻辑覆盖率：100%
- 错误处理路径覆盖率：≥90%

---

## 6. 完整示例：Card CRUD

以下是一个完整的Card CRUD实现示例，展示三层架构的协作。

### 6.1 Controller层

```rust
// rust/src/api/card_controller.rs
// 完整代码见 3.1.2 节
```

### 6.2 Service层

```rust
// rust/src/service/card_service.rs
// 完整代码见 3.2.2 节
```

### 6.3 DAO层

```rust
// rust/src/dao/card_dao.rs
// 完整代码见 3.3.2 节
```

### 6.4 调用流程图

```
Flutter
  ↓ 调用 create_card(title, content)
Controller (card_controller.rs)
  ↓ 1. 验证参数
  ↓ 2. 调用 CardService.create_card()
Service (card_service.rs)
  ↓ 1. 生成UUID v7
  ↓ 2. 创建LoroDoc
  ↓ 3. 保存到文件系统
  ↓ 4. 查询常驻空间
  ↓ 5. 自动加入常驻空间
  ↓ 6. 调用 CardDao.find_by_id()
DAO (card_dao.rs)
  ↓ 1. 从SQLite查询
  ↓ 2. Entity → Model转换
  ↑ 返回 Card
Service
  ↑ 返回 Card
Controller
  ↑ 错误转换 ServiceError → ApiError
Flutter
  ↑ 接收 Result<Card, ApiError>
```

---

## 7. 代码审查清单

在提交代码前，请确认以下检查项：

### 7.1 Controller层
- [ ] 所有API函数添加了`#[flutter_rust_bridge::frb]`注解
- [ ] 参数验证完整（非空、格式等）
- [ ] 使用了正确的错误类型（ApiError）
- [ ] 添加了完整的文档注释
- [ ] 不包含业务逻辑代码

### 7.2 Service层
- [ ] 所有业务规则已实现
- [ ] 通过DAO访问数据库（不直接使用sea-orm）
- [ ] 通过LoroManager操作Loro（不直接使用loro库）
- [ ] 复杂逻辑拆分为内部方法
- [ ] 添加了方法文档注释说明业务规则

### 7.3 DAO层
- [ ] 方法命名符合规范（find_/insert/update/delete）
- [ ] 所有数据库错误已捕获并转换为DaoError
- [ ] 查询单个对象返回Option<T>
- [ ] Entity与Model转换正确
- [ ] 物理删除方法标注了`#[cfg(test)]`

### 7.4 错误处理
- [ ] 每层使用了正确的错误类型
- [ ] 错误消息提供了足够的上下文
- [ ] 实现了From trait进行错误转换
- [ ] 不吞噬错误（不使用unwrap/expect）

### 7.5 测试
- [ ] 编写了单元测试
- [ ] 测试覆盖了正常流程
- [ ] 测试覆盖了异常流程
- [ ] 测试可以独立运行

---

## 8. 常见问题

### Q1: Controller层是否需要参数验证？
**A**: 是的。Controller层负责参数的基本验证（非空、格式等），Service层负责业务规则验证（如"卡片是否存在"、"是否有权限"等）。

### Q2: Service之间可以相互调用吗？
**A**: 可以。Service层允许相互调用以处理复杂业务逻辑，但要注意避免循环依赖。

### Q3: DAO层可以调用其他DAO吗？
**A**: 不可以。DAO层只负责单一数据模型的持久化操作，不应调用其他DAO。如需协调多个DAO，应在Service层完成。

### Q4: 什么时候使用物理删除？
**A**: 仅在测试清理时使用物理删除。生产代码统一使用软删除（设置is_deleted标记）。

### Q5: Subscribe机制在哪一层处理？
**A**: Subscribe机制由LoroManager统一管理，Service层调用LoroManager的方法，DAO层不直接处理Subscribe。

---

## 9. 参考资源

- [Rust异步编程](https://rust-lang.github.io/async-book/)
- [sea-orm文档](https://www.sea-ql.org/SeaORM/)
- [flutter_rust_bridge文档](https://cjycode.com/flutter_rust_bridge/)
- [thiserror文档](https://docs.rs/thiserror/)
- [Loro文档](https://loro.dev/docs)
