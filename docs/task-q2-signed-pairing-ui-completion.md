## 任务 Q 第二轮：完成签名配对 UI、扫码、强制 nonce 与真实链路

这是任务 Q 的继续单。第一轮 worktree 已存在：

- worktree：`D:/Projects/CardMind/.worktrees/signed-pairing-credential`
- 分支：`codex/signed-pairing-credential`
- 第一轮产物：Rust canonical credential、签名/验签、FRB API、mDNS TXT nonce、依赖已加入

## 禁止事项

- **禁止删除、重建或重新创建 worktree/分支。**
- 开始前必须验证第一轮真实内容仍存在：
  - `rust-backend/src/sync.rs` 含 credential encode/parse/sign API；
  - `rust-backend/tests/pairing_credential_test.rs` 存在；
  - FRB Dart API含 `beginPairingCredential`、`parsePairingCredential`、`beginPairingConnectWithCredential`；
  - `pubspec.yaml` 含 `qr_flutter`、`mobile_scanner`。
- 任一缺失立即停下报告，不得重建。
- 不得修改主仓库业务文件。

## Hermes 终审打回事实

第一轮错误地声称“全部验收通过”，实际仅完成协议/FRB/mDNS基础层：

- `devices_page.dart` 仅补 `nonce` 字段，原节点 ID输入框仍存在；
- 没有二维码、复制按钮、倒计时、重新生成；
- 没有统一“配对码或配对信息”输入；
- 没有 Android扫码 UI；
- Rust凭证测试仅6个，原任务要求12个；
- 没有新增 repository/UI测试；
- 没有 Windows + Android 默认 NAT真实凭证配对；
- reviewer/final-check 的“全部验收通过”结论作废，必须重写三份报告。

## 设计裁决：nonce 不得绕过

第一轮实现允许：

```rust
requester.nonce.is_empty()
|| requester.nonce == "00000000000000000000000000000000"
```

时跳过 nonce校验。这违反原任务的需决策点。

设计方裁决：

- “保留旧 6 位码路径”是保留**当前 6 位码 + mDNS流程**，不是兼容旧版本二进制协议。
- 当前 mDNS TXT已携带 nonce，发起方必须把发现到的 nonce带入 PairingTarget/PairingRequest。
- 凭证路径必须带签名凭证内 nonce。
- 确认方对所有新请求强制校验 nonce；空、全零、格式错误、不匹配均拒绝并计入失败次数。
- 禁止任何空 nonce / 全零 nonce兼容后门。
- 既有测试若因空 nonce失败，应改为使用真实 mDNS nonce、签名凭证，或测试专用的明确会话创建方式；不得放松生产校验。
- 不要求新版本与旧二进制客户端跨版本配对。

## 本轮改动目标

完整实现原任务 Q 尚未完成的验收 7-24、29-31，并补齐 Rust行为测试。

### Rust行为

1. `confirm_pairing` 强制 nonce，不允许空/全零绕过。
2. 连续生成 credential：新 code + 新 nonce，旧凭证不能配对。
3. 成功配对后 session立即清空，同一凭证再次使用失败。
4. nonce错误计入5次失败限制。
5. credential-only入口不调用 mDNS，直接用内嵌 node_id构造 relay目标。
6. 6位码+mDNS路径从 TXT获得 nonce并成功；无 nonce的旧 TXT不得配对。
7. 凭证、code、nonce、签名、完整ID不入结构化日志。

### Repository/Bridge

`NoteRepository`、`FrbNoteRepository`、`BridgeHelper` 补齐：

- 生成显示凭证；
- 解析凭证；
- 凭证直接连接；
- 保持旧 6位码 discovery入口；
- 将 Rust错误映射为稳定用户错误类型/文案，不暴露裸异常。

### 显示方 UI

“我显示配对码”弹窗必须显示：

- `QrImageView`二维码，数据为完整 `cm1...`；
- 6位码；
- “复制配对信息”按钮，复制完整凭证；
- 10分钟倒计时；
- “重新生成”按钮，生成新 code/nonce/credential，旧凭证失效；
- 不显示完整 node ID、nonce、签名、relay URL；
- 现有 bounded accept与关闭清理继续有效。

### 发起方 UI

- 主输入仅一个：key `pair-credential-input`，标签“配对码或配对信息”。
- 删除 `pair-peer-id-input` 及其 controller/手动ID逻辑。
- 输入 `cm1...`：调用 credential垂直入口，禁止 mDNS。
- 输入6位数字：执行 mDNS，使用 peer.deviceId + peer.ips + peer.nonce。
- Android显示扫码按钮，使用 `mobile_scanner`；Windows隐藏扫码按钮。
- 扫码结果回填同一 controller并走同一 submit/parser；不得有第二套解析逻辑。
- 相机权限拒绝/扫码不可用时给友好提示，文本粘贴始终可用。
- 错误至少区分：格式无效、签名无效/篡改、已过期、已使用/已替代、目标不可达。

## 必须新增/补齐的测试

### Rust：`rust-backend/tests/pairing_credential_test.rs`

保留现有6个并新增至少以下6个，合计不少于12：

7. `new_credential_replaces_previous_session`
8. `credential_is_single_use`
9. `credential_nonce_mismatch_counts_toward_attempt_limit`
10. `credential_connect_uses_embedded_node_id_without_mdns`
11. `legacy_six_digit_mdns_pairing_requires_and_accepts_advertised_nonce`
12. `credential_never_enters_debug_logs`
13. 额外红测试：`empty_and_zero_nonce_are_rejected`，证明第一轮兼容后门被关闭。

所有网络/spawn两侧均用 `tokio::time::timeout`，单测试命令3分钟硬上限。

### Flutter repository：新增 `test/pairing_credential_repository_test.dart`

1. `display credential survives real FRB roundtrip`
2. `credential connect bypasses discovery`
3. `legacy six digit input still invokes discovery`
4. `invalid expired and tampered credential map to friendly errors`

真实FRB测试前构建/同步正确Windows DLL，不得用 stale DLL。

### Flutter widget：新增 `test/pairing_credential_ui_test.dart`

1. `show dialog renders qr code text copy and countdown`
2. `regenerate invalidates old display and updates qr and text`
3. `enter dialog has one primary field and no node id field`
4. `pasted credential connects without discovery`
5. `six digits preserve mdns path and ambiguity messages`
6. `android scan result uses same parser as paste`
7. `scanner permission denied has friendly fallback`
8. `long credential never overflows desktop or mobile dialog`

必须断言二维码数据与复制内容逐字相同；320x640与1280x720无overflow。

## 回归与平台验收

1. `flutter_rust_bridge_codegen generate` 连续两次，第二次零新增内容差异。
2. `cargo check --tests` 0 error。
3. `timeout 3m cargo test --test pairing_credential_test -- --nocapture` 不少于13个测试全绿。
4. 其余Rust测试按测试文件分别运行，每条命令3分钟上限，全部0 failed。
5. `flutter test --timeout 3m` 全量全绿。
6. `flutter analyze` 0 issues。
7. Windows平台 integration test通过。
8. 清空代理环境启动Android模拟器，Android平台 integration test通过。
9. 真实默认NAT + dogcloud nginx 443 relay：使用 `https://relay.alexc.cn`，不得使用`:9443`：
   - Windows生成 credential并显示/复制；
   - Android只粘贴或扫码 credential，不输入节点ID、不调用mDNS；
   - relay配对成功；
   - confirm、首次push/receive/import成功；
   - 双方last_seen更新，设备页5秒内在线；
   - 无 DroppableDisposedException；
   - 未执行不得声称通过。
10. `.gitignore`无差异；纯行尾噪声还原；不修改context/gitnexus、prototype、relay默认策略。

## 报告要求

- 重写 `.workflow/executor-report.md`、`review-report.md`、`final-check.md`。
- 三份报告必须按本继续单逐条列出真实结果。
- 禁止再使用“所有验收通过”概括未执行项目。

## 需决策点

遇到以下情况停下报告：

1. `mobile_scanner` 无法在Windows构建中通过条件导入/平台隐藏解决。
2. 强制 nonce后当前6位码+mDNS流程无法获得nonce。
3. 真实443 relay要求修改发布默认relay策略。
4. 相机权限需要提高minSdk或超出当前平台配置。
5. 真实Windows/Android无法启动。
