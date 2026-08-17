## 任务 S：配对凭证最终一致性裁决与验收

这是任务R停在设计冲突后的继续单。使用现有worktree：

- `D:/Projects/CardMind/.worktrees/signed-pairing-credential`
- 分支：`codex/signed-pairing-credential`
- 禁止删除/重建worktree，禁止回退已通过的任务Q/R产物。

## 已验证且必须保留

- 6个旧Widget文件迁移批次：54/54通过；
- credential UI + repository：14/14通过；
- Rust credential：13/13通过；
- `flutter analyze`通过；
- 生产UI无`pair-peer-id-input`；
- 强制nonce，不允许空/全零绕过。

## 设计裁决1：恢复discovery nonce前置产物

Reviewer把`rust-backend/src/discovery.rs`视为任务R越界并回退，导致现有`sync.rs`、`api.rs`、FRB生成代码无法编译。该判断错误。

`discovery.rs` nonce是任务Q协议的合法前置产物，必须恢复并保留：

```rust
pub struct PeerInfo {
    pub device_id: String,
    pub ip: String,
    pub port: u16,
    pub nonce: String,
}

pub fn start_advertising(
    &mut self,
    device_id: &str,
    port: u16,
    nonce: &str,
) -> Result<()>
```

行为：

- TXT写入`nonce`；
- discover解析`nonce`；
- 旧TXT缺nonce时返回空字符串（仅用于识别并由严格配对校验拒绝，不是绕过）；
- `sync.rs`组合API使用当前session nonce广播；
- `api.rs`和FRB生成字段保持一致。

恢复后执行`cargo fmt`与FRB codegen，禁止通过回退`sync.rs/api.rs/frb_generated`来取消nonce协议。

## 设计裁决2：真实FRB本地测试使用credential身份材料 + localAddrs直连

任务R要求`pairing_repository_test.dart`调用`beginPairingConnectWithCredential`，但测试中的两个内存/临时repository默认relay disabled，credential只有node ID和nonce，没有IP，故必然报：

```text
No addressing information available
```

这不是产品credential入口失败，而是离线本地测试没有寻址信息。固定迁移方式如下，不得自选：

```text
repoA.beginPairingCredential()
→ repoB.parsePairingCredential(display.credential)
→ 断言code/deviceId/nonce
→ repoA.localAddrs()取得真实IP:port（必须非空）
→ PairingTarget(
     deviceId: parsed.deviceId,
     ips: addrsA,
     nonce: parsed.nonce,
   )
→ repoB.beginPairingConnect(parsed.code, target)
→ repoA bounded accept + confirm
→ 首次push/receive/import
→ 双方持久化和笔记断言
```

该测试仍真实验证：

- credential签名解析；
- credential内node ID/code/nonce；
- 严格nonce网络握手；
- 双repository真实FRB配对；
- 首次同步。

credential-only入口“禁止mDNS并使用内嵌node ID”由以下既有测试覆盖，禁止重复强迫离线测试走无地址连接：

- Rust `credential_connect_uses_embedded_node_id_without_mdns`
- `pairing_credential_repository_test.dart` fake/observable路径
- 最终真实443 relay平台验收

## 设计裁决3：测试名称与注释清理

任务R迁移后测试体已通过，但仍残留误导名称/注释：

- `manual pairing emits discovery-bypass event`
- `requester uses manual device id when provided`
- `manual relay pairing UI path`
- 顶部“手动ID路径”说明

必须重命名/改注释为credential语义，测试体不得恢复手动节点ID：

- `credential pairing emits discovery-bypass event`
- `credential input bypasses mdns without node id field`
- `credential relay pairing UI path`

允许保留`pair-code-input`/`pair-peer-id-input`字符串的唯一情况：新UI测试中的`findsNothing`负向断言。生产代码和正向测试操作不得使用旧key。

## 设计裁决4：范围与生成噪声

合法前置产物范围包括：

- `rust-backend/src/discovery.rs`
- `rust-backend/src/sync.rs`
- `rust-backend/src/api.rs`
- FRB生成文件
- 配对相关bridge/UI/scanner/manifest/dependencies/tests

`rust-backend/src/debug_log.rs`仅当credential日志脱敏实现确有内容变更时保留；否则还原。Linux/Windows Flutter plugin registrant文件如果是新增扫码插件所需的真实生成变化可保留；若`git diff --ignore-cr-at-eol`为空则还原纯行尾噪声。不得一概回退生成文件导致插件缺失。

## TDD与验收

### 红阶段

先记录当前真实红：

1. `cargo check --tests`：因`discovery.rs`缺nonce产生6个编译错误；
2. `flutter test test/pairing_repository_test.dart --timeout 3m`：`No addressing information available`/accept超时。

报告必须保留这两段红输出。

### 绿阶段

1. `cargo fmt --check`。
2. `cargo check --tests`：0 error、0 warning。
3. `timeout 3m cargo test --test pairing_credential_test -- --nocapture`：13/13。
4. `timeout 3m cargo test --test discovery_test -- --nocapture`：全绿，覆盖nonce TXT roundtrip和旧TXT空nonce解析。
5. `flutter test test/pairing_repository_test.dart --timeout 3m`：单文件全部通过，不能再出现寻址/nonce/超时。
6. 6个迁移Widget文件批次：54/54或更多，0 failed。
7. credential UI/repository批次：14/14或更多，0 failed。
8. `receiver_store_borrow_test.dart`单文件通过。
9. `flutter analyze`：0 issues。
10. 全套Flutter：

```bash
timeout 10m flutter test --concurrency=1 --timeout 3m
```

0 failed。这里3分钟是每个测试用例上限，外层10分钟只防runner整体失控。
11. Rust其余测试按文件分别执行，每文件外层3分钟，全部0 failed。
12. FRB codegen连续两次，第二次零内容diff。
13. `git diff -- .gitignore`为空；无prototype/context/gitnexus改动；纯行尾噪声还原。
14. 全仓搜索：旧手动ID测试名/注释为0；旧UI key仅负向`findsNothing`断言。

## 平台验收

代码/测试绿后执行：

1. Windows integration test；
2. 清空代理启动Android模拟器并运行integration test；
3. 真实默认NAT + `https://relay.alexc.cn`标准443：Windows生成credential，Android只粘贴/扫码，不输入node ID、不调用mDNS；connect/confirm/push/receive/import/last_seen/在线通过。

若平台环境不可用，报告必须明确“未覆盖”，禁止写全部验收通过；但不得因此回退已绿代码。

## 流程与报告

- executor在原worktree实现，重写`executor-report.md`，附两项红输出与绿结果；
- reviewer独立复验，不得再次把`discovery.rs`判为越界；
- build亲跑关键验收并写`final-check.md`，标题必须包含“任务S最终一致性”；
- final-check必须明确：16个旧失败迁移状态、真实FRB寻址裁决、discovery nonce恢复、平台覆盖状态。

## 需决策点

仅以下情况停下：

1. `localAddrs()`在两个真实repository实例中返回空列表；
2. 带localAddrs和parsed nonce仍无法直连；
3. 恢复discovery nonce后FRB codegen产生无法解释的协议不一致；
4. 需要放松nonce或修改relay默认策略。
