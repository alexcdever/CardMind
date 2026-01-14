# 数据契约 (Data Contract)

本文档定义 CardMind 各实体的数据契约,包括字段定义、类型约束和不变式。

**实现细节请查看源码**: 运行 `cargo doc --open` 查看自动生成的 Rust 数据结构文档。

---

## 1. 卡片数据契约

### 1.1 字段定义

| 字段 | 类型 | 约束 | 业务含义 |
|------|------|------|---------|
| `id` | UniqueIdentifier | 必填、全局唯一、时间有序 | 卡片唯一标识 |
| `title` | OptionalText | 可选、最大 256 字符 | 卡片标题 |
| `content` | MarkdownText | 必填、非空 | 卡片内容 (Markdown 格式) |
| `created_at` | Timestamp | 自动生成、不可修改 | 创建时间 (毫秒级) |
| `updated_at` | Timestamp | 自动更新 | 最后更新时间 (毫秒级) |
| `is_deleted` | Boolean | 默认 false | 软删除标记 |

**关系字段说明**:
- **Loro 真理源**: Card 文档仅包含卡片自身内容,不再持有池关系字段。
- **SQLite 缓存层**: 通过 `card_pool_bindings` 反向填充查询结果中的 `pool_id: Option<String>` 字段,单卡只会关联一个池。

### 1.2 类型说明

#### UniqueIdentifier

**要求**:
- 分布式环境下全局唯一,无需中心化协调
- 支持按创建时间排序
- 128 位长度
- 冲突概率极低 (< 10^-15)

**技术实现**: 由技术选型决定 (见 `TECH_CONSTRAINTS.md`)

**示例值**: `018c8f8e-1a2b-7c3d-9e4f-5a6b7c8d9e0f` (UUID v7 格式)

#### OptionalText

**格式**: UTF-8 编码字符串

**约束**:
- 可为空 (null 或空字符串)
- 最大长度: 256 字符 (Unicode 字符,非字节)
- 不包含控制字符 (如 `\0`)

**用途**: 卡片标题,辅助信息

#### MarkdownText

**格式**: 符合 CommonMark 规范的 Markdown 文本

**支持特性**:
- 标题 (H1-H6)
- 列表 (有序、无序)
- 代码块 (带语法高亮)
- 行内代码
- 引用块
- 链接
- 表格
- 加粗、斜体、删除线

**约束**:
- 不能为空字符串 (至少一个空格)
- 最大长度: 无限制 (由系统性能决定)

**用途**: 卡片主体内容

#### Timestamp

**格式**: Unix 时间戳 (毫秒级)

**精度**: 毫秒 (1/1000 秒)

**时区**: UTC

**示例值**: `1704067200000` (2024-01-01 00:00:00 UTC)

**约束**:
- 非负整数
- 范围: 1970-01-01 至 2262-04-11

### 1.3 不变式 (Invariants)

1. **创建时间不可修改**: `created_at` 在卡片创建后永不改变
2. **更新时间单调递增**: `updated_at >= created_at`
3. **软删除可查询**: `is_deleted = true` 的卡片不在默认查询结果中,但数据仍存在
4. **内容非空**: `content` 不能为空字符串
5. **池归属一致性**: 卡片的池归属由 Pool 文档中的 `card_ids` 决定,SQLite 绑定表必须与之保持一致

### 1.4 生命周期契约

```
创建: id 生成 → created_at = now() → updated_at = created_at → is_deleted = false
更新: 修改字段 → updated_at = now()
删除: is_deleted = true → updated_at = now()
恢复: is_deleted = false → updated_at = now()
永久删除: 物理删除 (文件系统和缓存层)
```

---

## 2. 数据池契约 (单池模型)

### 2.1 字段定义

| 字段 | 类型 | 约束 | 业务含义 |
|------|------|------|---------|
| `pool_id` | UniqueIdentifier | 必填、全局唯一 | 数据池唯一标识 |
| `name` | Text | 必填、最大 128 字符 | 数据池昵称 |
| `password_hash` | SecureHash | 必填、不可逆加密 | 密码哈希 (加密存储) |
| `members` | List\<Device\> | 至少 1 个成员 | 成员设备列表 |
| `card_ids` | List\<CardId\> | 默认空数组 | 池内所有卡片 ID 列表 (真理源) |
| `created_at` | Timestamp | 自动生成 | 创建时间 |
| `updated_at` | Timestamp | 自动更新 | 最后更新时间 |

### 2.2 类型说明

#### SecureHash

**格式**: bcrypt 加密哈希

**约束**:
- 使用 bcrypt 算法 (不可逆)
- 工作因子: 12 (平衡性能与安全)
- 盐值: 自动生成 (bcrypt 内置)

**示例值**: `$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYzPfUmIJ82`

**用途**: 数据池密码验证 (明文密码存储在系统 Keyring,不在此契约中)

#### Device

**结构**:
```
{
  "device_id": UniqueIdentifier,
  "device_name": Text,
  "joined_at": Timestamp
}
```

**约束**:
- `device_id` 全局唯一
- `device_name` 最大 64 字符，**可修改**，数据池特定（同一设备在不同数据池中可以有不同昵称）
- `joined_at` 加入数据池的时间,不可修改

**默认昵称生成规则**:
- 格式: `{设备型号}-{UUID前5位}`
- 示例: `iPhone-018c8`, `MacBook-7a3e1`
- 用途: 加入数据池时如果用户未自定义昵称，使用此规则即时生成

### 2.3 安全约束

#### 2.3.1 传输层安全

**TLS 强制加密**:
- 所有密码传输必须通过 libp2p TLS 加密
- 禁止明文连接（libp2p 配置强制）
- 加密算法: AES-256-GCM

**请求时效性**（防简单重放攻击）:
- 加入请求包含 Unix 毫秒时间戳
- 验证时效性: 5 分钟内有效
- 容忍时钟偏差: ±30 秒（可配置）

**JoinRequest 数据结构**:
```rust
struct JoinRequest {
    pool_id: String,
    password: Zeroizing<String>,  // 自动清零内存
    timestamp: u64,                // Unix 毫秒时间戳
}
```

#### 2.3.2 内存安全

**敏感数据清零**:
- 使用 `zeroize` crate 清除密码内存
- 密码类型: `Zeroizing<String>`（离开作用域自动清零）
- bcrypt 验证后立即清零

**日志安全**:
- 密码不出现在任何日志中
- Debug 输出时脱敏处理
- 错误信息不包含密码提示

#### 2.3.3 密码强度要求

**创建数据池时**:
- 最少长度: 8 位字符
- 建议复杂度: 包含字母、数字（可选，不强制）
- 前端验证 + 后端二次验证

**bcrypt 配置**:
- 工作因子: 12（平衡性能与安全）
- 盐值: 自动生成（bcrypt 内置）
- 哈希格式: `$2b$12$...`

#### 2.3.4 存储安全

1. **明文密码仅存储在系统安全存储中**: 使用 Keyring (不在 CRDT 或 SQLite 中)
2. **密码哈希使用不可逆算法**: bcrypt (不是 SHA256/MD5)
3. **密码修改同步**: 修改 `password_hash` 后通过 CRDT 同步到所有设备
4. **Keyring 密钥格式**: `cardmind.pool.<pool_id>.password`

### 2.4 权限与所有权模型

**当前设计**:
- 所有成员权限平等
- 一个用户 = 一个数据池 (对用户展示为"笔记空间")
- 池文档持有 `card_ids`,是卡片归属的唯一真理源

**未来扩展** (可选):
- 引入角色系统 (管理员/普通成员)
- 管理员可踢出成员
- 细粒度权限控制

---

## 3. 设备配置契约 (单池模型)

### 3.1 字段定义

**本地配置文件** (`/data/config.json`):

| 字段 | 类型 | 约束 | 业务含义 |
|------|------|------|---------|
| `device_id` | UniqueIdentifier | 必填、本设备唯一 | 设备唯一标识 |
| `pool_id` | Option\<PoolId\> | 单值,可为空 | 当前加入的唯一数据池 (笔记空间) |

**示例**:
```json
{
  "device_id": "018c8f8e-1a2b-7c3d-9e4f-5a6b7c8d9e0f",
  "pool_id": "pool-001"
}
```

**设计原则**:
- **单一归属**: 一个设备只能加入一个数据池,如需切换必须先退出
- **最小化存储**: 仅存储必要的索引信息,池详情从 Pool CRDT 读取
- **性能优化**: `pool_id` 用于快速启动,避免扫描文件系统

**注意**:
- 密码不存储在 `config.json` 中，存储在系统 Keyring
- 设备昵称不存储在本地配置中，仅存储在数据池 CRDT 的 `members` 列表中

### 3.2 密码存储契约

**平台映射**:

| 平台 | 安全存储机制 | Rust Crate |
|------|-------------|-----------|
| iOS | Keychain (硬件级加密) | `keyring` |
| Android | Keystore / EncryptedSharedPreferences | `keyring` |
| Windows | Credential Manager (DPAPI) | `keyring` |
| macOS | Keychain | `keyring` |
| Linux | Secret Service API (GNOME Keyring / KWallet) | `keyring` |

**密码存储键格式**:
```
cardmind.pool.<pool_id>.password
```

**安全保证**:
- 明文密码仅存在于内存中 (用户输入时)
- 密码存储受操作系统保护 (加密、权限控制)
- 应用卸载时自动清除密码

---

## 4. mDNS 广播数据契约 (单池模型)

### 4.1 广播内容 (非敏感信息)

```json
{
  "device_id": "device-001",
  "device_name": "MacBook-018c8",  // 默认昵称 (设备型号-UUID前5位)
  "pool_id": "pool-abc"            // 仅暴露唯一数据池 ID (未加入时可省略)
}
```

**说明**:
- `device_name` 使用即时生成的默认昵称,避免暴露数据池内昵称
- 单设备仅暴露单个 `pool_id`; 未初始化时可不带该字段
- mDNS 广播公开可见,信息保持最小化

**隐私保护策略**:
- ✅ **仅暴露 `pool_id`** (UUID): 未授权设备无法推断数据用途
- ❌ **不暴露 `pool_name`**: 防止泄露敏感业务信息
- ✅ **密码验证后获取**: 新设备需输入正确密码后才能从 Pool LoroDoc 获取 `pool_name` 等详细信息

### 4.2 不包含的敏感信息

**禁止广播**:
- ❌ 数据池名称 (`pool_name`)
- ❌ 密码或密码哈希
- ❌ 成员列表
- ❌ 卡片数量或内容
- ❌ 任何业务数据

**隐私保护**: 未授权设备无法通过 mDNS 获取数据池的任何实质性信息。

---

## 5. 卡片与数据池绑定契约 (单池模型)

### 5.1 绑定规则

**单向绑定**:
- 一个用户 = 一个数据池 (笔记空间)
- Pool 文档持有 `card_ids`,是卡片归属的唯一真理源
- 卡片通过订阅自动映射到 SQLite `card_pool_bindings` 表,查询结果填充 `pool_id`

### 5.2 绑定流程

```
create_card()
  → 读取 DeviceConfig.pool_id (必须已加入)
  → 将 card_id 写入 Pool.card_ids
  → pool_doc.commit() 触发订阅
  → 订阅回调重建 card_pool_bindings
  → SQLite 查询填充 Card.pool_id
```

### 5.3 移除与退出

- **移除卡片**: 从 `Pool.card_ids` 删除并 commit → 所有设备收到移除事件
- **退出数据池**: 清空本地卡片并删除 Pool 文档,`pool_id` 置空

### 5.4 约束

- 设备必须先加入数据池 (`pool_id` 存在) 才能创建/同步卡片
- 不存在多池/常驻池概念,也不支持一张卡片属于多个池

---

## 6. 数据完整性保证

### 6.1 引用完整性

**约束**:
- DeviceConfig.pool_id 必须存在于 Pool 文档集合中
- Pool.card_ids 必须与 SQLite `card_pool_bindings` 表保持一致 (由订阅自动维护)
- 退出数据池时必须删除本地 Pool 文档及其对应卡片数据,避免孤立绑定

### 6.2 时间戳一致性

**保证**:
- `created_at <= updated_at` (始终成立)
- `updated_at` 在每次修改时自动更新
- 时间戳使用 UTC,避免时区问题

### 6.3 软删除一致性

**保证**:
- 软删除的卡片 (`is_deleted = true`) 不出现在默认查询中
- 软删除的卡片可以恢复 (`is_deleted = false`)
- 物理删除不可逆 (删除 Loro 文件和 SQLite 记录)

---

## 7. 数据验证规则

### 7.1 创建卡片验证

**必需字段**:
- `content` 不能为空字符串

**可选字段**:
- `title` 可以为空

**自动生成**:
- `id` (UUID v7)
- `created_at` (当前时间)
- `updated_at` (当前时间)
- `is_deleted` (默认 false)

### 7.2 更新卡片验证

**可修改字段**:
- `title`
- `content`

**自动更新**:
- `updated_at` (当前时间)

**不可修改**:
- `id`
- `created_at`

### 7.3 笔记空间 (数据池) 验证

**创建笔记空间**:
- 启动时未加入任何池则自动引导创建
- `password` 明文长度至少 8 字符

**加入笔记空间**:
- 通过 mDNS 发现单个 `pool_id`
- `password` 必须匹配 `password_hash` (bcrypt 验证)

---

## 8. 相关文档

**架构层文档**:
- [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) - 系统设计原则
- [LAYER_SEPARATION.md](LAYER_SEPARATION.md) - 分层策略
- [SYNC_MECHANISM.md](SYNC_MECHANISM.md) - 同步机制设计
- [TECH_CONSTRAINTS.md](TECH_CONSTRAINTS.md) - 技术选型理由

**实现细节**:
- 运行 `cargo doc --open` 查看 Rust 数据结构文档
- 源码位置: `rust/src/models/`

---

## 更新日志

| 版本 | 变更 |
|------|------|
| 1.1.0 | 简化设备配置契约：设备昵称改为数据池特定，支持即时生成默认昵称；config.json 仅存储必要索引和用户偏好 |
| 1.0.0 | 初始版本,从 PRD.md 和 DATABASE.md 提取字段定义 |

---

**设计哲学**: 本文档定义数据契约,使用抽象类型描述 (如 UniqueIdentifier),不绑定具体实现 (如 UUID v7)。技术实现见 `TECH_CONSTRAINTS.md` 和源码。
