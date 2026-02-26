# iroh 数据池成员字段调整设计（2026-02-26）

## 目标
- 用 iroh 的 `endpoint_id` 取代现有 `peer_id/public_key/multiaddr` 作为成员唯一标识
- 仅调整数据池元数据与持久化结构，不引入任何网络实现
- 允许成员显示昵称（`nickname`），默认取本机 `hostname`，可修改

## 非目标
- 不实现 iroh Endpoint/Discovery/同步收发逻辑
- 不做旧数据迁移兼容（MVP 阶段）
- 不引入额外权限/安全体系

## 背景与约束
- iroh 以 `EndpointId`（公钥）作为节点唯一标识
- 使用 iroh 内置 discovery（DNS/PKARR、本地发现）进行地址解析
- 本次仅调整数据模型与持久化，网络层延后

## 数据模型变更
### PoolMember
- 删除：`peer_id` / `public_key` / `multiaddr` / `hostname`
- 新增/保留：
  - `endpoint_id: String`
  - `nickname: String`
  - `os: String`
  - `is_admin: bool`

### LoroDoc members 结构
- 从：`[peer_id, public_key, multiaddr, os, hostname, is_admin]`
- 改为：`[endpoint_id, nickname, os, is_admin]`

## SQLite 结构调整（不做迁移）
### pool_members
- 字段：
  - `pool_id TEXT NOT NULL`
  - `endpoint_id TEXT NOT NULL`
  - `nickname TEXT NOT NULL`
  - `os TEXT NOT NULL`
  - `is_admin INTEGER NOT NULL`
- 主键：`(pool_id, endpoint_id)`
- 旧表数据不保留；按新 schema 重新创建

## API/方法签名影响
- `create_pool`：移除 `public_key/multiaddr/hostname`，增加 `endpoint_id/nickname/os`
- `join_pool`：成员结构改为 `endpoint_id/nickname/os/is_admin`
- `leave_pool`：使用 `endpoint_id`

## 测试与文档
- 更新 `rust/tests/sqlite_store_pool_test.rs` 适配新字段
- 更新计划/设计文档中 `peer_id/multiaddr/libp2p + mDNS` 的表述
  - 改为 `endpoint_id` + iroh 内置 discovery（不新增依赖）

## 风险
- 不做迁移导致旧数据池信息丢失（MVP 可接受）
- 仅依赖 discovery 解析地址，离线场景需后续补充本地发现策略
