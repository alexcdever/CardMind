# Executor 自检报告 — CardMind 修复任务 C（数据目录迁移）

- worktree: `D:/Projects/CardMind/.worktrees/fix-data-dir`（分支 `codex/fix-data-dir`）
- 执行代理: executor（deepseek-v4-flash）
- 日期: 2026-08-14

## 完成内容

任务单要求：将 `lib/bridge/bridge_helper.dart:24` 的数据目录来源从 `getApplicationDocumentsDirectory()`（Windows 解析为 `C:\Users\<user>\Documents`）改为 `getApplicationSupportDirectory()`（Windows 上为 `%APPDATA%\com.cardmind\cardmind`；Android 上两者等价）。旧数据已删除，不做迁移、不做兼容回退。

### 改动文件清单与 diff 摘要

仅改 1 个文件，共 1 行：

```
lib/bridge/bridge_helper.dart | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

```diff
--- a/lib/bridge/bridge_helper.dart
+++ b/lib/bridge/bridge_helper.dart
@@ -21,7 +21,7 @@ class BridgeHelper implements NoteRepository {
   ///
   /// Call once after [RustLib.init] in main.dart.
   Future<void> init() async {
-    final dir = await getApplicationDocumentsDirectory();
+    final dir = await getApplicationSupportDirectory();
     _repository?.close();
     _repository = await FrbNoteRepository.open(dataDirectory: dir.path);
   }
```

- `test/` 目录：**无需改动**。全库搜索 `getApplicationDocumentsDirectory|getApplicationSupportDirectory` 仅命中 `lib/bridge/bridge_helper.dart:24` 一处，现有测试无任何 Documents 路径断言。
- `init()` 方法签名、调用方（`lib/main.dart` 的 `BridgeHelper().init()`）均不受影响。

### 环境补齐（非代码改动，已 gitignore）

worktree 首次 `flutter test` 失败于 `RustLib.init()` 加载 `cardmind_backend.dll`（error code 126，找不到模块）。这是 worktree 缺构建产物所致，非本改动引入。补齐方式（只写入了 gitignore 的产物路径，不触碰任何受跟踪文件）：

1. `build/windows/x64/runner/Release/cardmind_backend.dll`（首次放置，实际 loader 不从这里读）
2. `rust-backend/target/release/cardmind_backend.dll`（**真正生效位置**——`frb_generated.dart` 的 `ioDirectory: 'rust-backend/target/release/'`）

## 验收标准逐条结果

### 验收标准 1：`flutter pub get && flutter test` — ✅ 通过

真实输出（节选，完整输出在下方要点）：

```
$ flutter pub get
Got dependencies!
20 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.

$ flutter test
00:04 +44: D:/Projects/CardMind/.worktrees/fix-data-dir/test/vertical_slice_widget_test.dart: CardMindApp injects the repository into its workspace
00:04 +45: All tests passed!
```

- 测试总数：**45 个，全部通过**（`+45`，`All tests passed!`），与任务单"现有 45 个测试不回归"一致。
- 覆盖文件：api_integration_test、build_tool_test、frb_note_repository_test、knowledge_base_widget_test、mobile_ui_test、vertical_slice_widget_test、widget_test。

注：首次执行因缺 dll 出现 `+35 -2`（api_integration_test / frb_note_repository_test 的 setUpAll 失败），补齐 `rust-backend/target/release/cardmind_backend.dll` 后全部通过。此失败与本任务改动无关。

### 验收标准 2：`flutter analyze` — ✅ 通过

真实输出：

```
$ flutter analyze
Analyzing fix-data-dir...
No issues found! (ran in 19.7s)
```

- 无 error、无 warning、无 info。

### 验收标准 3：`git status` — ✅ 通过（改动全在允许范围内）

真实输出（还原 flutter pub get 工具副作用后）：

```
$ git status --short
 M lib/bridge/bridge_helper.dart

$ git diff --stat
 lib/bridge/bridge_helper.dart | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)
```

- 仅 `lib/bridge/bridge_helper.dart` 一个受跟踪文件被改动，符合改动范围（`lib/bridge/bridge_helper.dart` + `test/`，后者无需改动）。
- `rust-backend/`、`lib/src/rust/`、`docs/`、`prototype/`、`.gitignore`、`lib/` 其余文件均未改动。
- 说明：`flutter pub get` 每次运行会自动改写 `analysis_options.yaml`（追加 analyzer exclude）和 `linux|windows/flutter/generated_plugin_registrant.*` 等 7 个文件——这是 flutter 工具副作用（仓库历史 commit `995049bf` 有同款回退先例），不属于本任务改动，验收命令跑完后已 `git checkout --` 还原，最终 status 干净。

## 未决问题

无。未遇到需决策点（测试失败原因均为 worktree 缺构建产物，补齐后通过，不属于"目录 API 变化导致测试失败"；无需改动 rust-backend）。
