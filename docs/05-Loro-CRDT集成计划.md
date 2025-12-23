# Loro CRDT 集成实施计划（文件系统方案）

**创建时间**：2025-12-23
**更新时间**：2025-12-23（采用文件系统存储方案）
**优先级**：🔴 P0（核心功能）
**预计工作量**：4-6 小时
**当前状态**：架构设计已更新，采用官方推荐的文件系统存储方案

---

## 📋 新架构设计：文件系统存储方案

### 架构变更说明

**原方案**（已废弃）：
- Loro 文档存储在 SQLite 的 `loro_doc BLOB` 字段
- 每次更新都需要读取、修改、写入整个 BLOB

**新方案**（官方推荐）：
```
系统数据目录/
├── db/
│   └── cardmind.db          # SQLite数据库（仅存元数据）
└── loro/
    ├── <base64_uuid_1>/
    │   ├── snapshot.loro    # 快照文件（完整状态）
    │   └── updates.loro     # 增量更新文件
    ├── <base64_uuid_2>/
    │   ├── snapshot.loro
    │   └── updates.loro
    └── ...
```

**优势**：
- ✅ 追加写入性能极高（每次编辑只需追加几KB）
- ✅ 避免SQLite BLOB的读写开销
- ✅ 易于备份和同步单个笔记
- ✅ 支持增量传输（P2P时只传updates文件）
- ✅ Loro官方推荐做法

---

## 📋 已完成的准备工作

### 1. ✅ 添加 Loro 依赖
**文件**：`rust/Cargo.toml`
```toml
# CRDT - Loro for conflict-free replicated data types
loro = "1.0"
```

### 2. ⚠️ CRDT 管理模块（需重新实现）
**文件**：`rust/src/crdt/mod.rs`（当前375行，基于BLOB方案）

**需要重新设计为文件系统方案**：

```rust
pub struct CrdtManager {
    // Loro 数据根目录
    loro_root: PathBuf,

    // 内存中的活跃文档（用于快速访问）
    active_docs: Arc<RwLock<HashMap<Uuid, Arc<LoroDoc>>>>,

    // 更新文件大小阈值（字节，默认10MB）
    update_threshold: usize,
}
```

**核心方法**：
- `new(loro_root: PathBuf)` - 初始化管理器
- `get_card_dir(uuid)` → `loro_root/base64(uuid)/`
- `load_card_doc(uuid)` → 加载 snapshot + updates
- `save_update(uuid, update_bytes)` → 追加到 updates.loro
- `merge_snapshot_if_needed(uuid)` → 检查并合并快照
- `get_update_file_size(uuid)` → 获取updates文件大小

---

## 🎯 待完成的集成任务

### 阶段1：存储层集成（2-3小时）

#### 任务 1.1：修改 Storage 结构体添加 CrdtManager
**文件**：`rust/src/storage/mod.rs`

**步骤**：
1. 在 `Storage` 结构体中添加 `crdt_manager` 字段：
   ```rust
   pub struct Storage {
       db: DatabaseConnection,
       crdt_manager: Arc<CrdtManager>,  // 新增
   }
   ```

2. 修改 `new()` 方法初始化 CrdtManager：
   ```rust
   pub async fn new(db_path: &str) -> Result<Self, DbErr> {
       // ... 现有数据库初始化代码 ...

       Ok(Self {
           db,
           crdt_manager: Arc::new(CrdtManager::new()),  // 新增
       })
   }
   ```

#### 任务 1.2：修改 create_card 集成 Loro
**文件**：`rust/src/storage/mod.rs:99-130`

**修改前**：
```rust
pub async fn create_card(&self, card: card::ActiveModel) -> Result<card::Model, DbErr> {
    let card_model = card.insert(&self.db).await?;
    Ok(card_model)
}
```

**修改后**：
```rust
pub async fn create_card(&self, card: card::ActiveModel) -> Result<card::Model, DbErr> {
    // 1. 获取卡片数据
    let id = card.id.clone().unwrap();
    let title = card.title.clone().unwrap();
    let content = card.content.clone().unwrap();

    // 2. 创建 Loro 文档
    let loro_bytes = self.crdt_manager
        .create_card_doc(id, &title, &content)
        .await
        .map_err(|e| DbErr::Custom(e))?;

    // 3. 更新 ActiveModel 的 loro_doc 字段
    let mut card_with_loro = card;
    card_with_loro.loro_doc = Set(loro_bytes);

    // 4. 插入数据库
    let card_model = card_with_loro.insert(&self.db).await?;

    Ok(card_model)
}
```

#### 任务 1.3：修改 update_card 集成 Loro
**文件**：`rust/src/storage/mod.rs:132-152`

**修改步骤**：
1. 从数据库加载现有卡片的 loro_doc
2. 使用 `crdt_manager.load_card_doc()` 加载文档到缓存
3. 使用 `crdt_manager.update_card_doc()` 更新文档
4. 将更新后的二进制数据写回 SQLite

#### 任务 1.4：修改 create_network 集成 Loro
**文件**：`rust/src/storage/mod.rs:211-240`

类似于 create_card 的处理方式。

#### 任务 1.5：修改 update_network 集成 Loro
**文件**：`rust/src/storage/mod.rs:270-298`

类似于 update_card 的处理方式。

#### 任务 1.6：添加文档加载方法
在应用启动时，需要从数据库加载所有 loro_doc 到缓存：

```rust
impl Storage {
    /// 从数据库加载所有 Loro 文档到缓存
    pub async fn load_all_loro_docs(&self) -> Result<(), String> {
        // 加载所有卡片的 Loro 文档
        let cards = self.get_cards().await?;
        for card in cards {
            if !card.loro_doc.is_empty() {
                self.crdt_manager.load_card_doc(card.id, &card.loro_doc).await?;
            }
        }

        // 加载所有网络的 Loro 文档
        let networks = self.get_networks().await?;
        for network in networks {
            if !network.loro_doc.is_empty() {
                self.crdt_manager.load_network_doc(network.id, &network.loro_doc).await?;
            }
        }

        Ok(())
    }
}
```

---

### 阶段2：API 层集成（1-2小时）

#### 任务 2.1：修改 API 服务初始化
**文件**：`rust/src/api/impl_.rs:20-41`

在 `ApiService::new()` 中调用 `storage.load_all_loro_docs()`：

```rust
pub async fn new(db_path: &str) -> Result<Self, String> {
    // ... 现有初始化代码 ...

    // 加载所有 Loro 文档到缓存
    storage.load_all_loro_docs().await?;

    Ok(Self {
        network,
        storage,
    })
}
```

#### 任务 2.2：验证所有写操作
确认所有创建和更新操作都通过 Storage 层，自动使用 Loro：
- ✅ create_card
- ✅ update_card
- ✅ create_network
- ✅ update_network

---

### 阶段3：P2P 同步集成（预留，待 libp2p 完成后）

这部分将在 libp2p 集成完成后实现。需要：

1. 当收到远程设备的 Loro 更新时：
   ```rust
   // 伪代码
   async fn on_receive_loro_update(card_id: Uuid, remote_bytes: Vec<u8>) {
       // 1. 合并 Loro 文档
       let merged_bytes = storage.crdt_manager
           .merge_card_docs(card_id, &remote_bytes)
           .await?;

       // 2. 从合并后的文档读取数据
       let (title, content) = storage.crdt_manager
           .read_card_from_doc(card_id)
           .await?;

       // 3. 更新 SQLite
       storage.update_card_from_loro(card_id, title, content, merged_bytes).await?;
   }
   ```

2. 当本地更新后广播给其他设备：
   ```rust
   // 在 update_card 完成后
   let loro_bytes = card_model.loro_doc;
   network.broadcast_loro_update(card_id, loro_bytes).await?;
   ```

---

### 阶段4：测试和验证（1小时）

#### 单元测试
**文件**：`rust/src/crdt/mod.rs`（已包含基础测试）

需要添加的测试：
1. ✅ test_create_and_read_card_doc - 已有
2. ✅ test_update_card_doc - 已有
3. 需添加：test_merge_conflicting_updates - 测试冲突合并
4. 需添加：test_network_doc_operations - 测试网络文档操作

#### 集成测试
**新建文件**：`rust/tests/loro_integration_test.rs`

测试内容：
1. 创建卡片后 loro_doc 字段不为空
2. 更新卡片后 loro_doc 正确更新
3. 从数据库重新加载后 Loro 文档可以正确恢复
4. 模拟两个设备的文档合并

---

## 📝 实施注意事项

### API 兼容性
当前使用的 Loro API 方法（需要验证是否与 Loro 1.0 兼容）：
- `LoroDoc::new()`
- `doc.set_peer_id()`
- `doc.get_map()`
- `map.insert()`
- `doc.commit()`
- `doc.export_snapshot()`
- `doc.import()`

**行动项**：在实施前需要查阅 Loro 1.0 的官方文档确认 API。

### 性能考虑
1. **缓存策略**：当前使用无限制的内存缓存，后续可能需要实现 LRU 缓存
2. **延迟加载**：只在需要时加载 Loro 文档，而不是启动时全部加载
3. **批量更新**：考虑批量提交 Loro 更新以减少序列化开销

### 错误处理
1. Loro 操作失败时的回滚策略
2. 文档损坏时的恢复机制
3. 合并冲突的处理策略

---

## 🔗 相关文档

- Loro 官方文档：https://loro.dev
- CRDT 理论：https://crdt.tech
- 项目架构设计：`docs/00-架构设计文档.md`
- 进度报告：`docs/04-修复进度/修复进度报告.md`

---

## ✅ 验收标准

完成 Loro 集成后，应满足以下条件：

1. ✅ 所有卡片和网络的 `loro_doc` 字段都有有效数据
2. ✅ 创建、更新操作正确生成和更新 Loro 文档
3. ✅ 应用重启后可以从 SQLite 恢复所有 Loro 文档
4. ✅ 单元测试全部通过
5. ✅ 集成测试验证 CRDT 合并功能正常
6. ✅ 代码编译无错误和警告

---

## 🎯 下一步行动

1. **验证 Loro API**：确认 Loro 1.0 的 API 与当前实现兼容
2. **完成存储层集成**：按照阶段1的步骤逐个完成
3. **API 层调整**：确保初始化时加载 Loro 文档
4. **编写测试**：验证基本功能正常
5. **集成 libp2p**：实现 P2P 同步（单独任务）

---

## 💡 备注

- 当前 CRDT 模块已创建完成，提供了完整的文档管理 API
- Loro 依赖已添加到项目中
- 主要工作是将 Loro 集成到现有的 Storage 和 API 层
- 建议先完成基础集成，P2P 同步可以在 libp2p 完成后再实现
