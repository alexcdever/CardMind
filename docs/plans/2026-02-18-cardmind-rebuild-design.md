# CardMind 重启设计草案（2026-02-18）

## 目标
- 继续使用 Flutter + Rust + `flutter_rust_bridge`
- 离线优先：所有写入进入 Loro，所有读取来自 SQLite
- 数据池可选：未加入池也可使用完整笔记功能
- 单池模式：同一时间仅允许加入一个数据池
- 池内同步：仅在加入池后启用 libp2p + mDNS

## 非目标
- 不做多池并行
- 不做高级加密与复杂权限体系
- 不做 FTS5 等高级搜索

## 架构总览
- 双层架构：
  - 写入：Loro CRDT（真相源）
  - 读取：SQLite（查询缓存）
  - 数据流：`loro_doc.commit()` → 订阅回调 → SQLite 更新
- 池外不启动任何 libp2p 组件
- 池内启动 libp2p，mDNS 仅用于发现

## 数据模型
### 数据池元数据（LoroDoc）
- `pool_id`: UUID v7
- `pool_key`: 32 字节随机数（Base64）
- `members[]`:
  - `peer_id`
  - `public_key`
  - `multiaddr`
  - `os`
  - `hostname`
  - `is_admin`
- `card_ids[]`: UUID v7 列表

### 卡片（LoroDoc）
- `id`: UUID v7
- `title`: string
- `content`: Markdown string
- `created_at`: timestamp
- `updated_at`: timestamp
- `deleted`: bool（软删除）

## 存储路径
- 池元数据：`data/loro/pool/<base64(uuid)>/`
- 卡片数据：`data/loro/note/<base64(uuid)>/`

## SQLite 缓存
- `pool_meta`：池基础字段
- `members`：成员缓存
- `cards`：卡片缓存
- 搜索：SQLite `LIKE`（标题 + 正文）

## 关键流程
### 创建池
1. 生成 `pool_id`（UUID v7）与 `pool_key`（Base64）
2. 创建池元数据 LoroDoc，并写入 `members`（创建者 `is_admin = true`）
3. 启动 libp2p + mDNS

### 未加入池的笔记
- 允许完整笔记功能
- 不启动 libp2p
- 不创建池元数据

### 加入池（二维码 + 审批）
- 任一成员可生成二维码，包含：
  - `pool_id_hash`
  - `pool_key_hash`
  - 生成者 `peer_id`
  - 生成者 `multiaddr`
- 申请方扫码后发送加入请求，包含：
  - 自身 `peer_id`
  - 自身 `multiaddr`
  - `os`
  - `hostname`
- 若接收者是管理员：弹窗审批
- 若接收者不是管理员：转发给在线管理员
- 审批通过后，管理员返回完整池元数据（包含明文 `pool_key`）
- 申请方写入本地池元数据 LoroDoc，并把自身写入 `members`
- 加入时将本地已有卡片 `id` 全部写入 `card_ids`

### 池内同步
- 基于 `members` 中的 `peer_id + public_key + multiaddr` 直连同步
- mDNS 仅用于发现在线节点

### 退出池
1. 读取池元数据 `card_ids`
2. 物理删除这些卡片：删除 Loro 文件 + SQLite 记录
3. 删除本地池元数据 LoroDoc
4. 关闭 libp2p + mDNS

## 错误码（加入池）
- `POOL_NOT_FOUND`
- `INVALID_POOL_HASH`
- `INVALID_KEY_HASH`
- `ADMIN_OFFLINE`
- `REQUEST_TIMEOUT`
- `REJECTED_BY_ADMIN`
- `ALREADY_MEMBER`

## UI 范围（首版）
- 池创建/加入
- 卡片列表
- 卡片编辑

### 桌面端
- 键鼠优先、快捷操作优先

### 移动端
- 触摸优先、手势优先

## 测试策略（首版）
- 单元测试：Loro → SQLite 同步、软删除、字段约束
- 功能测试：创建池、扫码加入、审批通过/拒绝、退出池清理
- 错误码测试：加入失败场景覆盖七个错误码

## 风险与约束
- `pool_key` 明文分发，安全性基础且可被中间人观察
- 单池模式降低复杂度，但限制了使用场景
