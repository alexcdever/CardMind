# Peer/Nickname & mDNS Minimal Broadcast Alignment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 统一池成员字段为 `peer_id/nickname/device_os` 并移除自定义 mDNS 广播，完成 Flutter/Rust 测试与业务代码对齐。

**Architecture:** 以规格为单一事实源，先修订 domain/architecture/features 文档；再按 TDD 更新 Rust 模型/存储/接口与 mDNS 发现逻辑；随后更新 Flutter QR 加入与成员展示逻辑，并运行全量测试。

**Tech Stack:** Markdown specs、Rust、Flutter/Dart、flutter_rust_bridge、cargo test、flutter test

---

### Task 1: 规格对齐（成员字段 + mDNS 只用 libp2p 默认广播）

**Files:**
- Modify: `docs/specs/domain/pool.md:31-47`
- Modify: `docs/specs/features/pool/members.md:11-32`
- Modify: `docs/specs/architecture/sync/peer_discovery.md:9-18`
- Modify: `docs/specs/architecture/security/privacy.md:9-18`
- Modify: `docs/specs/features/pool/discovery.md:11-31`

**Step 1: 更新规格条目**

```text
- 成员字段统一为 peer_id / nickname / device_os / joined_at
- 默认昵称 = peer_id 前五位 + device_os（直接拼接）
- mDNS 不携带任何自定义字段，仅使用 libp2p 默认广播
```

**Step 2: 术语清理检查**

Run: `rg -n "device_id|device_name" docs/specs/{domain,architecture,features}`
Expected: 无匹配

**Step 3: Commit**

```bash
git add docs/specs/domain/pool.md docs/specs/features/pool/members.md \
  docs/specs/architecture/sync/peer_discovery.md docs/specs/architecture/security/privacy.md \
  docs/specs/features/pool/discovery.md
git commit -m "docs: align pool member identity and mdns privacy"
```

---

### Task 2: Rust 池成员模型改为 peer 元数据（TDD）

**Files:**
- Modify: `rust/src/models/pool.rs:49-125`
- Modify: `rust/src/store/pool_store.rs:282-369`
- Modify: `rust/src/api/pool.rs:171-225`
- Modify: `rust/tests/pool_model_feature_test.rs:176-210`
- Modify: `rust/src/store/pool_store.rs:741-812`
- Modify: `rust/src/api/pool.rs:376-420`

**Step 1: 写入失败测试（默认昵称规则）**

```rust
#[test]
fn it_should_generate_default_nickname_from_peer_id_and_device_os() {
    let device = Device::new("12D3KooWABCDE", "macOS");
    assert_eq!(device.peer_id, "12D3KooWABCDE");
    assert_eq!(device.device_os, "macOS");
    assert_eq!(device.nickname, "12D3KmacOS"); // 前 5 位 + device_os
}
```

**Step 2: 运行测试验证失败**

Run: `cd rust && cargo test it_should_generate_default_nickname_from_peer_id_and_device_os`
Expected: FAIL（字段/构造器未对齐）

**Step 3: 最小实现通过测试**

```text
- Device 字段改为 peer_id/nickname/device_os/joined_at
- Device::new(peer_id, device_os) 生成默认昵称
- Pool 成员增删改使用 peer_id 与 nickname
- Loro 序列化键改为 peer_id/nickname/device_os
- add_pool_member API 签名改为 (pool_id, peer_id, device_os)
```

**Step 4: 运行相关测试**

Run: `cd rust && cargo test pool_model_feature_test pool_store`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/models/pool.rs rust/src/store/pool_store.rs rust/src/api/pool.rs \
  rust/tests/pool_model_feature_test.rs
git commit -m "refactor: align pool members to peer metadata"
```

---

### Task 3: Rust mDNS 去除自定义广播（TDD）

**Files:**
- Modify: `rust/src/p2p/discovery.rs:10-310`
- Modify: `rust/tests/mdns_discovery_feature_test.rs:1-29`
- Modify: `rust/tests/security_p2p_discovery_feature_test.rs:9-36`
- Modify: `rust/src/api/mdns_discovery.rs:328-490`

**Step 1: 写入失败测试（无自定义广播）**

```rust
use cardmind_rust::p2p::discovery::CUSTOM_MDNS_PAYLOAD_ENABLED;

#[test]
fn it_should_not_enable_custom_mdns_payload() {
    assert!(!CUSTOM_MDNS_PAYLOAD_ENABLED);
}
```

**Step 2: 运行测试验证失败**

Run: `cd rust && cargo test it_should_not_enable_custom_mdns_payload`
Expected: FAIL（常量未定义/默认不满足）

**Step 3: 最小实现通过测试**

```text
- 删除 DeviceInfo/PoolInfo 自定义广播结构
- 增加 CUSTOM_MDNS_PAYLOAD_ENABLED = false 常量
- API 文档与事件结构移除自定义广播描述
```

**Step 4: 运行相关测试**

Run: `cd rust && cargo test mdns_discovery_feature_test security_p2p_discovery_feature_test`
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/p2p/discovery.rs rust/tests/mdns_discovery_feature_test.rs \
  rust/tests/security_p2p_discovery_feature_test.rs rust/src/api/mdns_discovery.rs
git commit -m "refactor: remove custom mdns payload"
```

---

### Task 4: Flutter 二维码加入格式对齐（TDD）

**Files:**
- Modify: `lib/services/qr_code_parser.dart:8-194`
- Modify: `lib/services/qr_code_generator.dart:10-155`
- Modify: `test/unit/services/qr_code_parser_unit_test.dart:10-220`
- Modify: `test/generate_test_qr_v3.dart:10-70`
- Modify: `lib/widgets/pair_device_dialog.dart`
- Modify: `lib/widgets/qr_code_upload_tab.dart`
- Modify: `lib/widgets/qr_code_scanner_tab.dart`

**Step 1: 写入失败测试（二维码仅包含 pool_id + multiaddr）**

```dart
test('it_should_parse_pool_join_qr_payload', () {
  final json = {
    'version': '1.0',
    'type': 'pool_join',
    'poolId': 'pool-001',
    'multiaddrs': ['/ip4/192.168.1.100/tcp/4001'],
  };
  final data = QRCodeData.fromJson(json);
  expect(data.poolId, 'pool-001');
  expect(data.multiaddrs, isNotEmpty);
});
```

**Step 2: 运行测试验证失败**

Run: `flutter test test/unit/services/qr_code_parser_unit_test.dart`
Expected: FAIL（旧字段仍要求 peerId/deviceName/deviceType/timestamp）

**Step 3: 最小实现通过测试**

```text
- QRCodeData 仅保留 version/type/poolId/multiaddrs
- type 固定为 pool_join
- 生成/解析/校验逻辑移除 peerId/deviceName/deviceType/timestamp
- UI 展示改为 poolId + multiaddr
```

**Step 4: 运行相关测试**

Run: `flutter test test/unit/services/qr_code_parser_unit_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/services/qr_code_parser.dart lib/services/qr_code_generator.dart \
  test/unit/services/qr_code_parser_unit_test.dart test/generate_test_qr_v3.dart
git commit -m "refactor: align pool join qr schema"
```

---

### Task 5: Flutter 池成员字段对齐 + Bridge 重生成（TDD）

**Files:**
- Modify: `lib/widgets/note_card_enhanced.dart:85-96`
- Modify: `lib/widgets/note_card_desktop.dart:494-505`
- Modify: `lib/providers/pool_provider.dart:104-155`
- Modify: `test/feature/widgets/note_card_enhanced_feature_test.dart`
- Modify: `test/feature/widgets/note_card_feature_test.dart`
- Modify: `test/feature/widgets/card_list_item_feature_test.dart`
- Modify: `test/feature/widgets/card_list_item_mobile_feature_test.dart`
- Modify: `test/feature/widgets/card_list_item_desktop_feature_test.dart`
- Modify: `lib/bridge/models/pool.dart`
- Regenerate: `lib/bridge/frb_generated*.dart`

**Step 1: 写入失败测试（member 字段改为 peer_id/nickname）**

```dart
final members = [
  pool.Device(
    peerId: '12D3KooWTestPeer',
    nickname: '12D3KmacOS',
    deviceOs: 'macOS',
    joinedAt: 1706234567,
  ),
];
```

**Step 2: 运行测试验证失败**

Run: `flutter test test/feature/widgets/note_card_enhanced_feature_test.dart`
Expected: FAIL（字段未对齐）

**Step 3: 最小实现通过测试**

```text
- pool member 使用 peerId/nickname/deviceOs
- UI 解析 lastEditPeer 对应成员昵称
- joinPool 调用 addPoolMember(poolId, peerId, deviceOs)
- 更新 Rust FFI 后执行 dart tool/generate_bridge.dart
```

**Step 4: 运行相关测试**

Run: `flutter test test/feature/widgets/note_card_enhanced_feature_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/widgets/note_card_enhanced.dart lib/widgets/note_card_desktop.dart \
  lib/providers/pool_provider.dart lib/bridge/models/pool.dart lib/bridge/frb_generated*.dart \
  test/feature/widgets/note_card_enhanced_feature_test.dart
git commit -m "refactor: align pool member fields in flutter"
```

---

### Task 6: 全量验证

**Files:**
- Test: `cd rust && cargo test`
- Test: `flutter test`

**Step 1: 运行 Rust 测试**

Run: `cd rust && cargo test`
Expected: `test result: ok`

**Step 2: 运行 Flutter 测试**

Run: `flutter test`
Expected: `All tests passed!`

