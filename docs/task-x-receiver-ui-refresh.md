# 任务 X：receiver 入站同步后实时刷新笔记列表

## 背景与真实缺陷证据

2026-08-18 在两个独立应用进程完成真实 relay E2E：

- Windows Release App 与 Android 模拟器 App 均使用 `https://relay.alexc.cn` 标准 443 relay；
- Android 通过完整签名 `cm1` 凭证配对，日志：`pairing.discovery mdns_skipped=true`、`pairing.connect transport=credential action=success duration_ms=290`；
- 两端设备页均显示对方“在线”，`paired_devices` 持久化且 `last_seen` 更新；
- Windows UI 创建并保存笔记 `E2E Relay 20260818-1033`；
- Android 的 `cardmind.loro` 与 `cardmind.db` 均更新，数据库中已存在该笔记；
- 但 Android 当前 NoteListPage 仍显示“还没有笔记”，切换“设备 → 笔记”也不刷新；
- force-stop 后重新启动 Android App，笔记立即出现。

根因：Rust 后台 receiver 已完成 `route → import_core_all → sync_core_to_store → update_last_seen`，但 Dart `SyncScheduler` 仅广播 `pendingCountChanges`；`NoteListPage` 只更新待同步数字，未订阅入站内容变化，也没有重新调用 `_loadNotes()`。

## 主仓库与 worktree

- 主仓库：`D:/Projects/CardMind`
- 基线分支：`codex/knowledge-base`
- worktree：`D:/Projects/CardMind/.worktrees/receiver-ui-refresh`
- worktree 分支：`codex/receiver-ui-refresh`
- worktree 已存在时禁止删除/重建，先检查现有产物。

## 设计契约

### Rust 内容投影版本

1. `SyncService` 新增 `Arc<AtomicU64>`（命名遵循代码语义，如 `content_revision`），`ReceiverContext` clone 同一 Arc。
2. 初始值为 0。
3. 只有后台 receiver 完整成功执行以下链路后递增一次：
   `import_core_all` 成功 → `sync_core_to_store` 成功 → `update_last_seen` 成功。
4. 配对帧、空闲窗口、import失败、SQLite投影失败、last_seen失败均不得递增。
5. 使用 `fetch_add(1, Ordering::Release)`；getter 使用 `load(Ordering::Acquire)`。
6. 暂不把本地编辑、主动push、纯last_seen变化计入内容版本；这个版本只代表当前进程后台receiver成功投影了新的入站内容。
7. 不把正文、完整设备ID或凭证写入日志。

### FRB API

一次性加入并生成完整API：

```rust
pub fn receiver_content_revision(svc: &SyncService) -> u64
```

运行 `flutter_rust_bridge_codegen generate`，提交Rust/Dart生成绑定。不得手改生成文件。

### Dart Scheduler

1. `SyncApi` 新增 `Future<int> receiverContentRevision()`；`FrbSyncApi`调用生成getter。
2. `SyncScheduler`新增广播流 `Stream<int> contentChanges`。
3. scheduler启动时读取一次版本作为baseline，然后以300ms间隔轻量轮询getter；仅版本发生变化时广播新版本。不得每300ms查询SQLite或调用`listNotes()`。
4. 第一次baseline不得广播，避免启动时无意义重复刷新。
5. 相同版本不重复广播；版本跳跃只需广播最新值一次。
6. getter失败静默，下次轮询重试；不得停止receiver或周期同步。
7. `stop/dispose`取消版本轮询Timer并关闭内容流；dispose后不得广播。
8. 现有60秒同步周期、receiver 300ms accept窗口和pendingCount流语义保持不变。

### NoteListPage

1. 订阅 `contentChanges`；收到后立即重新加载笔记列表。
2. 合并并发刷新：若 `_loadNotes()` 正在运行，记录一次“需要再次刷新”，当前加载完成后最多再执行一次，禁止无限并发查询/闪烁。
3. 页面dispose取消订阅；dispose后不得setState。
4. 搜索进行中收到内容变化时，重新执行当前搜索查询或清晰地刷新搜索结果，不能显示过期结果。
5. 移动端和桌面端共用该逻辑。
6. 不通过页面切换、生命周期重建或App重启作为刷新机制。

## TDD与验收标准

所有测试单命令3分钟硬超时。executor必须红-绿-蓝并在报告记录红阶段真实失败输出。

### 1. 红阶段：复现本次真实UI缺陷

文件：`test/sync_ui_widget_test.dart`

用例名：`receiver projected inbound note refreshes visible list without app restart`

- 首次 `DevicesRepository.listNotes()` 返回空，NoteListPage显示“还没有笔记”；
- 模拟receiver已经把一篇入站笔记投影到repository；
- 在没有重建widget、没有切页、没有重新启动App的情况下触发scheduler内容版本变化；
- 修复前断言标题出现必须失败；executor先运行并记录红输出；
- 修复后300ms轮询+UI刷新完成，标题出现且空状态消失。

### 2. Scheduler版本变化流

文件：`test/sync_scheduler_test.dart`

至少加入：

- `scheduler baselines receiver revision without initial content event`
- `scheduler emits once when receiver revision changes`
- `scheduler coalesces revision jump and ignores duplicates`
- `scheduler retries revision getter after failure`
- `scheduler stop and dispose cancel revision polling`

FakeSyncApi明确可控制revision和抛错。测试不得真实等待60秒；使用可注入poll interval/时钟或最多1秒有界等待。

### 3. NoteListPage刷新生命周期

文件：`test/sync_ui_widget_test.dart`

至少覆盖：

- receiver版本变化后立即加载新笔记；
- 快速连续版本变化不会并发无限调用`listNotes`，但最终状态不丢；
- widget dispose后再广播不调用repository、不抛setState after dispose；
- 搜索状态下入站内容变化后结果更新。

### 4. Rust版本递增语义

文件：`rust-backend/tests/receiver_continuous_test.rs`

至少覆盖：

- 初始revision=0；
- 配对/空闲不递增；
- 一次真实push经receiver import+投影成功后revision恰好+1；
- 第二次push再+1；
- import/投影失败不递增；
- receiver重复start不重置revision。

所有spawn两侧和网络操作均用`tokio::time::timeout`。

### 5. 真实FRB边界

新增或扩展：`test/receiver_store_borrow_test.dart`

- 真实RustLib、SyncService、NoteStore；
- getter通过生成FRB绑定读取；
- receiver接收真实push后Dart可观察revision递增；
- Store不disposed，原任务P回归继续通过。

### 6. 生成绑定幂等

```bash
flutter_rust_bridge_codegen generate
git diff --exit-code -- rust-backend/src/frb_generated.rs lib/src/rust
```

第二次生成零差异。

### 7. 专项与全量

```bash
dart format --output=none --set-exit-if-changed lib test integration_test tool
cd rust-backend && cargo fmt --all -- --check
cd rust-backend && timeout 3m cargo test --test receiver_continuous_test
flutter test --timeout 3m test/sync_scheduler_test.dart test/sync_ui_widget_test.dart test/receiver_store_borrow_test.dart
flutter analyze
```

Rust全量按测试文件拆分，每命令3分钟；Flutter全量`flutter test --concurrency=1 --timeout 3m`。

### 8. Windows/Android平台测试

扩展 `integration_test/receiver_platform_test.dart` 或新增明确文件：

- Windows和Android模拟器分别真实启动；
- receiver revision getter可读取；
- 测试必须在3分钟内完成，不再等待两个60秒周期；
- 不把单平台测试冒充双实例E2E。

### 9. 最终真实双独立进程relay E2E

由Hermes合并后执行，不由fake替代：

- 全新/备份隔离的数据目录；
- Windows显示凭证，Android输入完整cm1；
- 两端显示在线；
- Windows UI保存唯一标题笔记；
- Android receiver在10秒内数据库落库；
- **不重启App、不切换重建页面**，Android当前NoteListPage在10秒内出现标题；
- 双方last_seen更新；
- 脱敏日志无正文/完整ID/凭证。

## 改动范围

允许：

- `rust-backend/src/sync.rs`
- `rust-backend/src/api.rs`
- FRB生成文件
- `lib/bridge/sync_scheduler.dart`
- `lib/pages/note_list_page.dart`
- 上述专项测试/平台测试
- `.workflow/`报告

禁止：

- 配对协议、凭证格式、relay默认配置
- 数据库schema、Loro envelope格式
- UI视觉重设计
- 其它业务功能
- 主仓库未提交文件和其它worktree

## 需决策点

遇到以下情况停止报告，不自行决定：

- 版本getter轮询在目标平台有明显性能/生命周期问题；
- 必须修改数据库schema或同步协议；
- 无法在10秒内实现UI刷新而需要放宽验收；
- 真实FRB绑定必须使用stream/callback而非getter轮询；
- 任一测试单进程超过3分钟。
