# 第二阶段调研：局域网同步

> 2026-07-08 | 调研文档，非实施计划

---

## 目标

在 v2 本地体验确定可用后，增加**局域网设备发现 + 自动数据同步**。两个设备在同一 WiFi 网络下，无需手动配置即可发现对方并同步笔记。

---

## 技术方案评估

### 方案 A：Loro (CRDT) + iroh (P2P)

这是项目早期选型方向。

**Loro**（Rust CRDT 库）
- 核心价值：数据合并零冲突（CRDT 算法保证）
- 提供 `LoroDoc` → import/export 变更集 → 通过网络交换
- 支持文本协作编辑（富文本 LoroText）
- 5.8k GitHub stars，活跃维护（每日有 commit）
- 版本 1.x，API 已稳定

**iroh 1.0.2**（Rust P2P 网络库）
- 核心价值：QUIC 直连 + NAT 穿透
- `Endpoint` 模型：创建端点 → `connect(addr, alpn)` → 交换数据
- 中继服务器（Relay）辅助 NAT 穿透，但局域网场景可用直连地址
- SecretKey 身份认证，TLS 加密
- 不内置 mDNS，需要额外实现局域网发现

**组合使用方式**：
```
设备 A                         设备 B
│                              │
├─ LoroDoc (本地状态)          ├─ LoroDoc (本地状态)
├─ iroh Endpoint               ├─ iroh Endpoint
│                              │
└── mDNS 发现 ──────────────→  │
└── iroh.connect(addr) ──────→  │
└── Loro.exportFrom() ───────→  │
└── Loro.import() ←──────────   │
```

**复杂度评估**：
- Rust 端需要编写：mDNS 服务发现 + iroh 连接管理 + Loro 同步协议
- Flutter 端通过 flutter_rust_bridge (FRB) 调用 Rust API
- FRB 2.12 已在旧代码中配置过，可复用

### 方案 B：SQLite + 简单文件同步

直接在设备间同步 SQLite 数据库文件。

**优点**：实现极简，无需 CRDT
**缺点**：
- 冲突处理粗暴（谁后写谁覆盖）
- 无法做到部分更新
- 不适合之后的多用户扩展
- SQLite 文件不宜直接通过网络传输

**结论**：❌ 不推荐。与产品未来的扩展方向矛盾。

### 方案 C：纯自研同步协议

基于 WebSocket / HTTP，自定义同步协议。

**优点**：可控、可定制
**缺点**：
- 全部需要从头写，工作量大
- 仍然面临冲突解决问题
- 浪费已有成熟库的价值

**结论**：❌ 不推荐。除非 A 方案验证不可行。

---

## 方案 A 的关键问题及应对

### 1. 局域网设备发现（无 mDNS 怎么办）

| 方案 | 复杂度 | 可靠性 |
|------|--------|--------|
| mDNS (mdns-sd crate) | 低 | 高（标准协议） |
| 手动输入 IP | 零 | 低（用户体验差） |
| 预共享密钥 + 广播 | 中 | 中 |
| iroh 的 gossip/discovery | 需调研 | 未知 |

**建议**：优先用 Rust 的 `mdns-sd` crate 实现局域网发现。查到设备后，将 IP 传给 iroh 建立 QUIC 连接。

### 2. 数据同步模型

Loro 支持两种同步粒度的数据：

**a) 整个 LoroDoc 级别的同步**
- 每个设备维护一个 LoroDoc
- 通过 `exportFrom(theirVersion)` 获取增量变更
- 通过 `import(theirChanges)` 合并对方的变更
- 适合：整个笔记库作为一个文档

**b) 每个笔记一个 LoroDoc / LoroText**
- 粒度更细，可以只同步变化的笔记
- 管理多个文档更复杂

**建议**：先试验方案 b（按笔记粒度），因为它更轻量，只同步变化的笔记。

### 3. Flutter ↔ Rust 架构

```
Flutter (UI only)
  ├── 笔记列表渲染
  ├── Markdown 编辑器
  └── 网络状态显示
       │
       │ flutter_rust_bridge (FFI)
       │
Rust (后端)
  ├── SQLite (本地读模型，复用现有表结构)
  ├── Loro (CRDT 真源)
  ├── iroh (P2P 网络)
  └── mdns-sd (设备发现)
```

**关键设计决策**：Rust 端全权负责数据管理和同步，Flutter 只做 UI 渲染。与当前 v2（Flutter 直接操作 sqflite）不同，需要重构数据层。

### 数据真相源：Loro 为准，SQLite 只做读缓存

```
编辑器 ──写──→ LoroDoc（真源，唯一写入入口）
                │
                ├──→ 导出变更 → iroh → 对方设备
                │
                └──→ 投影 → SQLite（只读，供列表/搜索查询）
```

- **Loro 永远不读 SQLite。SQLite 永远不写 Loro。**
- 当两端同时修改同一笔记时，Loro 的 CRDT 算法保证合并结果确定且无冲突
- 如果在引入 Loro 前已有 SQLite 数据，启动时做一次性导入迁移。迁移完成后 Loro 接管所有写入

### 4. 最低可行版本应先验证什么

**验证 1：Rust 端 LoroDoc 基本操作**
```rust
// 创建、修改、导出、导入
let doc = LoroDoc::new();
doc.get_text("content").insert(0, "Hello").unwrap();
let snapshot = doc.export_snapshot(); // 全量快照
let changes = doc.export_from(&Default::default()); // 增量变更
```

**验证 2：iroh 局域网直连**
- 两个 Endpoint 在同一局域网，使用本地 IP 直连
- 验证 QUIC 连接建立 + 数据交换

**验证 3：mDNS 发现设备**
- 注册 `_cardmind._tcp` 服务
- 扫描并发现同一局域网的服务
- 将发现的 IP 交给 iroh 建立连接

**验证 4：端到端同步**
- 设备 A 创建笔记 → Loro 导出变更 → iroh 发送 → 设备 B 接收 → Loro 导入 → 列表刷新

---

## 风险与未知项

| 风险 | 等级 | 应对 |
|------|------|------|
| mDNS 在部分路由器/防火墙下不可用 | 中 | 提供手动输入 IP 的降级方案 |
| iroh QUIC 在严格防火墙下被阻断 | 中 | iroh 内置 fallback 到 relay |
| Loro 的 Rust API 学习曲线 | 低 | 文档完善，有丰富示例 |
| FRB 代码生成复杂度 | 中 | 旧代码已有 FRB 配置，可复用 |
| Flutter 端数据模型重构 | 中 | 需要从 sqflite 迁移到 Rust 后端 |

---

## 下一步建议

1. **先做验证 1**：在 Rust 端写一个最简 LoroDoc 读写 demo，确认 CRDT 机制可用
2. **再做验证 3**：用 `mdns-sd` 在局域网发现设备
3. **再做验证 2**：用 iroh 在两个进程间建立连接
4. **最后验证 4**：端到端同步演示

以上四个验证不涉及 Flutter 代码。全部通过后再写 Flutter ↔ Rust 的桥接层。

---

## 安全：设备白名单

### 问题

纯 mDNS 在公共 WiFi 下会暴露设备给任意人。需要准入控制。

### 方案：mDNS 发现 + 手动批准 + 信任传递

1. **mDNS 发现**设备在局域网内互相可见，但发现 ≠ 可连接
2. **手动批准**：首次发现陌生设备时弹出审批，批准后 NodeId 写入白名单
3. **信任传递**：白名单存储在 LoroDoc 中，随笔记数据一起同步

**效果**：
```
A 手动批准 B → A 的白名单: [B]
A 手动批准 C → A 的白名单: [B, C]
A 同步到 B → B 收到 A 的白名单 → B 也信任 C
A 同步到 C → C 收到 A 的白名单 → C 也信任 B
```

每台新设备只需与已信任的设备做一次配对，信任圈自动传递。

### 实现量评估

iroh **不内置**白名单功能，但提供了白名单所需的身份基础：

- `SecretKey` → 每台设备有唯一私钥
- `NodeId` → 从私钥派生的公钥 ID，不可伪造
- `endpoint.accept()` → 返回的 connection 带对端 NodeId

需要手写的代码量：

| 组件 | 语言 | 预估行数 |
|------|------|---------|
| 白名单存储（Loro 中的一个 List<[NodeId](https://docs.rs/iroh/1.0.2/iroh/struct.NodeId.html)> ） | Rust | ~10 |
| 连接准入检查（对端 NodeId 是否在白名单中） | Rust | ~5 |
| 审批弹窗（显示设备指纹，确认/拒绝） | Flutter | ~30 |
| 信任传递逻辑（白名单自动随笔记同步） | 不需要额外写 | 0 |

**结论：不算"一大片逻辑代码"。** iroh 的密钥身份 + Loro 的同步能力已经把大部分路铺好了。白名单本质上就是一个跟笔记一起同步的名单，外加一个连接时的 if 判断。
