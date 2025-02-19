为了实现卡片笔记项目的多端数据同步，可以采用以下分步方案：

### 一、架构升级（核心思路）
1. **引入中央服务器**
   - 将现有Rust后端改造为中央同步服务器
   - 数据库迁移至PostgreSQL（更适合并发写入）
   - 保留SQLite作为各客户端的本地缓存

2. **数据模型改造**
   ```rust
   // 增加同步元字段
   struct Note {
       id: String,
       content: String,
       created_at: DateTime<Utc>,
       updated_at: DateTime<Utc>,  // 关键同步字段
       sync_version: i64,         // 乐观锁版本控制
       device_id: String,         // 最后修改设备标识
   }
   ```

### 二、同步协议设计
1. **增量同步接口**
   ```rust
   // 请求体
   #[derive(Deserialize)]
   struct SyncRequest {
       last_sync: DateTime<Utc>,
       changes: Vec<Note>
   }

   // 响应体
   #[derive(Serialize)]
   struct SyncResponse {
       server_time: DateTime<Utc>,
       changes: Vec<Note>,
       conflicts: Vec<Note>
   }
   ```

2. 同步流程：
   ```
   客户端 -> 服务器：
   1. 上传last_sync时间点后的本地修改
   2. 拉取该时间点后的服务端修改
   
   服务器：
   1. 合并客户端提交的修改（使用冲突解决策略）
   2. 返回需要客户端应用的修改
   ```

### 三、客户端实现

#### Electron桌面端
1. **本地存储**
   ```javascript
   // 使用better-sqlite3
   const db = require('better-sqlite3')('notes.db');
   db.pragma('journal_mode = WAL');

   // 初始化表
   db.exec(`
       CREATE TABLE IF NOT EXISTS notes (
           id TEXT PRIMARY KEY,
           content TEXT,
           updated_at DATETIME,
           sync_version INTEGER DEFAULT 0
       )`);
   ```

2. **同步触发器**
   ```typescript
   // 网络状态监听
   window.addEventListener('online', syncWithServer);

   // 定时同步（每5分钟）
   setInterval(syncWithServer, 300_000);

   // 显式同步按钮
   syncButton.addEventListener('click', syncWithServer);
   ```

#### React Native移动端
1. **本地存储配置**
   ```bash
   yarn add react-native-sqlite-storage
   npx pod-install
   ```

2. **数据同步组件**
   ```typescript
   useEffect(() => {
       const unsubscribe = NetInfo.addEventListener(state => {
           if (state.isConnected) syncLocalChanges();
       });
       return () => unsubscribe();
   }, []);
   ```

### 四、冲突解决策略
采用改进的"最后写入获胜"策略：
1. 优先比较`sync_version`字段
2. 版本相同则比较`updated_at`时间戳
3. 仍无法解决时保留两个版本供用户选择

冲突解决示例：
```rust
fn resolve_conflict(local: Note, remote: Note) -> Note {
    match local.sync_version.cmp(&remote.sync_version) {
        Ordering::Greater => local,
        Ordering::Less => remote,
        Ordering::Equal => {
            if local.updated_at > remote.updated_at {
                local
            } else {
                remote
            }
        }
    }
}
```

### 五、性能优化措施
1. **二进制增量传输**
   - 使用Protocol Buffers替代JSON
   ```toml
   # Cargo.toml
   [dependencies]
   prost = "0.11"
   tonic = "0.8"
   ```

2. **客户端数据分页**
   ```rust
   #[derive(Deserialize)]
   struct SyncRequest {
       last_sync: DateTime<Utc>,
       page_size: usize,
       page_token: Option<String>
   }
   ```

3. **本地数据库索引优化**
   ```sql
   CREATE INDEX idx_notes_updated ON notes (updated_at);
   CREATE INDEX idx_notes_sync ON notes (sync_version);
   ```

### 六、安全方案
1. 数据加密
   ```rust
   // 服务器端加密存储
   fn encrypt_data(content: &str) -> Result<String> {
       let key = ring::hkdf::Salt::new(ring::hkdf::HKDF_SHA256, b"salt");
       let prk = key.extract(b"secret");
       let okm = prk.expand(b"encrypt", 32)?;
       // 实际加密逻辑...
   }
   ```

2. 传输安全
   ```bash
   # 使用Let's Encrypt证书
   sudo apt install certbot
   sudo certbot certonly --standalone -d yourdomain.com
   ```

### 七、监控体系
1. 同步指标埋点
   ```rust
   #[derive(Serialize)]
   struct SyncMetrics {
       sync_duration: Duration,
       uploaded_count: usize,
       downloaded_count: usize,
       conflict_count: usize
   }

   // 上报到Prometheus
   metrics_register!("sync_operation", "Sync operation metrics");
   ```

2. 异常预警
   ```bash
   # 使用Sentry进行错误跟踪
   sentry-cli releases new v1.0.0
   sentry-cli releases finalize v1.0.0
   ```

### 八、部署方案
推荐使用容器化部署：
```dockerfile
# Dockerfile
FROM rust:1.65 as builder
WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bullseye-slim
COPY --from=builder /app/target/release/sync-server .
COPY config.toml /etc/sync-server/
CMD ["./sync-server", "--config", "/etc/sync-server/config.toml"]
```

```bash
# 部署命令
docker build -t note-sync .
docker run -d -p 443:443 -v ./data:/var/lib/postgresql note-sync
```

### 九、测试策略
1. 同步一致性测试
   ```python
   # pytest
   def test_sync_consistency():
       client1 = NoteClient()
       client2 = NoteClient()
       
       # 初始同步
       client1.add_note("Test")
       client1.sync()
       client2.sync()
       
       # 离线修改
       client1.network = False
       client2.network = False
       client1.edit_note(0, "Client1")
       client2.edit_note(0, "Client2")
       
       # 恢复同步
       client1.sync()
       client2.sync()
       
       assert client1.get_note(0) == client2.get_note(0)
   ```

2. 性能压测
   ```bash
   # 使用wrk进行压力测试
   wrk -t12 -c400 -d30s https://sync-server/api/sync
   ```

该方案通过中央服务器协调各端数据，在保证离线可用的同时实现最终一致性。实际实施时建议：
1. 先实现基础同步功能
2. 逐步添加冲突解决策略
3. 最后完善监控和安全功能
4. 使用Canary Release进行渐进式发布

对于初期版本，可先实现Electron端的同步，验证方案可行后再扩展到React Native移动端。