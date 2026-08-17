## 任务 R：签名配对测试迁移与生命周期回归收尾

这是任务 Q/Q2/Q3 的**测试迁移专用收尾任务**。设计方已逐个审计当前失败测试并完成产品契约裁决。本任务不得重新设计，不得删除worktree，不得把失败归为“旧测试冲突”后停下。

## 主仓库与现有 worktree

- 主仓库：`D:/Projects/CardMind`
- 现有 worktree：`D:/Projects/CardMind/.worktrees/signed-pairing-credential`
- 分支：`codex/signed-pairing-credential`
- 禁止删除、重建或重新创建worktree/分支。
- 开始前确认以下现有产物存在；任一缺失才停下：
  - `test/pairing_credential_ui_test.dart`（10个测试）
  - `test/pairing_credential_repository_test.dart`（4个测试）
  - `rust-backend/tests/pairing_credential_test.rs`（13个测试）
  - `lib/pages/devices_page.dart` 含 `pair-credential-input` 且不含生产UI `pair-peer-id-input`
  - `lib/scanner/`

## 设计方影响分析

改动符号/行为面：

- `DevicesPage._showMyCode`
- `_PairingAcceptDialog`生命周期
- `DevicesPage._enterPeerCode`
- `DevicesPage._connectWithSixDigitCode`
- 配对结构化日志事件
- 6个旧Flutter测试文件的配对断言

风险：MEDIUM。配对页及测试会受影响；笔记、回收站、同步receiver、relay默认策略不应受影响。

GitNexus runner本轮因npm registry `ECONNRESET`未能完成自动impact调用；已通过源码调用面和全部旧UI锚点进行人工逐项审计。不得借此扩大范围。

## 已验证基线

设计方实跑：

- `pairing_credential_test`：13/13通过
- `pairing_credential_repository_test.dart`：4/4通过
- `pairing_credential_ui_test.dart`：10/10通过
- `flutter analyze`：0 issues
- Flutter全量：约107通过、16个旧UI失败；另真实FRB慢测试在整套外层180秒时被累计运行时间截断

## 测试执行纪律修正

原计划把整个 `flutter test` 外层包 `timeout 3m` 是错误的：套件累计耗时会超过3分钟，而这不代表单个测试挂死。

本任务固定：

- `flutter test --timeout 3m`：Dart参数是**每个测试用例**3分钟上限；全套命令外层最多10分钟，仅用于防runner整体失控。
- 真实FRB慢文件（`pairing_repository_test.dart`、`receiver_store_borrow_test.dart`、`pairing_credential_repository_test.dart`）单文件执行，每个测试用例仍 `--timeout 3m`。
- 纯Widget测试可合并运行，每个用例 `--timeout 3m`，外层5分钟。
- Rust每个测试文件命令外层3分钟；网络spawn两侧继续使用tokio timeout。

## 产品契约（不得自行改变）

### A. 输入路径

1. `cm1...` 凭证：直接调用 `beginPairingConnectWithCredential`；不得调用mDNS；不得暴露节点ID字段。
2. 纯6位数字：调用mDNS；唯一结果必须带device ID、IP/port和nonce，再调用 `beginPairingConnect`。
3. mDNS无结果：友好提示检查同一网络，不再提示“手动填写节点ID”。
4. mDNS多结果：提示无法自动确定，请改用二维码/复制配对信息；不得提示手动节点ID。
5. 手动节点ID路径已从产品删除；对应旧测试不得保留该行为，应迁移为凭证路径。

### B. 显示与生命周期

1. 显示方调用 `beginPairingCredential` 组合API生成credential并启动广播。
2. credential生成成功后才启动单个bounded accept。
3. 关闭/取消后必须调用 `stopPairingAdvertising`；已完成的旧accept返回后不得confirm/setState。
4. 重新生成不得并发两个accept loop，不得用旧code confirm。
5. accept失败/超时后停止广播并显示友好错误。
6. 配对成功刷新设备列表并显示成功提示。

### C. 日志契约（必须保留）

生产代码不得因UI重构丢失以下结构化事件：

```text
pairing.show_code action=start
pairing.show_code action=success
pairing.show_code action=cancelled（用户关闭且未配对）
pairing.advertise action=start
pairing.advertise action=stop ok=true|false
pairing.accept action=start|timeout|failed
pairing.request action=received
pairing.confirm action=start|success|failed
pairing.discovery action=start|result|failed（仅6位码mDNS路径）
pairing.discovery action=bypassed mdns_skipped=true（仅cm1凭证路径；不得记录完整凭证/node ID）
pairing.connect action=start|success|failed transport=credential|direct|relay_or_dns
```

- cm1凭证路径应记录 `pairing.discovery=bypassed`，替代已删除的“手动ID bypass”日志。
- cm1连接transport使用稳定值`credential`；真实Rust层仍可另记relay。
- 6位码+mDNS有IP时transport=`direct`；无IP但有合法nonce时=`relay_or_dns`。
- 凭证、code、nonce、签名和完整node ID不得进入日志。

## 旧失败用例逐项迁移表

### `test/pairing_accept_ui_test.dart`

1. `cancel stops advertising and accept task`：**保留测试名与契约**。更新fake的`beginPairingCredential`为组合生成+advertisingStarted；操作新显示凭证弹窗；断言关闭后stop=true、延迟返回请求不confirm、无setState异常。
2. `manual relay pairing UI path`：**重命名为** `credential relay pairing UI path`。输入`cm1...`到`pair-credential-input`；断言credentialConnectCalls=1、discoverCalls=0、旧beginPairingConnect=0、无node ID控件、成功提示。
3. 该文件其它显示方测试：API计数从旧`beginPairingAccept*`迁到`beginPairingCredential`；仍断言accept时序、confirm code、刷新、超时、重开不叠加。

### `test/pairing_log_events_test.dart`

1. `manual pairing emits discovery-bypass event`：**重命名为** `credential pairing emits discovery-bypass event`；输入cm1；断言bypassed/mdns_skipped=true、discoverCalls=0；不得断言/记录目标完整ID。
2. `mdns discovery emits count and duration`：保留；改用`pair-credential-input`输入6位码；PeerInfo必须使用非空合法nonce。
3. `pairing accept lifecycle emits all stages`：保留；fake `beginPairingCredential`；生产代码如缺show_code/advertise/request/confirm事件则修复生产代码，不得删除断言。
4. `pairing show-code cancel emits cancelled event`：保留；如生产代码缺cancelled/advertise stop日志则修复。
5. `connect failure emits transport and error chain`：保留6位码+mDNS direct路径；使用新输入key和非空nonce。
6. `connect with empty ips records relay_or_dns transport`：保留6位码+mDNS路径；PeerInfo ip为空、nonce非空；不得用手动ID。
7. logger failure测试保留；fake request nonce必须与credential会话一致。

### `test/pairing_mdns_widget_test.dart`

1. `test_regression_empty_device_id_user_path`：**重命名为** `six digit input with no mdns result shows friendly error`；新单输入框输入6位；断言无node ID控件、discover=1、connect=0、友好提示。
2. `confirmer advertises while showing code`：保留；计数改为credentialCalls，断言组合API和stop。
3. `requester auto-fills device id via mdns`：保留产品行为但更新描述为 `six digit input uses unique mdns target and nonce`；新输入key；断言target的deviceId/IP/nonce均来自PeerInfo。
4. `requester shows friendly error when mdns finds nothing`：保留；新输入key；文案不得含“手动填写”。
5. `requester uses manual device id when provided`：**删除该旧行为用例并替换为** `credential input bypasses mdns without node id field`；断言credentialConnect=1、discover=0、没有节点ID控件。
6. `requester shows guidance when multiple mdns devices found`：保留；新输入key；新文案引导二维码/复制配对信息，不引导手动ID。
7. 所有PeerInfo使用有效非空nonce，除非测试“旧TXT无nonce应拒绝”，该协议测试已在Rust覆盖，不在Widget重复。

### `test/sync_ui_widget_test.dart`

`pairing flow shows code and accepts input`：拆成同一测试内两个现代路径：

- 显示方断言`beginPairingCredential`调用、二维码/复制/6位码出现；
- 发起方输入cm1，断言credentialConnect调用且不discover；
- 不再断言旧`beginPairingAccept`或节点ID输入。

### `test/mobile_ui_test.dart`

若失败来自fake未实现新credential API：补fake返回稳定`PairingCredentialDisplay`与bounded accept；保留移动布局断言。不得恢复旧UI。

### `test/vertical_slice_widget_test.dart`

若失败来自fake未实现新credential API或旧key：更新fake/锚点到credential流程；保留原垂直切片目的。不得删除非配对测试。

### `test/pairing_repository_test.dart`

1. `repository pair flow pairs two devices and syncs notes`：生产协议已强制nonce；测试不得构造空/全零nonce。改为通过`beginPairingCredential`解析得到code/node ID/nonce，或从当前session/mDNS公开入口取得nonce，然后完成真实配对。
2. `bounded accept times out through FRB bridge`：单文件单独执行，`--timeout 3m`；不得与全部Widget并行造成累计超时。若单独仍超过3分钟，停下查根因，不提高上限。

## 先红后绿的验收测试

executor开始时先执行并报告真实红结果：

1. 纯Widget旧文件批次：

```bash
flutter test \
  test/pairing_accept_ui_test.dart \
  test/pairing_log_events_test.dart \
  test/pairing_mdns_widget_test.dart \
  test/sync_ui_widget_test.dart \
  test/mobile_ui_test.dart \
  test/vertical_slice_widget_test.dart \
  --timeout 3m
```

必须先复现当前旧契约失败，不得先改后测。

2. 单跑真实FRB：

```bash
flutter test test/pairing_repository_test.dart --timeout 3m
```

记录真实结果；如果是nonce失败，按上表修；如果单测试真超时，停下查接收生命周期。

## 绿阶段验收

1. 上述6个Widget文件批次全部通过。
2. `pairing_repository_test.dart`单文件全部通过。
3. `pairing_credential_ui_test.dart` 10/10通过。
4. `pairing_credential_repository_test.dart` 4/4通过。
5. `receiver_store_borrow_test.dart`单文件通过。
6. 纯Dart/Widget其余测试（排除3个真实FRB慢文件）全部通过。
7. 全套：

```bash
# 每测试用例3分钟；外层runner最多10分钟，不是3分钟
# Windows git-bash:
timeout 10m flutter test --timeout 3m
```

输出0 failed。若全套因并发FRB资源竞争失败，但所有分组单跑通过：不得直接声称全绿；先用`flutter test --concurrency=1 --timeout 3m`外层10分钟复跑确认。

8. `flutter analyze` 0 issues。
9. Rust：`cargo fmt --check`、`cargo check --tests`无warning、`pairing_credential_test`13/13；移除`PairingCredentialErrorKind` unused import。
10. FRB codegen无需再次修改API；若运行，连续两次第二次零内容diff。

## 平台验收边界

本任务R聚焦测试迁移与生产生命周期日志修复。完成绿阶段后必须执行：

- Windows integration test；
- 清代理Android integration test；
- 真实默认NAT + `https://relay.alexc.cn`凭证配对。

如果平台环境不可用，允许报告“未覆盖”，但不得写“全部验收通过”。Hermes后续仍会独立做平台终验。不得修改发布默认relay策略。

## 改动范围

允许：

- `lib/pages/devices_page.dart`（仅日志/生命周期缺口）
- 上述7个旧测试文件
- `test/pairing_credential_ui_test.dart`/repository测试（仅共享fake/断言修正）
- `rust-backend/src/api.rs`仅清unused import
- `.workflow/*.md`重写

禁止：

- 重做凭证二进制协议
- 放松nonce
- 修改relay默认策略、笔记/同步数据模型、prototype、`.gitignore`
- 修改context/gitnexus文件

## 报告与审核

- executor重写`executor-report.md`，附红阶段与每组绿阶段真实输出。
- reviewer逐项核对本迁移表，特别检查没有通过删除有价值测试来“变绿”。
- build复跑分组和全套测试，`final-check.md`标题必须含“任务R测试迁移”。
- 完整性要求：最终报告必须明确列出16个旧失败用例对应的新测试名/状态，以及平台验收是否覆盖。
