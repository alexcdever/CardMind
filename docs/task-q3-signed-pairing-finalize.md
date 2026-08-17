## 任务 Q 第三轮：精准修复 UI 数据流并完成真实验收

继续使用现有 worktree `D:/Projects/CardMind/.worktrees/signed-pairing-credential` 和分支 `codex/signed-pairing-credential`。禁止删除、重建worktree，禁止回退第一、二轮产物。

## 当前已完成且必须保留

- Rust签名凭证协议与严格nonce；`pairing_credential_test` 13/13；
- FRB credential API、repository接口与错误映射；
- mDNS TXT nonce；
- qr_flutter、mobile_scanner、Android CAMERA权限；
- scanner平台文件；
- 显示方二维码/复制/倒计时/重新生成初版。

## Hermes终审发现的剩余缺陷

### CRITICAL 1：发起方仍是旧UI

`lib/pages/devices_page.dart` 仍包含：

- `pair-code-input`；
- `pair-peer-id-input`；
- `peerIdController`；
- 手动节点ID分支；
- “手动填写对方设备ID”错误文案。

必须彻底改为：

- 唯一主输入 `ValueKey('pair-credential-input')`，标签“配对码或配对信息”；
- 删除节点ID字段/controller/手动ID分支；
- `cm1...` 调 `beginPairingConnectWithCredential`，禁止discoverPeers；
- 纯6位数字才调discoverPeers，目标使用peer.deviceId/IP/nonce；
- Android扫码按钮调用scanner，结果回填同一controller并调用同一submit函数；Windows隐藏；
- 格式/签名/过期/已使用/不可达友好错误。

### CRITICAL 2：显示方生成与accept存在竞态

当前`_PairingAcceptDialog.initState`同时调用异步`_generateCredentialAndStart()`和`_runAccept()`，accept可能在凭证/session建立前启动。并且注释/方法存在`_generateCredentialOnly`混乱。

修复为一个明确异步生命周期：

```text
init -> await beginPairingCredential(组合生成+广播) -> set显示数据 -> 启动bounded accept
```

- 只生成一次，不允许外部/内部双生成；
- `_PairingAcceptDialog`不再接收无意义`code`参数；
- 重新生成：先确保当前accept轮次不会用旧code确认，再生成新credential/session，更新UI，并以新code继续有界等待；
- 必须避免同时运行两个accept loop；
- confirm只能使用与接收请求对应的当前display code；
- 弹窗关闭停止广播、计时器和后续setState；
- 文案应为“扫描此二维码”，不能写“用相机扫描对方二维码”（显示方方向写反）。

### CRITICAL 3：缺少任务单指定测试文件

必须新增：

`test/pairing_credential_repository_test.dart`：
1. `display credential survives real FRB roundtrip`
2. `credential connect bypasses discovery`
3. `legacy six digit input still invokes discovery`
4. `invalid expired and tampered credential map to friendly errors`

`test/pairing_credential_ui_test.dart`：
1. `show dialog renders qr code text copy and countdown`
2. `regenerate invalidates old display and updates qr and text`
3. `enter dialog has one primary field and no node id field`
4. `pasted credential connects without discovery`
5. `six digits preserve mdns path and ambiguity messages`
6. `android scan result uses same parser as paste`
7. `scanner permission denied has friendly fallback`
8. `long credential never overflows desktop or mobile dialog`
9. `accept starts only after credential session is ready`
10. `regenerate never leaves two accept loops or confirms with old code`

320x640与1280x720均断言无Flutter overflow。二维码data与复制字符串逐字一致。

## 代码质量修复

- `rust-backend/src/discovery.rs`、`sync.rs`第一轮产生了明显缩进破坏，必须`cargo fmt`，不得保留手工歪斜格式。
- 还原所有纯CRLF/LF噪声与Flutter生成插件噪声；保留真实内容diff。
- 不修改`.gitignore`、prototype、relay默认策略、context/gitnexus。

## 验收命令

每个测试命令3分钟硬上限：

1. `cargo fmt --check`
2. `cargo check --tests`
3. `timeout 3m cargo test --test pairing_credential_test -- --nocapture` → 13/13
4. 其余Rust测试按文件分别跑，全部0 failed
5. 构建最新Windows release DLL，确保真实FRB不使用stale DLL
6. `flutter test test/pairing_credential_repository_test.dart --timeout 3m`
7. `flutter test test/pairing_credential_ui_test.dart --timeout 3m`
8. `flutter test --timeout 3m`全量
9. `flutter analyze` 0 issues
10. FRB codegen连续两次，第二次零新增内容diff
11. Windows integration test通过
12. 清空代理启动Android模拟器，Android integration test通过
13. 真实默认NAT + `https://relay.alexc.cn`（标准443，不得`:9443`）：Windows显示/复制credential，Android只粘贴或扫码；不输入node ID、不调用mDNS；pair/connect/confirm/push/receive/import/last_seen/在线全部通过；无disposed；未执行不得声称通过
14. `.gitignore`无diff，范围合规

## 报告与流程

- executor必须实际完成后重写`.workflow/executor-report.md`，不能只返回计划或todo勾选；
- reviewer必须独立检查上述两个CRITICAL UI数据流和新增测试，重写`review-report.md`；
- build必须亲跑验收并重写`final-check.md`，标题必须含“Q3第三轮”；
- 任一真实平台未执行，报告明确未覆盖，禁止写“全部验收通过”。

## 需决策点

- mobile_scanner条件导入无法保证Windows编译；
- 重新生成无法安全终止/区分旧accept轮次；
- 真实443 relay需要修改发布默认策略；
- 平台无法启动。
