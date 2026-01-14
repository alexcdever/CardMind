# ADR-0003: 技术选型决策

**Status**: Accepted
**Date**: 2024-12-31
**Deciders**: CardMind Team

---

## Overview

本文档记录 CardMind 核心技术栈的选型决策，包括 CRDT、数据库、ID 生成、跨平台桥接等。

---

## 1. CRDT 选型: Loro

### Context

需要支持多设备离线编辑、联网后自动合并、去中心化同步，数据永不丢失。

### Decision

采用 **Loro CRDT** 作为数据同步引擎。

### Alternatives Considered

| 方案 | 自动冲突解决 | P2P 支持 | 文件持久化 | 性能 | 结论 |
|------|------------|---------|-----------|------|------|
| 手动冲突处理 | ❌ | ✓ | ✓ | ✓ | ❌ 用户体验差 |
| OT 算法 | ✓ | ❌ (需中心化) | ✓ | ✓ | ❌ 违背去中心化 |
| **Loro CRDT** | ✓ | ✓ | ✓ | ✓ (Rust) | ✅ 采用 |
| Yjs | ✓ | ✓ | ❌ (内存) | ✓ (JS/WASM) | ❌ 无法直接持久化 |
| Automerge | ✓ | ✓ | ✓ | ⚠️ 性能较低 | ❌ 不适合移动端 |

### Reasoning

Loro 是唯一同时满足以下条件的方案：
1. 自动冲突解决 (CRDT)
2. P2P 支持（去中心化）
3. 文件持久化（简单可靠）
4. 高性能（Rust 实现）

---

## 2. 缓存层选型: SQLite

### Context

Loro CRDT 专注于数据一致性和同步，不擅长查询。需要支持快速列表查询、全文搜索、排序分页。

### Decision

采用 **双层架构**：
- Loro CRDT：负责写操作、冲突解决、P2P 同步
- SQLite：负责读操作、快速查询、全文搜索

### Reasoning

| 功能 | Loro CRDT | SQLite | 结论 |
|------|----------|--------|------|
| 查询所有卡片 | 遍历 O(n) | 索引 O(log n) | SQLite 更快 |
| 按时间排序 | 手动 O(n log n) | ORDER BY | SQLite 优化 |
| 全文搜索 | 不支持 | FTS5 | SQLite 独有 |
| 分页查询 | 不支持 | LIMIT/OFFSET | SQLite 原生 |

### Trade-offs

**收益**：
- 兼具 CRDT 和关系数据库优势
- 查询性能毫秒级响应
- 支持复杂查询 (SQL 语法)

**代价**：
- 需维护订阅同步机制
- 数据存储占用略高（两份数据）

**结论**：代价可控，收益显著。

---

## 3. ID 生成: UUID v7

### Context

需要分布式环境下生成唯一 ID，支持按创建时间排序，无中心化协调。

### Decision

采用 **UUID v7** 作为唯一标识符。

### Alternatives Considered

| 版本 | 唯一性 | 时间有序 | 分布式生成 | 标准化 | 结论 |
|------|-------|---------|-----------|-------|------|
| UUID v4 | ✓ | ❌ | ✓ | ✓ (RFC 4122) | ❌ 无法排序 |
| **UUID v7** | ✓ | ✓ | ✓ | ✓ (IETF Draft) | ✅ 采用 |
| ULID | ✓ | ✓ | ✓ | ⚠️ 非标准 | ❌ 生态较小 |
| Snowflake | ✓ | ✓ | ⚠️ 需机器 ID | ❌ 不适合 P2P |

### Reasoning

1. **时间有序**：前 48 位是 Unix 时间戳，天然支持按创建时间排序
2. **标准化**：IETF 标准，生态成熟
3. **分布式生成**：无需中心化 ID 生成器
4. **全局唯一**：128 位长度，冲突概率 < 10^-15

---

## 4. 跨平台桥接: flutter_rust_bridge

### Context

Flutter UI + Rust 后端，需要类型安全、自动生成桥接代码。

### Decision

采用 **flutter_rust_bridge** 作为 Dart/Rust 桥接层。

### Alternatives Considered

| 方案 | 类型安全 | 自动生成 | 性能 | 易用性 | 结论 |
|------|---------|---------|------|-------|------|
| FFI 原生 | ❌ | ❌ | ✓ (最优) | ⚠️ 复杂 | ❌ 易出错 |
| JSON over FFI | ❌ | ❌ | ⚠️ 序列化 | ✓ | ❌ 类型不安全 |
| **flutter_rust_bridge** | ✓ | ✓ | ✓ | ✓ | ✅ 采用 |

### Reasoning

1. **自动生成代码**：只需在 Rust 中定义函数，自动生成 Dart 绑定
2. **类型安全**：编译时检查，避免类型不匹配
3. **支持复杂类型**：自动序列化 `Vec<T>`, `Option<T>`, `Result<T, E>`
4. **错误处理**：Rust 的 `Result` 自动转换为 Dart 的 `Future`

---

## 5. 密码哈希: bcrypt

### Context

数据池需要密码保护，防止未授权设备访问，支持安全存储。

### Decision

采用 **bcrypt** 作为密码哈希算法。

### Alternatives Considered

| 算法 | 不可逆 | 抗暴力破解 | 盐值 | 标准化 | 结论 |
|------|-------|-----------|------|-------|------|
| MD5 | ⚠️ 已破解 | ❌ | ❌ | ❌ | ❌ 不安全 |
| SHA256 | ✓ | ❌ (太快) | ❌ | ❌ | ❌ 易被暴力破解 |
| **bcrypt** | ✓ | ✓ (可调) | ✓ (自动) | ✓ | ✅ 采用 |
| scrypt | ✓ | ✓ | ✓ | ✓ | ⚠️ 内存消耗大 |
| Argon2 | ✓ | ✓ | ✓ | ✓ | ⚠️ 生态较新 |

### Reasoning

1. **工作因子可调**：可以增加计算复杂度，抵抗硬件提升
2. **盐值自动生成**：避免彩虹表攻击
3. **生态成熟**：Rust、Dart、Java、Python 都有成熟库
4. **性能平衡**：工作因子 12 下，单次验证 ~100ms

---

## 6. 设备发现: mDNS

### Context

本地网络自动发现设备，无需手动配置 IP，零配置体验。

### Decision

采用 **mDNS** (RFC 6762) 进行本地网络设备发现。

### Alternatives Considered

| 方案 | 零配置 | 本地网络 | 跨平台 | 结论 |
|------|-------|---------|-------|------|
| 手动输入 IP | ❌ | ✓ | ✓ | ❌ 体验差 |
| **mDNS** | ✓ | ✓ | ✓ | ✅ 采用 |
| DHT | ✓ | ❌ (全球) | ✓ | ⚠️ 隐私风险 |
| 中心化服务器 | ✓ | ❌ | ✓ | ❌ 违背去中心化 |

### Reasoning

1. **零配置**：设备自动广播和发现
2. **本地网络**：仅在局域网内广播，隐私保护
3. **标准化**：RFC 6762，所有平台支持
4. **libp2p 集成**：libp2p 原生支持 mDNS

### Security

- mDNS 广播仅包含非敏感信息（设备 ID、数据池 ID）
- 数据池名称仅在密码验证成功后获取
- 不包含密码、成员列表、卡片内容

---

## 7. 密码存储: 系统 Keyring

### Context

安全存储明文密码，App 重启后自动重连，利用操作系统原生安全机制。

### Decision

采用 **系统 Keyring** (keyring crate) 存储密码。

### Platform Support

| 平台 | 安全存储机制 | Rust Crate |
|------|-------------|-----------|
| iOS | Keychain | keyring |
| Android | Keystore | keyring |
| Windows | Credential Manager | keyring |
| macOS | Keychain | keyring |
| Linux | Secret Service API | keyring |

### Reasoning

1. **平台原生安全**：利用操作系统加密机制
2. **硬件级加密**：iOS/Android 支持硬件加密
3. **跨平台统一 API**：keyring crate 提供统一接口
4. **自动清理**：App 卸载时自动清除密码

---

## 8. 总结

### 技术选型矩阵

| 技术选型 | 业务需求 | 决策理由 |
|---------|---------|---------|
| Loro CRDT | 分布式同步、自动冲突解决 | 唯一满足 CRDT + P2P + 文件持久化 |
| SQLite | 快速查询、全文搜索 | CRDT 不擅长查询，双层架构兼具优势 |
| UUID v7 | 分布式 ID、时间有序 | IETF 标准，时间有序，分布式生成 |
| flutter_rust_bridge | 跨平台 UI + Rust 后端 | 类型安全，自动生成，易用 |
| bcrypt | 密码哈希 | 工作因子可调，抗暴力破解，生态成熟 |
| mDNS | 本地网络设备发现 | 零配置，本地网络，标准化 |
| 系统 Keyring | 安全存储密码 | 平台原生，硬件加密，跨平台统一 |

### 核心决策原则

1. **优先标准化技术**：UUID v7、mDNS、bcrypt 都是标准协议
2. **兼顾性能与安全**：Rust 实现高性能，bcrypt 保证安全
3. **平衡复杂度与收益**：双层架构略增复杂度，但收益显著
4. **跨平台一致性**：所有技术都支持主流平台

---

## Related Documents

- [System Design](../architecture/system_design.md) - 架构原则
- [Data Contract](../architecture/data_contract.md) - 数据契约
- [ADR-0002: 双层架构决策](./0002-dual-layer-architecture.md)

---

**最后更新**: 2026-01-15
**版本**: 1.0.0
