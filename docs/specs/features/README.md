# 功能规格总览
- 相关文档:
  - [卡片功能](card/README.md)
  - [数据池功能](pool/README.md)
  - [设置功能](settings/README.md)
- 测试覆盖:
  - `rust/tests/card_store_feature_test.rs`
  - `rust/tests/pool_model_feature_test.rs`
  - `test/feature/features/card_management_feature_test.dart`
  - `test/feature/features/pool_management_feature_test.dart`
  - `test/feature/features/settings_feature_test.dart`

## 卡片笔记

- **能力**: 新建、编辑、查看（列表/详情）、搜索、软删除
- **归属规则**:
  - 未加入数据池时，卡片归属本地
  - 加入数据池后仅允许创建数据池卡片
  - 加入时自动迁移本地卡片为数据池卡片
  - 退出数据池时删除数据池卡片
- **列表/搜索**: 默认仅返回未删除卡片，按 `updated_at` 倒序；关键词匹配标题或内容

## 数据池

- **能力**: 创建、加入、退出、查看信息、修改名称/密钥、同步
- **单池约束**: 每个 App 最多加入一个数据池；已加入时不可创建/加入其他数据池
- **加入方式**: 仅通过二维码；二维码包含 `multiaddr` 与 `pool_id` 明文，密钥由用户手动输入
- **校验规则**:
  - 加入时校验 `pool_id` 哈希 + `secretkey` 哈希
  - 同步时仅校验 `pool_id` 哈希
- **发现/广播**: 加入前不监听/广播 mDNS；加入后启用

## 设置

- **能力**: 日/夜主题切换、依赖库列表、开源协议展示
