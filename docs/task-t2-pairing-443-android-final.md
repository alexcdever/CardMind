## 任务 T2：签名凭证标准 443 relay 与 Android 最终闭环

### 目标

在现有 worktree `D:/Projects/CardMind/.worktrees/signed-pairing-credential` 收尾任务 T 的真实未覆盖项。不重做协议/UI，不删除或重建 worktree。

### 已确认事实（Hermes 实机）

1. 标准 443 relay 已部署，不需要重新部署：
   - `relay.alexc.cn` DNS-only 直连 `206.237.16.164:443`；
   - nginx 监听 443；
   - nginx exact host `relay.alexc.cn` 反代 `127.0.0.1:8087`；
   - 容器 `iroh-relay-nginx` 运行，`127.0.0.1:8087 -> 3340`；
   - `https://relay.alexc.cn/` 直连 HTTP 200；
   - Let's Encrypt 证书有效；
   - 旧 `:9443` systemd relay 保留作回滚，但本任务不得用它作为标准 443 验收证据。
2. Android 之前失败是 CLI 使用错误：
   - 错误：`dart run tool/build.dart lib --target android`（把 android 当 Rust target triple）；
   - 正确完整入口：`dart run tool/build.dart app --platform android`；
   - 模拟器验收最小 Rust 构建：`cargo ndk -t x86_64 -o ../build/android-jni build --release -j 2`；
   - Hermes 已实跑 x86_64 增量构建，3.06s 成功；
   - 三 ABI首次冷构建在3分钟被外层timeout主动终止，不是编译错误。发布三 ABI构建不得无限延长，需拆 ABI/预热后逐条≤3分钟。
3. 现有 `rust-backend/tests/live_relay_test.rs` 仍硬编码 `https://relay.alexc.cn:9443` 且走旧六位码 `begin_pairing_connect`，不能证明签名凭证标准443链路。
4. 签名凭证真实入口已经存在：
   - `begin_pairing_credential`
   - `begin_pairing_connect_with_credential`
   - accept request + confirm pairing
   - 首次 push / accept / import / last_seen
5. Flutter/Rust 基线此前已通过：Flutter 124、credential 13、pairing 10、analyze、Windows receiver integration；必须保持。

### 必做 1：标准 443 签名凭证 live test

在现有 `live_relay_test.rs` 中最小升级或新增独立 ignored test，要求：

- relay 配置严格为 `https://relay.alexc.cn`，字符串不得带 `:9443`；
- 两个真实持久化 `SyncService`；
- 两端 `relay.txt` 都写标准 URL；
- confirmer 生成签名 credential；
- initiator 只拿 credential 字符串，调用 `begin_pairing_connect_with_credential`；
- initiator 不输入 node ID、不调用 mDNS；
- confirmer accept request 后 confirm；
- 验证 request 的 code/nonce 与当前 credential 会话一致；
- 首次全量 push → accept → import；
- 两边配对记录存在；
- 两边 last_seen 均为非空且在合理时间窗；
- 笔记 n1 在 initiator 可读；
- 结构化日志证明 pairing.connect transport=relay；
- 产品结构化日志不能含完整 credential、code、私钥、完整 device id或正文；
- 人工 test stdout 也不要打印完整 device id/配对码，修掉旧 live test 的敏感 println；
- confirmer、initiator 两侧及 spawned task 两侧均有内部 timeout；
- 外层测试命令 `timeout 3m`。

必须真实运行：

```bash
cd rust-backend
# 允许按 test name 只运行标准443 credential用例
timeout 3m cargo test --test live_relay_test <credential_443_test_name> -- --ignored --nocapture
```

报告必须出现真实成功证据，不能用 HTTP 200替代 iroh endpoint 链路。

### 必做 2：Android x86_64 平台 integration

- 清空大小写 `HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy`；
- 默认 NAT，不恢复 TAP；
- 启动 `medium_phone`，等待 `sys.boot_completed=1`；
- 刷新 x86_64 Rust库：

```bash
cd rust-backend
timeout 3m cargo ndk -t x86_64 -o ../build/android-jni build --release -j 2
```

- 验证 `build/android-jni/x86_64/libcardmind_backend.so` 非空且mtime为本轮；
- 运行：

```bash
flutter test integration_test/receiver_platform_test.dart -d emulator-5554 --timeout 3m
```

若 integration test 本身需要接近170秒，外层runner/平台启动时间必须拆分，单测试仍不得无限等待。输出必须证明 receiver.start + 至少两个 sync.cycle + 无 DroppableDisposedException。

### 必做 3：双端签名凭证 UI 自动化可行性

优先复用/扩展现有 integration harness，在同一测试进程无法形成两个真实 app endpoint 时，不得伪造“双端UI通过”。至少完成：

- Windows/Android 两个平台分别真实启动凭证 UI页面；
- Widget用户旅程保持：显示二维码/复制凭证、输入页只有一个主字段、粘贴/扫描统一解析、无 node ID字段；
- 如果能自动驱动两个app实例，则执行 Windows显示凭证→Android粘贴→标准443→confirm→首次sync→双方last_seen→设备页在线；
- 如果架构/自动化工具确实无法跨两个app提取并传递credential，最终报告明确写“真实双端UI未覆盖”，但 Rust 443 credential链路、Windows平台、Android平台必须分别真实通过，禁止合并陈述。

### 必做 4：最终回归

- `cargo fmt --check`
- `cargo check --tests` 0 error/0 warning
- Rust测试按文件拆分，每个命令≤3分钟，全部0 failed（ignored live除标准443指定用例）
- `flutter test --concurrency=1 --timeout 3m` 全绿
- `flutter analyze` 0 issues
- credential UI/repository测试全绿
- FRB codegen 连续两次内容级幂等
- `.gitignore` 无diff
- 还原纯CRLF/LF噪声
- `git diff -w -- rust-backend/src/debug_log.rs` 为空
- 不触碰 prototype、GitNexus/context、任务U worktree

### 范围

允许最小修改：

- `rust-backend/tests/live_relay_test.rs`
- 必要时新增/修改签名凭证 platform integration test（仅测试）
- `.workflow/executor-report.md`
- `.workflow/review-report.md`
- `.workflow/final-check.md`

除非测试暴露真实业务bug，否则禁止修改 `lib/**`、`rust-backend/src/**`、manifest、协议、UI设计；若暴露需修改业务实现，停下报告Hermes设计新任务，不就地扩大范围。

### 报告门禁

- executor、reviewer、build 三份报告标题包含“任务 T2”；
- 标准443 credential真实链路必须单列；
- Android平台integration必须单列；
- 双端UI必须明确“通过/未覆盖”，不得模糊；
- final-check非空且更新时间晚于本任务派发；
- 未满足则交付不完整。
