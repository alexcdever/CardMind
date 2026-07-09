# P2P 同步与 mDNS 行为调整设计

日期: 2026-02-03
状态: 已确认

## 背景与问题

当前规格、测试与实现对 mDNS 的职责、启停条件及设备标识存在脱节：
- 设备发现与 P2P 启动逻辑不一致
- device_id 与 peer_id 的定位重复
- mDNS 临时开关与产品意图不一致

## 目标

- 未加入池时不启动 P2P 服务，也不进行 mDNS 监听或广播
- 加入池后启动 P2P 服务，并启用 libp2p mDNS 监听与广播
- 使用 peer_id 全局替代 device_id
- 连接后在握手阶段完成同池校验
- Flutter 处理权限引导，Rust 返回语义化错误码

## 非目标

- 不引入自定义 mDNS TXT 记录
- 不在发现阶段进行同池过滤
- 不做旧数据迁移（视为破坏性变更）

## 关键决策

1) 发现实现只保留 libp2p mDNS
2) 未加入池时 P2P 不启动
3) peer_id 取代 device_id，且来源于持久化密钥对
4) pool_hash 使用 HKDF-SHA256 派生，len=32 字节，hex=64
5) 权限流程为 Rust 先启动，失败则 Flutter 授权后重试
6) 移除 mDNS 临时开关与计时器

## 数据流与组件行为

### 启动流程

- Flutter 在用户加入池后调用 Rust `start_p2p()`
- Rust 初始化 IdentityManager
  - 若无密钥对则生成并持久化
  - 派生 peer_id，写回 DeviceConfig（若缺失）
- 创建 P2PNetwork 与 P2PSyncService
- 启动 TCP 监听与 libp2p mDNS

### 发现与连接

- mDNS 发现仅用于触发连接尝试
- 不做池过滤
- 连接建立后进入握手

### 握手与池校验

- 发起方发送 pool_hash
- 接收方使用本地 pool_id + password 派生 pool_hash
- 不匹配则拒绝并断开
- 匹配则继续同步并更新在线状态

### 退出池

- Flutter 调用 `stop_p2p()`
- Rust 停止 mDNS、断开连接、停止监听
- 保留密钥对与 peer_id

## 错误处理

采用分层语义化错误码:

- CardMindError::Mdns(MdnsError::PermissionDenied)
- CardMindError::Mdns(MdnsError::SocketUnavailable)
- CardMindError::Mdns(MdnsError::Unsupported)
- CardMindError::Mdns(MdnsError::StartFailed)
- CardMindError::InvalidState(NotJoinedPool)

Flutter 监听 `PermissionDenied` 后发起系统授权，再调用 `start_p2p()` 重试。

## 规格与测试对齐

### 规格更新

- docs/specs/architecture/sync/peer_discovery.md
  - 改为 libp2p mDNS 发现
  - 移除 TXT 记录、version/protocol 描述
  - 发现后连接，握手阶段池校验

- docs/specs/architecture/sync/service.md
  - 启动条件: 加入池才启用
  - 握手校验与错误处理

- docs/specs/architecture/storage/device_config.md
  - 移除 device_id
  - peer_id 作为唯一设备标识
  - 删除 mDNS 临时开关/计时器

### 测试更新

新增/调整:
- it_should_not_start_p2p_when_not_joined()
- it_should_start_mdns_when_joined()
- it_should_return_mdns_permission_error_when_denied()
- it_should_reject_peer_on_pool_hash_mismatch()

移除/替换:
- rust/tests/sp_mdns_001_spec.rs
- 任何依赖 mDNS 临时开关/计时器的测试

## 破坏性变更

- 不做历史配置迁移
- 旧 device_id 字段与旧 mDNS 临时开关逻辑直接移除

## 风险与待验证

- mDNS 在各平台的权限行为与错误码映射需要实测
- libp2p mDNS 在移动端的稳定性需要验证
