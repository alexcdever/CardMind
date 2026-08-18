# 任务 X Round 4 设计裁决

## Reviewer 真实发现

Round3 reviewer 真实复验发现：FRB codegen 将 Rust `u64` getter 正确生成成 Dart `Future<BigInt>`，但生产适配层 `FrbSyncApi.receiverContentRevision()` 声明为 `Future<int>` 并直接返回该Future，导致：

```text
lib/bridge/sync_scheduler.dart:123
Future<BigInt> cannot be returned as Future<int>
```

Rust专项14/14通过；Round3测试裁决修改正确。

## 设计裁决

允许且只允许修改 `lib/bridge/sync_scheduler.dart` 的该适配方法：

```dart
@override
Future<int> receiverContentRevision() async =>
    (await api.receiverContentRevision(svc: _sync)).toInt();
```

理由：

- Rust revision是单调 `u64`，FRB生成BigInt正确；
- Scheduler内部使用Dart int；Dart native平台int可承载本任务实际revision；
- 类型转换必须放在手写适配层，禁止手改任何FRB生成文件；
- 下一次codegen不得覆盖修复。

## 限定范围

Round4新增修改只允许：

- `lib/bridge/sync_scheduler.dart` 上述方法；
- `.workflow/`任务X报告。

保留既有任务X生产实现、生成绑定和测试。禁止重建worktree、禁止改其它生产逻辑、禁止改生成文件、禁止改任务单。

## 验收

每个命令3分钟硬上限：

1. `dart analyze lib/bridge/sync_scheduler.dart lib/pages/note_list_page.dart test/sync_scheduler_test.dart test/sync_ui_widget_test.dart` → 0 issue。
2. `flutter test --timeout 3m test/sync_scheduler_test.dart test/sync_ui_widget_test.dart test/receiver_store_borrow_test.dart` → 全绿。
3. `cargo test --test receiver_continuous_test` → 14/14。
4. `flutter_rust_bridge_codegen generate` 连续执行两次；第二次对FRB生成文件零差异；手写适配转换仍存在。
5. `pubspec.lock`、platform generated plugin无变化。
6. 删除额外临时报告，只保留：
   - `.workflow/round3-adjudication.md`
   - `.workflow/round4-adjudication.md`
   - `.workflow/executor-report.md`
   - `.workflow/review-report.md`
   - `.workflow/final-check.md`
7. reviewer只读复验并返回结论；若reviewer不能写文件，由build根据reviewer原始返回代写 `.workflow/review-report.md`，不得保留旧任务W报告。
8. 三报告标题必须含“任务 X”，如实记录Round1/2/3的Luna上游空响应、Round3 reviewer FAIL和Round4修复结果。
