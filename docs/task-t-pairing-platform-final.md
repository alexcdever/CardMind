## 任务 T：配对凭证格式、Codegen、平台终验与最终报告

这是任务Q→S的最小收尾任务。使用现有worktree：

- `D:/Projects/CardMind/.worktrees/signed-pairing-credential`
- 分支：`codex/signed-pairing-credential`
- 禁止删除/重建worktree；禁止重做协议/UI/测试迁移。

## 已通过基线（不得回退）

- Flutter全套：124/124
- 迁移相关Flutter：37/37
- Rust credential：13/13
- Rust discovery：2/2
- 真实FRB repository：`localAddrs + parsed nonce`直连通过
- discovery nonce恢复
- 16个旧失败迁移PASS
- `flutter analyze`通过

## 设计裁决1：允许debug_log.rs纯rustfmt

当前全仓`cargo fmt -- --check`仅因基线`rust-backend/src/debug_log.rs:173`长行失败。设计方明确允许：

```bash
cargo fmt
```

保留`debug_log.rs`由rustfmt产生的纯格式变化，使全仓格式基线一致。不得改其行为、日志字段或脱敏逻辑。格式化后：

- `git diff -w -- rust-backend/src/debug_log.rs`必须为空；
- `cargo fmt --check`必须通过。

## 设计裁决2：使用全局FRB codegen命令

机器已确认：

```text
flutter_rust_bridge_codegen 2.12.0
```

正确命令：

```bash
cd D:/Projects/CardMind/.worktrees/signed-pairing-credential
flutter_rust_bridge_codegen generate
```

不得使用`dart run flutter_rust_bridge_codegen`。

连续执行两次：

1. 第一次生成后记录内容级diff；
2. 第二次生成后内容级diff与第一次完全一致，零新增变化；
3. 还原所有`--ignore-cr-at-eol`为空的纯行尾噪声；
4. 保留真实FRB API生成变化。

## 设计裁决3：平台终验

### Windows

运行：

```bash
flutter test integration_test/receiver_platform_test.dart -d windows --timeout 3m
```

若该测试不覆盖credential UI，不得声称Windows凭证UI全流程，只报告它真实覆盖的Store/receiver生命周期。

### Android

当前模拟器未启动，但有AVD。必须：

1. 清空`HTTP_PROXY/HTTPS_PROXY/ALL_PROXY`大小写变量；
2. 启动`medium_phone`默认NAT，不使用TAP；
3. 等待boot_completed；
4. 运行Android integration test；
5. 不允许模拟器继承`127.0.0.1:2333`。

### 真实标准443 relay

测试relay URL固定：

```text
https://relay.alexc.cn
```

不得使用`:9443`。

优先执行两端真实app UI：Windows生成credential，Android只粘贴/扫码；不输入node ID、不调用mDNS；验证connect/confirm/push/receive/import/last_seen/在线。

如果无法自动驱动完整UI，至少执行真实Rust两个endpoint经443 relay的credential配对与首次同步测试；报告必须准确区分：

- Rust真实443 relay链路；
- Windows平台integration；
- Android平台integration；
- 双端UI手工/自动验收是否覆盖。

禁止把Rust测试通过冒充双端UI通过。

## 最终回归

1. `cargo fmt --check`
2. `cargo check --tests`：0 error、0 warning
3. 每个Rust测试文件外层3分钟，全部0 failed
4. `timeout 10m flutter test --concurrency=1 --timeout 3m`：124/124或更多
5. `flutter analyze`：0 issues
6. credential UI/repository单独测试继续通过
7. FRB codegen幂等
8. `.gitignore`无diff；无prototype/context/gitnexus改动；纯行尾噪声还原
9. `git diff -w -- rust-backend/src/debug_log.rs`为空

## 报告与交付门禁

- executor重写`executor-report.md`；
- reviewer独立复验；
- build写`final-check.md`，标题必须包含“任务T平台终验”；
- final-check必须含：
  - `cargo fmt`裁决结果
  - `flutter_rust_bridge_codegen 2.12.0`连续两次结果
  - Windows平台状态
  - Android平台状态
  - `https://relay.alexc.cn`标准443结果
  - 双端UI是否实际覆盖
  - 16个旧失败迁移仍PASS
- 平台未覆盖项明确写“未覆盖”，禁止“全部验收通过”。

## 需决策点

仅以下情况停下：

1. rustfmt除`debug_log.rs`格式外改变业务语义；
2. codegen第二次仍产生内容变化；
3. Android模拟器无代理环境仍无法联网；
4. 443 relay真实Rust链路失败；
5. 必须恢复TAP或修改发布默认relay策略。
