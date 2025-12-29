# 常见问题解答 (FAQ)

本文档收集开发过程中的常见问题和解决方案。

---

## 📐 架构相关

### Q: 为什么要用Loro + SQLite双层架构？

**A**:
- **Loro CRDT**: 提供数据一致性、冲突自动解决、P2P同步能力
- **SQLite**: 提供快速查询、全文搜索、复杂筛选能力
- **各司其职**: Loro负责写入和同步，SQLite负责读取和查询

这种架构结合了CRDT的可靠性和SQL的查询性能。

---

### Q: 能否跳过Loro直接写SQLite？

**A**: **绝对不行！** 这会：
- ❌ 破坏数据一致性
- ❌ 导致P2P同步失败
- ❌ 丢失CRDT的冲突解决能力
- ❌ Loro和SQLite数据不同步

**正确做法**: 所有写操作 → Loro → commit() → 订阅自动更新SQLite

---

### Q: 为什么每个卡片是独立的LoroDoc？

**A**:
- ✅ **性能**: 小文档加载快，操作速度快
- ✅ **隔离性**: 每个卡片的版本历史独立，互不影响
- ✅ **P2P友好**: 可以按需同步单个卡片，减少流量
- ✅ **灵活性**: 便于实现卡片级别的权限控制（未来扩展）
- ✅ **文件管理**: 删除卡片只需删除对应目录

---

### Q: SQLite损坏了怎么办？

**A**: 不用担心！SQLite只是缓存，可以随时重建：

```rust
// 从Loro重建SQLite
pub fn rebuild_sqlite_from_loro(store: &CardStore) -> Result<()> {
    // 1. 删除旧数据库
    std::fs::remove_file(&store.sqlite_path)?;

    // 2. 重新初始化
    let conn = Connection::open(&store.sqlite_path)?;
    init_sqlite(&conn)?;

    // 3. 从Loro全量同步
    full_sync_from_loro(&conn, &store.loro_dir)?;

    Ok(())
}
```

**关键**: 只有Loro文件是关键数据，SQLite可以随时重建。

---

### Q: Loro订阅机制是怎么工作的？

**A**:

```rust
// 1. 设置订阅（应用启动时）
loro_doc.subscribe(
    &SubscribeOptions::default(),
    move |event| {
        // 每次commit()后会触发这个回调
        sync_to_sqlite(event);
    }
);

// 2. 修改数据时
card_map.insert("title", "新标题")?;
loro_doc.commit();  // ← 触发订阅回调

// 3. 订阅回调自动更新SQLite
fn sync_to_sqlite(event: &LoroEvent) {
    // 从event中提取变更
    // 更新SQLite
}
```

---

## 🛠️ 开发相关

### Q: 测试跑不过怎么办？

**A**: 按以下步骤排查：

1. **检查是否调用了commit()**
   ```rust
   // ❌ 错误：忘记commit
   card_map.insert("title", title)?;
   // SQLite不会更新！

   // ✅ 正确：调用commit
   card_map.insert("title", title)?;
   loro_doc.commit();  // 触发订阅
   ```

2. **检查SQLite表结构**
   ```bash
   sqlite3 cache.db
   .schema cards
   # 确认字段是否正确
   ```

3. **查看详细日志**
   ```bash
   RUST_LOG=debug cargo test
   ```

4. **检查测试数据是否隔离**
   ```rust
   // 每个测试使用独立的store
   let mut store = CardStore::new_in_memory().unwrap();
   ```

---

### Q: 如何调试Loro订阅机制？

**A**: 在订阅回调中添加日志：

```rust
loro_doc.subscribe(
    &SubscribeOptions::default(),
    move |event| {
        tracing::info!("订阅触发: {:?}", event);

        if let Err(e) = sync_to_sqlite(&conn, event) {
            tracing::error!("SQLite同步失败: {}", e);
        } else {
            tracing::info!("SQLite同步成功");
        }
    }
);
```

运行时查看日志：
```bash
RUST_LOG=info cargo test -- --nocapture
```

---

### Q: cargo build很慢怎么办？

**A**:

**方案1: 配置国内镜像（中国大陆用户）**

在 `~/.cargo/config.toml` 添加：
```toml
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "https://mirrors.ustc.edu.cn/crates.io-index"
```

**方案2: 使用增量编译**
```bash
# 只重新编译修改的部分
cargo build --release
```

**方案3: 使用sccache（缓存）**
```bash
cargo install sccache
export RUSTC_WRAPPER=sccache
```

---

### Q: flutter_rust_bridge生成失败？

**A**:

1. **确认安装**
   ```bash
   cargo install flutter_rust_bridge_codegen
   flutter_rust_bridge_codegen --version
   ```

2. **检查Rust代码**
   - 确保使用了 `#[flutter_rust_bridge::frb(sync)]` 注解
   - 参数类型必须是简单类型（String, i64, bool等）
   - 返回值必须是 `Result<T, E>`

3. **手动运行**
   ```bash
   # 使用Dart脚本
   dart tool/generate_bridge.dart
   ```

---

## 📦 数据相关

### Q: 数据存储在哪里？

**A**:

| 平台 | 路径 |
|------|------|
| **iOS** | `Library/Application Support/cardmind/` |
| **Android** | `data/data/com.cardmind.app/files/` |
| **Windows** | `%APPDATA%\cardmind\` |
| **macOS** | `~/Library/Application Support/cardmind/` |
| **Linux** | `~/.local/share/cardmind/` |

目录结构：
```
cardmind/
├── loro/
│   ├── <base64(uuid-1)>/
│   │   ├── snapshot.loro
│   │   └── update.loro
│   └── <base64(uuid-2)>/
│       └── ...
└── cache.db  # SQLite缓存
```

---

### Q: 如何备份数据？

**A**: 只需备份 `loro/` 目录：

```bash
# 压缩备份
tar -czf cardmind_backup_$(date +%Y%m%d).tar.gz loro/

# 恢复
tar -xzf cardmind_backup_20240101.tar.gz
# SQLite会自动从Loro重建
```

**重要**: 不需要备份 `cache.db`，它可以从Loro重建。

---

### Q: 如何查看Loro文件内容？

**A**: Loro是二进制格式，不能直接查看。可以通过代码读取：

```rust
// 加载并打印卡片内容
let doc = load_card_doc(card_id)?;
let card_map = doc.get_map("card");
println!("Title: {:?}", card_map.get("title"));
println!("Content: {:?}", card_map.get("content"));
```

---

## 🧪 测试相关

### Q: 如何提高测试速度？

**A**:

1. **使用内存数据库**
   ```rust
   Connection::open_in_memory()  // 而不是文件数据库
   ```

2. **并行运行测试**（默认）
   ```bash
   cargo test  # 自动并行
   ```

3. **只运行修改相关的测试**
   ```bash
   cargo test test_create_card  # 只运行特定测试
   ```

4. **跳过耗时测试**
   ```rust
   #[test]
   #[ignore]  // 默认跳过
   fn slow_integration_test() {
       // ...
   }

   // 需要时运行：cargo test -- --ignored
   ```

---

### Q: 如何查看测试覆盖率？

**A**:

```bash
# 1. 安装工具
cargo install cargo-tarpaulin

# 2. 生成覆盖率报告
cd rust
cargo tarpaulin --out Html

# 3. 查看报告
open tarpaulin-report.html  # macOS
start tarpaulin-report.html  # Windows
```

覆盖率必须 >80%，否则PR会被拒绝。

---

### Q: 测试之间互相影响怎么办？

**A**: 确保每个测试使用独立的数据：

```rust
// ❌ 错误：共享全局状态
static STORE: Mutex<CardStore> = ...;

#[test]
fn test_1() {
    let store = STORE.lock();  // 会互相影响
}

// ✅ 正确：每个测试独立创建
#[test]
fn test_1() {
    let mut store = CardStore::new_in_memory().unwrap();
    // 完全隔离
}
```

---

## 🔧 工具相关

### Q: 推荐使用什么IDE？

**A**:

**推荐**: Visual Studio Code
- 轻量级
- 插件丰富
- 同时支持Rust和Flutter
- 跨平台

**安装扩展**:
```bash
code --install-extension Dart-Code.flutter
code --install-extension rust-lang.rust-analyzer
```

**备选**: Android Studio / IntelliJ IDEA
- 功能更强大
- 但较重

---

### Q: 如何格式化代码？

**A**:

**Rust**:
```bash
cd rust
cargo fmt
```

**Flutter**:
```bash
dart format lib/
```

**自动格式化**（推荐）:
在VS Code的 `settings.json` 中：
```json
{
  "editor.formatOnSave": true
}
```

---

### Q: 如何运行静态检查？

**A**:

**Rust**:
```bash
cd rust
cargo clippy --all-targets --all-features
```

**Flutter**:
```bash
flutter analyze
```

**CI要求**: 两者都必须零警告才能合并PR。

---

## 🐛 错误处理

### Q: 遇到"Card not found"错误？

**A**:

1. **检查ID是否正确**
   ```rust
   // UUID必须完整且正确
   let id = "01234567-89ab-7def-0123-456789abcdef";
   ```

2. **检查卡片是否被软删除**
   ```sql
   SELECT * FROM cards WHERE id = 'xxx' AND is_deleted = 0;
   ```

3. **检查Loro文件是否存在**
   ```bash
   ls loro/<base64(uuid)>/
   ```

---

### Q: 编译错误：linker not found？

**A**:

**Windows**:
```powershell
# 安装 Visual Studio Build Tools
# https://visualstudio.microsoft.com/downloads/
# 选择 "Desktop development with C++"
```

**macOS**:
```bash
xcode-select --install
```

**Linux**:
```bash
sudo apt-get install build-essential  # Debian/Ubuntu
sudo dnf install gcc                   # Fedora
```

---

## 💡 最佳实践

### Q: 如何编写好的commit message？

**A**: 遵循项目规范：

```bash
# ✅ 好的commit
feat: 实现卡片创建API

- 添加create_card函数
- Loro订阅机制同步到SQLite
- 测试覆盖率82%

# ❌ 不好的commit
update code
修改了一些东西
fix bug
```

格式：`<type>: <subject>`

类型：`feat`, `fix`, `refactor`, `test`, `docs`, `chore`

---

### Q: 什么时候需要写日志？

**A**:

```rust
use tracing::{info, warn, error, debug};

// ✅ 需要记录
info!("创建卡片: id={}", id);           // 重要操作
error!("保存失败: {}", e);               // 错误
warn!("标题为空: id={}", id);            // 警告

// ⚠️ 谨慎记录
debug!("中间变量: {:?}", data);          // 仅开发时

// ❌ 不要记录
trace!("进入函数");                      // 过于详细
info!("循环第{}次", i);                  // 过于频繁
```

---

## 🚀 性能优化

### Q: 如何提升应用性能？

**A**:

1. **SQLite索引**
   ```sql
   CREATE INDEX idx_cards_created ON cards(created_at DESC);
   ```

2. **Loro定期compact**
   ```rust
   // 定期合并snapshot和update
   if update_size > threshold {
       merge_snapshot_and_updates()?;
   }
   ```

3. **Flutter列表虚拟化**
   ```dart
   ListView.builder(  // 而不是ListView
     itemCount: cards.length,
     itemBuilder: (context, index) => CardItem(cards[index]),
   )
   ```

4. **懒加载**
   - 只加载可见区域的数据
   - 图片按需加载

---

## 📞 获取帮助

### Q: 遇到问题去哪里求助？

**A**:

1. **查看文档**
   - [SETUP.md](SETUP.md) - 环境搭建
   - [ARCHITECTURE.md](ARCHITECTURE.md) - 架构设计
   - [TESTING_GUIDE.md](TESTING_GUIDE.md) - TDD指南

2. **搜索Issues**
   - 可能已有人遇到相同问题

3. **提交Issue**
   - 附上错误信息
   - 附上环境信息（`flutter doctor -v`）
   - 附上复现步骤

4. **提交PR**
   - 遵循Git工作流
   - 确保测试通过
   - 等待Code Review

---

## 🔄 更新日志

| 日期 | 版本 | 变更 |
|------|------|------|
| 2024-XX-XX | 1.0 | 初始版本 |

---

**还有其他问题？** 欢迎补充到这个文档！
