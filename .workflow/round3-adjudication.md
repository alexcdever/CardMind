# 任务 X Round 3 设计裁决

Hermes 真实复核结果：

- `dart analyze`：通过。
- `cargo test --test receiver_continuous_test`：14/14 通过。
- Flutter 专项：25 passed，唯一失败为 `scheduler retries revision getter after failure`（`test/sync_scheduler_test.dart:267`）。

设计方裁决：失败不是生产实现错误，也不只是等待时长。任务单明确规定“第一次 baseline 不得广播”。当启动阶段 revision getter 失败时，恢复后的第一次成功读取必须建立 baseline，不广播内容变化。因此现有测试期望恢复后的首值 `3` 产生 `[3]` 是错误的。

仅允许修改 `test/sync_scheduler_test.dart` 中该测试：

1. 启动时 getter 失败；
2. 恢复getter并设 revision=3；等待至少两个20ms轮询窗口；断言 events 仍为空，证明恢复后的首个成功值只建立baseline；
3. 再设 revision=4；等待至少两个轮询窗口；断言 events == `[4]`；
4. 断言 getter 调用次数足以证明失败后重试；
5. 不修改任何生产代码或其它测试语义。

修复后必须：

- 运行 `flutter test --timeout 3m test/sync_scheduler_test.dart test/sync_ui_widget_test.dart test/receiver_store_borrow_test.dart`；
- 运行 `dart analyze lib/bridge/sync_scheduler.dart lib/pages/note_list_page.dart test/sync_scheduler_test.dart test/sync_ui_widget_test.dart`；
- 运行 `cargo test --test receiver_continuous_test`（3分钟硬超时）；
- 运行FRB codegen两次，第二次零差异；
- 删除 `.workflow/round2-adjudication.txt`，保留本文件作为裁决证据；
- 不改 `pubspec.lock` 或平台generated plugin文件；
- 委派独立 reviewer；
- 三份 `.workflow` 报告标题含“任务 X”，如实记录Luna round1/2因上游空响应中断，以及Hermes裁决。
