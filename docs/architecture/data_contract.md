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
| `pool_ids` | List\<PoolId\> | 默认空数组 | 绑定的数据池列表 (Phase 2) |
| `created_at` | Timestamp | 自动生成、不可修改 | 创建时间 (毫秒级) |
| `updated_at` | Timestamp | 自动更新 | 最后更新时间 (毫秒级) |
| `is_deleted` | Boolean | 默认 false | 软删除标记 |

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
4. **数据池引用完整性**: `pool_ids` 中的 PoolId 必须是已存在的数据池 (Phase 2)
5. **内容非空**: `content` 不能为空字符串

### 1.4 生命周期契约

```
创建: id 生成 → created_at = now() → updated_at = created_at → is_deleted = false
更新: 修改字段 → updated_at = now()
删除: is_deleted = true → updated_at = now()
恢复: is_deleted = false → updated_at = now()
永久删除: 物理删除 (文件系统和缓存层)
```

---

## 2. 数据池契约 (Phase 2)

### 2.1 字段定义

| 字段 | 类型 | 约束 | 业务含义 |
|------|------|------|---------|
| `pool_id` | UniqueIdentifier | 必填、全局唯一 | 数据池唯一标识 |
| `name` | Text | 必填、最大 128 字符 | 数据池昵称 |
| `password_hash` | SecureHash | 必填、不可逆加密 | 密码哈希 (加密存储) |
| `members` | List\<Device\> | 至少 1 个成员 | 成员设备列表 |
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
- `device_name` 最大 64 字符,可修改
- `joined_at` 加入数据池的时间,不可修改

### 2.3 安全约束

1. **明文密码仅存储在系统安全存储中**: 使用 Keyring (不在 CRDT 或 SQLite 中)
2. **密码哈希使用不可逆算法**: bcrypt (不是 SHA256/MD5)
3. **网络传输仅验证哈希**: 不传输明文密码
4. **密码修改同步**: 修改 `password_hash` 后通过 CRDT 同步到所有设备

### 2.4 权限模型

**当前设计** (Phase 2):
- 所有成员权限平等
- 所有成员都可以修改数据池信息 (昵称、成员列表)
- 不支持"踢出成员"功能,仅支持"主动退出"

**未来扩展** (可选):
- 引入角色系统 (管理员/普通成员)
- 管理员可踢出成员
- 细粒度权限控制

---

## 3. 设备配置契约 (Phase 2)

### 3.1 字段定义

**本地配置文件** (`/data/config.json`):

| 字段 | 类型 | 约束 | 业务含义 |
|------|------|------|---------|
| `device_id` | UniqueIdentifier | 必填、本设备唯一 | 设备唯一标识 |
| `device_name` | Text | 必填、最大 64 字符 | 设备昵称 (用户可修改) |
| `joined_pools` | List\<PoolInfo\> | 默认空数组 | 已加入的数据池列表 |
| `resident_pools` | List\<PoolId\> | 默认空数组 | 常驻池列表 (多选) |

### 3.2 PoolInfo 结构

```
{
  "pool_id": UniqueIdentifier,
  "pool_name": Text,
  "joined_at": Timestamp
}
```

**注意**: 密码不存储在 `config.json` 中,存储在系统 Keyring。

### 3.3 密码存储契约

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

## 4. mDNS 广播数据契约 (Phase 2)

### 4.1 广播内容 (非敏感信息)

```json
{
  "device_id": "device-001",
  "device_name": "MacBook Pro",
  "pools": [
    {
      "pool_id": "pool-abc",
      "pool_name": "工作笔记"
    }
  ]
}
```

### 4.2 不包含的敏感信息

**禁止广播**:
- ❌ 密码或密码哈希
- ❌ 成员列表
- ❌ 卡片数量或内容
- ❌ 任何业务数据

**隐私保护**: 未授权设备无法通过 mDNS 获取数据池的任何实质性信息。

---

## 5. 卡片与数据池绑定契约 (Phase 2)

### 5.1 绑定规则

**多对多关系**:
- 一个卡片可以绑定多个数据池 (`pool_ids = ["pool-1", "pool-2"]`)
- 一个数据池可以包含多个卡片
- 未绑定数据池的卡片仅保存在本地 (`pool_ids = []`)

### 5.2 常驻池机制

**定义**: 用户从已加入的数据池中选择多个作为"常驻池"。

**行为**:
- 新建卡片时,自动绑定到所有常驻池 (`pool_ids = resident_pools`)
- 已存在的卡片不会因加入新数据池而自动绑定
- 用户可手动修改卡片的绑定池

### 5.3 同步过滤逻辑

**伪代码**:
```
should_sync_card(card, device):
  device_pools = device.joined_pools
  card_pools = card.pool_ids
  return card_pools ∩ device_pools ≠ ∅
```

**含义**: 仅同步设备已加入且卡片已绑定的数据池。

### 5.4 绑定冲突处理

**场景**: 多个设备并发修改卡片绑定时

**策略**: 使用 CRDT List 类型存储 `pool_ids`,自动合并

**示例**:
- 设备 A 修改: `pool_ids = [P1, P2]`
- 设备 B 修改: `pool_ids = [P1, P3]`
- CRDT 合并结果: `pool_ids = [P1, P2, P3]`

---

## 6. 数据完整性保证

### 6.1 引用完整性

**约束**:
- `card.pool_ids` 中的 PoolId 必须存在于 `joined_pools` 中
- 退出数据池时,如果卡片的 `pool_ids` 仅包含该池,则卡片变为本地卡片 (`pool_ids = []`)

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

### 7.3 数据池验证 (Phase 2)

**创建数据池**:
- `name` 不能为空
- `password` 明文长度至少 8 字符

**加入数据池**:
- `pool_id` 必须存在于 mDNS 广播中
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
| 1.0.0 | 初始版本,从 PRD.md 和 DATABASE.md 提取字段定义 |

---

**设计哲学**: 本文档定义数据契约,使用抽象类型描述 (如 UniqueIdentifier),不绑定具体实现 (如 UUID v7)。技术实现见 `TECH_CONSTRAINTS.md` 和源码。
