# 数据池 secretkey 明文方案 设计

**目标**：数据池密码改为明文 `secretkey` 存入 Loro 元数据；加入数据池时仅做 `SHA-256` 哈希匹配；删除 Keyring 与所有安全强化逻辑；不考虑旧数据兼容性。

**范围**：
- Rust：Pool 模型、PoolStore、SQLite schema、密码工具与 Pool API。
- P2P：禁用 `pool_hash` 校验，仅保留加入时哈希校验。
- Flutter：移除 keyring 相关桥接 API，更新生成代码。
- 测试：更新/删除所有与旧安全逻辑相关的测试。

**关键决策**：
- `secretkey` 明文保存在 `pool` 元数据（Loro map）。
- 加入时发送 `sha-256(password)`，接收方对 `secretkey` 做同样哈希后匹配。
- `pool_hash` 不再参与握手与同步校验。
- 删除 bcrypt、强度校验、时间戳、防重放、内存清零、Keyring 存取。
- 不迁移旧字段 `password_hash`。

**数据与存储**：
- Loro：`pool.secretkey` 字段。
- SQLite：`pools.secretkey` 列。

**接口变化**：
- `create_pool`：保存明文 `secretkey`。
- `verify_pool_password`：改为 `sha-256` 哈希比对。
- 移除所有 `keyring` API。

**非目标**：
- 任何密码安全能力与兼容性迁移。

**测试**：
- 新增/更新 SHA-256 哈希与验证测试。
- 删除 keyring 与旧安全逻辑测试。
