# review-report — log-dir-load-failure-state

- 审查角色：独立审查子代理（只读，未修改 worktree 任何文件，未提交）
- 审查时间：2026-09-28
- worktree: `/Users/alexc/Projects/CardMind/.worktrees/log-dir-load-failure-state`
- branch: `pipeline/log-dir-load-failure-state`
- HEAD: `521a8c5411b62c6aa711dadfee9fc9ff27b39f72`

## 0. 审查前工作区状态（原始）

```
$ git rev-parse HEAD
521a8c5411b62c6aa711dadfee9fc9ff27b39f72
$ git branch --show-current
pipeline/log-dir-load-failure-state
$ git diff --name-only
lib/pages/settings_page.dart
test/settings_page_test.dart
$ git status --porcelain
 M lib/pages/settings_page.dart
 M test/settings_page_test.dart
?? .pipeline/log-dir-load-failure-state/
$ git diff | shasum -a 256
f881b93cb99e8c7a001134bf5da852e88fbc3e53bb535483f72204361a239084  -
```

工作区 diff 哈希 `f881b93c…` 在审查全程保持恒定（审查前后多次核对一致）。**审查结束时工作区与审查开始时逐字节相同**（见第 3 节末）。

## 1. diff 范围 — PASS

命令与原始输出：

```
$ git diff --name-only HEAD
lib/pages/settings_page.dart
test/settings_page_test.dart
$ git diff --name-only            # 无 HEAD 参数，同结果
lib/pages/settings_page.dart
test/settings_page_test.dart
$ git diff --cached --name-only
(空 —— 无任何 staged 内容)
$ git diff --name-status HEAD
M	lib/pages/settings_page.dart
M	test/settings_page_test.dart
$ git ls-files --others --exclude-standard
.pipeline/log-dir-load-failure-state/executor-report.md
```

`lib/bridge/debug_log.dart` 与 `resolveLogDirectory` 是否被触碰：

```
$ git diff --stat HEAD -- lib/bridge/debug_log.dart
(空输出 —— 零改动)
$ git diff HEAD -- lib/bridge/debug_log.dart | head -20
(空输出)
```

结论：**只有契约允许的两个文件被修改**；未触碰 `lib/bridge/debug_log.dart`、未触碰 `resolveLogDirectory` 定义、未新增/删除任何其他受版本控制文件。唯一未跟踪项是执行方自己的证据文件 `.pipeline/log-dir-load-failure-state/executor-report.md`（预期内）。**PASS**

完整 diff（`git diff` 原文，与执行方报告第 5 节逐字一致）：

```diff
diff --git a/lib/pages/settings_page.dart b/lib/pages/settings_page.dart
index aee4767a..01a20e26 100644
--- a/lib/pages/settings_page.dart
+++ b/lib/pages/settings_page.dart
@@ -56,6 +56,7 @@ class _SettingsPageState extends State<SettingsPage> {
   String? _downloadMessage;
   DownloadCancellationToken? _downloadToken;
   String? _logDirectory;
+  bool _logDirectoryLoadFailed = false;
 
   @override
   void dispose() {
@@ -100,7 +101,7 @@ class _SettingsPageState extends State<SettingsPage> {
       final dir = await (widget.logDirectoryResolver ?? resolveLogDirectory)();
       if (mounted) setState(() => _logDirectory = dir.path);
     } catch (_) {
-      // 解析失败静默：副标题保持「加载中…」
+      if (mounted) setState(() => _logDirectoryLoadFailed = true);
     }
   }
 
@@ -276,7 +277,10 @@ class _SettingsPageState extends State<SettingsPage> {
                   onTap: _openLogDirectory,
                   child: Padding(
                     padding: const EdgeInsets.symmetric(vertical: 4),
-                    child: Text(_logDirectory ?? '加载中…'),
+                    child: Text(
+                      _logDirectory ??
+                          (_logDirectoryLoadFailed ? '无法获取日志目录' : '加载中…'),
+                    ),
                   ),
                 ),
                 const SizedBox(height: 24),
diff --git a/test/settings_page_test.dart b/test/settings_page_test.dart
index 2dd76830..098df364 100644
--- a/test/settings_page_test.dart
+++ b/test/settings_page_test.dart
@@ -333,4 +333,33 @@ void main() {
     await tester.pump(const Duration(milliseconds: 1));
     expect(find.textContaining('检查失败'), findsOneWidget);
   });
+
+  testWidgets(
+    'A1: log directory resolution failure shows a failure state, not loading',
+    (tester) async {
+      await tester.pumpWidget(
+        MaterialApp(
+          home: SettingsPage(
+            currentVersion: '1.0.0',
+            settings: _SettingsFake(UpdateChannel.stable),
+            logDirectoryResolver: ({String? baseDirectory}) async =>
+                throw const FileSystemException('cannot resolve log directory'),
+          ),
+        ),
+      );
+      await tester.pumpAndSettle();
+
+      expect(find.text('日志目录'), findsOneWidget);
+      expect(
+        find.text('加载中…'),
+        findsNothing,
+        reason: '解析失败后副标题不得继续显示「加载中…」',
+      );
+      expect(
+        find.text('无法获取日志目录'),
+        findsOneWidget,
+        reason: '解析失败必须显示失败文案，供用户区分加载中与已失败',
+      );
+    },
+  );
 }
```

## 2. 既有断言零放宽 — PASS

### 2.1 行号级比对

```
$ git show HEAD:test/settings_page_test.dart | grep -n "expect(" | sed 's/^/HEAD: /'
HEAD: 131:    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
HEAD: 132:    expect(find.text('1.0.0'), findsOneWidget);
HEAD: 133:    expect(find.text('正式版'), findsOneWidget);
HEAD: 134:    expect(find.byKey(const ValueKey('check-for-updates')), findsOneWidget);
HEAD: 149:      expect(find.text('切换到测试版？'), findsOneWidget);
HEAD: 152:      expect(settings.channel, UpdateChannel.stable);
HEAD: 157:      expect(settings.channel, UpdateChannel.beta);
HEAD: 158:      expect(find.text('测试版'), findsOneWidget);
HEAD: 170:    expect(find.text('测试版'), findsOneWidget);
HEAD: 202:    expect(find.text('发现更新'), findsOneWidget);
HEAD: 205:    expect(find.text('已启动安装器'), findsOneWidget);
HEAD: 206:    expect(installer.received, file);
HEAD: 228:    expect(find.text('发现更新'), findsOneWidget);
HEAD: 250:    expect(find.text('已是最新版本'), findsOneWidget);
HEAD: 276:    expect(find.text('日志目录'), findsOneWidget, reason: '设置页必须有「日志目录」入口');
HEAD: 277:    expect(find.text(resolved), findsOneWidget, reason: '副标题必须显示解析出的路径');
HEAD: 282:    expect(openCount, 1, reason: '点击必须触发注入的 opener 且恰好一次');
HEAD: 283:    expect(openedWith, resolved, reason: 'opener 收到的必须是解析出的真实路径');
HEAD: 307:    expect(snackBar, findsOneWidget, reason: '打开失败必须显示 SnackBar');
HEAD: 308:    expect(
HEAD: 334:    expect(find.textContaining('检查失败'), findsOneWidget);

$ grep -n "expect(" test/settings_page_test.dart | sed 's/^/WT: /'
WT: 131: …（131–334 行与 HEAD 逐条同文同号）
WT: 352:      expect(find.text('日志目录'), findsOneWidget);
WT: 353:      expect(
WT: 358:      expect(
```

新增测试整体追加在文件尾部，既有 131–334 行**行号未移动**（因 diff 是纯追加），既有 21 条 `expect(` 与 HEAD 完全一致。

### 2.2 程序化逐条比对（去空白后按出现顺序）

```
$ python3 <balanced-paren expect extractor>  # 见审查命令记录
HEAD expect count: 21
WT expect count: 24
HEAD expects all present in WT in order: True
WT extra (new): ["expect(find.text('日志目录'),findsOneWidget)",
                 "expect(find.text('加载中…'),findsNothing,reason:'解析失败后副标题不得继续显示「加载中…」',)",
                 "expect(find.text('无法获取日志目录'),findsOneWidget,reason:'解析失败必须显示失败文案，供用户区分加载中与已失败',)"]
```

HEAD 的 21 条 `expect` 全部按原顺序、原文出现在工作区文件中（`h == w[:len(h)]` 为 `True`）；多出的 3 条全部属于新增 A1 用例。**既有断言语义零改动、零放宽。PASS**

### 2.3 用例数

```
$ grep -c "testWidgets(" test/settings_page_test.dart
10
$ git show HEAD:test/settings_page_test.dart | grep -c "testWidgets("
9
```

既有 9 个 + 新增 1 个 = 10，与契约 A2 预期一致。**PASS**

## 3. 红→绿真实性 — PASS

**安全做法**：未在 worktree 内 `git stash`。改用 `rsync` 把 worktree 复制到 `/tmp/logdir-review-copy`（排除 `build/`、`.git/`、`.worktrees/`），在副本内做红/绿实验。

```
$ rsync -a --exclude 'build/' --exclude '.git/' --exclude '.worktrees/' \
    /Users/alexc/Projects/CardMind/.worktrees/log-dir-load-failure-state/ /tmp/logdir-review-copy/
$ grep -n "_logDirectoryLoadFailed\|无法获取日志目录" /tmp/logdir-review-copy/lib/pages/settings_page.dart
59:  bool _logDirectoryLoadFailed = false;
104:      if (mounted) setState(() => _logDirectoryLoadFailed = true);
282:                          (_logDirectoryLoadFailed ? '无法获取日志目录' : '加载中…'),
```

### 3.1 红基线（副本内把 lib 还原为 HEAD，保留新增 test）

```
$ git show HEAD:lib/pages/settings_page.dart > /tmp/logdir-review-copy/lib/pages/settings_page.dart
$ grep -n "_logDirectoryLoadFailed" /tmp/logdir-review-copy/lib/pages/settings_page.dart
OK: reverted to HEAD
$ grep -c "A1: log directory resolution failure" /tmp/logdir-review-copy/test/settings_page_test.dart
1
$ flutter test test/settings_page_test.dart --plain-name 'A1: log directory resolution failure shows a failure state, not loading'
```

原始输出（节选）：

```
00:00 +0: A1: log directory resolution failure shows a failure state, not loading
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════════════
The following TestFailure was thrown running a test:
Expected: no matching candidates
  Actual: _TextWidgetFinder:<Found 1 widget with text "加载中…": [
            Text("加载中…", dependencies: [DefaultSelectionStyle, DefaultTextStyle, MediaQuery]),
          ]>
   Which: means one was found but none were expected
解析失败后副标题不得继续显示「加载中…」

When the exception was thrown, this was the stack:
#4      main.<anonymous closure> (file:///private/tmp/logdir-review-copy/test/settings_page_test.dart:353:7)
...
00:01 +0 -1: A1: log directory resolution failure shows a failure state, not loading [E]
00:01 +0 -1: Some tests failed.

Failing tests:
  /private/tmp/logdir-review-copy/test/settings_page_test.dart: A1: log directory resolution failure shows a failure state, not loading
RED_EXIT=1
```

**红成立**：退出码 `1`，失败点正是 `test/settings_page_test.dart:353`（`find.text('加载中…') findsNothing`），实际找到 1 个 `加载中…` widget —— 与契约「未修复时副标题仍是加载中…」完全对应。

### 3.2 绿（副本内恢复修复版 lib）

```
$ cp /tmp/settings_page_after.dart /tmp/logdir-review-copy/lib/pages/settings_page.dart
$ grep -c "_logDirectoryLoadFailed" /tmp/logdir-review-copy/lib/pages/settings_page.dart
3
$ flutter test test/settings_page_test.dart --plain-name 'A1: log directory resolution failure shows a failure state, not loading'
00:00 +0: A1: log directory resolution failure shows a failure state, not loading
00:01 +1: All tests passed!
GREEN_EXIT=0
```

### 3.3 整文件绿（副本，全部 10 个用例）

```
$ flutter test test/settings_page_test.dart
00:00 +0: settings page has version, stable default and check control
00:00 +1: beta selection can be cancelled or confirmed and persists on screen
00:01 +2: settings echoes a persisted channel
00:01 +3: download button shows progress and installer result
00:01 +4: update check renders an available update
00:01 +5: update check renders up to date
00:01 +6: A3: log directory entry shows path and opens once on tap
00:01 +7: A3: open failure surfaces the path via SnackBar
00:01 +8: update check renders failure state
00:02 +9: A1: log directory resolution failure shows a failure state, not loading
00:02 +10: All tests passed!
FULL_EXIT=0
```

### 3.4 同一命令在真实 worktree 内的独立复跑（绿）

```
$ cd /Users/alexc/Projects/CardMind/.worktrees/log-dir-load-failure-state
$ flutter test test/settings_page_test.dart
00:02 +9: A1: log directory resolution failure shows a failure state, not loading
00:02 +10: All tests passed!
EXIT_CODE=0
```

**红→绿真实成立。PASS**

### 3.5 工作区恢复原状核对

```
$ git diff | shasum -a 256
f881b93cb99e8c7a001134bf5da852e88fbc3e53bb535483f72204361a239084  -
$ git status --porcelain
 M lib/pages/settings_page.dart
 M test/settings_page_test.dart
?? .pipeline/log-dir-load-failure-state/
$ git rev-parse HEAD
521a8c5411b62c6aa711dadfee9fc9ff27b39f72
$ git stash list | wc -l
       5
```

工作区 diff 哈希与审查开始时**完全相同**；`git stash list` 的 5 条全部是仓库既有的旧 stash（`stash@{0}: WIP on main: 438f882 …` 等，均针对 `main`/`feature/center-server`），**本次审查没有创建任何 stash**，未污染 worktree。副本 `/tmp/logdir-review-copy` 与日志 `/tmp/logdir-red.log`、`/tmp/logdir-green.log`、`/tmp/logdir-full.log` 留在 /tmp，不影响仓库。

## 4. 逻辑正确性 — PASS

### 4.1 `_logDirectoryLoadFailed` 只在 catch 里置位

```
$ grep -n "无法获取日志目录\|加载中…\|_logDirectoryLoadFailed\|_logDirectory" lib/pages/settings_page.dart
59:  bool _logDirectoryLoadFailed = false;          # 声明，初值 false
102:      if (mounted) setState(() => _logDirectory = dir.path);   # 成功路径：只写 _logDirectory
104:      if (mounted) setState(() => _logDirectoryLoadFailed = true);  # 唯一置 true，位于 catch
110:    if (path == null || path.isEmpty) return;      # _openLogDirectory 提前返回
281-282: Text(_logDirectory ?? (_logDirectoryLoadFailed ? '无法获取日志目录' : '加载中…'))  # 唯一读取
```

全文件对 `_logDirectoryLoadFailed` 的写入**只有第 104 行一处**，且位于 `_loadLogDirectory` 的 `catch (_)` 内。成功路径（`try` 内第 102 行）只设置 `_logDirectory`，不会置失败位。**PASS**

### 4.2 成功时 `_logDirectory` 非 null，三元短路后不会显示失败文案

表达式 `_logDirectory ?? (_logDirectoryLoadFailed ? '无法获取日志目录' : '加载中…')`：`??` 左侧非 null 时**不评估右侧**。成功路径下 `_logDirectory = dir.path`（非 null），故失败文案与加载中文案都不会被求值/渲染。同时 `try` 与 `catch` 在一次 `_loadLogDirectory()` 调用中互斥，两个状态位不可能同时置位。既有 A3 用例（`find.text(resolved) findsOneWidget`）在本审查的绿跑中通过，佐证成功路径仍渲染真实路径。**PASS**

### 4.3 失败态下 `_openLogDirectory` 仍安全

```
  Future<void> _openLogDirectory() async {
    final path = _logDirectory;
    if (path == null || path.isEmpty) return;      # 失败态：_logDirectory 仍为 null → 提前 return
    try {
      await (widget.logDirectoryOpener ?? openLogDirectoryInFileManager)(path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('无法打开日志目录：$path')));
    }
  }
```

失败态下 `_logDirectory == null` → 第一行守卫直接 return：不调用 opener、不弹 SnackBar、无副作用。未改动此方法，契约「无需额外改动」成立。**PASS**

### 4.4 边界：resolver 成功但 `dir.path` 为空串

我的判断（不要求修改）：

- 若 `dir.path == ''`，`_logDirectory = ''`（**非 null**）→ `??` 短路 → `Text('')` → 副标题渲染为**空白**，既不是 `加载中…` 也不是 `无法获取日志目录`。
- `_openLogDirectory` 因 `path.isEmpty` 提前 return，点击仍无副作用（安全）。
- **这是既有行为，非本次改动引入或恶化**：改动前同样渲染 `Text('')`。本次改动只在 `_logDirectory` 为 null 时改变展示，空串路径不受影响。
- 实际可达性极低：`resolveLogDirectory` 返回 `Directory('${base.path}${Platform.pathSeparator}logs')`，只有当 `getApplicationSupportDirectory()` 返回空 `path` 时才会产生空串，而 `path_provider` 各平台实现均返回非空绝对路径；注入的测试 resolver 也需刻意返回空串才能触发。
- 结论：**可接受的低风险未覆盖边界**，属契约外的既有缺口。若后续要收口，可在成功分支同时判断 `dir.path.isEmpty` 归入失败态，但**不应在本任务范围内擅自扩大改动**（契约第 2 节明确禁止）。

### 4.5 附带观察（非本次改动，非 FAIL）

`lib/pages/settings_page.dart:272` 的版本号副标题 `Text(_version ?? '加载中…')` 存在**同类**问题：`_loadVersion()` 若抛异常（如 `PackageInfo.fromPlatform()` 失败），`_version` 保持 null，永久显示 `加载中…`。这与本任务修复的是同一类状态表达缺陷，但**不在本契约范围**（契约只针对日志目录项）。记录为后续可选跟进项。

## 5. 断言强度 — PASS

新增用例的三条断言：

```dart
expect(find.text('日志目录'), findsOneWidget);
expect(find.text('加载中…'), findsNothing, reason: '解析失败后副标题不得继续显示「加载中…」');
expect(find.text('无法获取日志目录'), findsOneWidget, reason: '解析失败必须显示失败文案，供用户区分加载中与已失败');
```

- 使用 `find.text(...)`（**精确全文匹配**，非 `textContaining`），断言强度足够：既断言旧文案**消失**，又断言新文案**出现**，双向夹逼。仅断言「不显示加载中」会放过「显示任意其他文本」；仅断言「显示失败文案」会放过「两个都在」。当前写法两者兼顾。
- 字面量逐字/逐字节比对：

```
$ python3 - <<'EOF'
for lit in ['无法获取日志目录','加载中…','日志目录']:
    print(repr(lit), 'in lib:', lit in src, '| in test:', lit in tst, '| bytes:', lit.encode('utf-8').hex())
EOF
'无法获取日志目录' in lib: True | in test: True | bytes: e697a0e6b395e88eb7e58f96e697a5e5bf97e79baee5bd95
'加载中…' in lib: True | in test: True | bytes: e58aa0e8bdbde4b8ade280a6
'日志目录' in lib: True | in test: True | bytes: e697a5e5bf97e79baee5bd95
```

代码侧字面量（第 282 行）与测试侧断言字面量（第 354、359 行）UTF-8 字节完全一致，**不是「包含」而是逐字相同**。`加载中…` 的 `…` 为 U+2026（`e280a6`），两侧一致，无全角/半角混用。

- 回归捕获能力已被红跑证实（第 3.1 节）：未修复代码上该用例失败，退出码 1。
- 小瑕疵（不影响结论）：新增用例首条 `expect(find.text('日志目录'), findsOneWidget)` 与既有 A3 用例重复，属弱冗余断言；无害，不构成 FAIL。

**PASS**

## 6. `flutter analyze` — PASS

```
$ export PUB_HOSTED_URL=https://pub.flutter-io.cn
$ flutter analyze
Analyzing log-dir-load-failure-state...
No issues found! (ran in 4.4s)
ANALYZE_EXIT=0
```

## 7. 全量 `flutter test` 环境归因（未独立复跑，仅佐证）

按环境说明，本 worktree 缺 FRB 原生库，全量 `flutter test` 的 `(setUpAll)` 失败属环境问题。我**没有**独立复跑全量套件（避免耗时且结论已知），但独立核实了执行方的关键环境论断：

```
$ find build -name "cardmind_backend.framework"
(end find)                       # 无输出 —— framework 确实不存在
$ ls test/api_integration_test.dart test/platform_log_capture_test.dart
test/api_integration_test.dart      test/platform_log_capture_test.dart   # 执行方列出的失败文件确实存在
```

执行方报告的 7 个失败全部为 `(setUpAll)` 阶段 `Failed to load dynamic library 'cardmind_backend.framework/cardmind_backend'`，与本 worktree 无 dylib 产物的事实一致；这些测试文件确实存在；该失败集合与上一任务 `git-gate-path-sep-fix` 记录的同名 7 个文件吻合。**归因可信**：7 个失败与本次 UI 状态改动无因果关系。我据此采信 A3 的「0 个新增逻辑失败」结论，但明确记录：**全量套件未由审查方独立复跑**。

## 8. 证据边界（必须声明）

- 本仓库无 `.gitnexus/run.cjs`，GitNexus 不可用。**我没有执行 impact analysis / detect_changes**，本报告不含任何相关结论，也不得被解读为已做影响面分析。
- 全量 `flutter test` 未独立复跑（见第 7 节），仅核实了环境归因所需的客观事实。
- 未做实机（真实应用）走查：改动仅涉及 UI 状态表达，不涉及平台路径；契约第 7 节已界定该边界。
- 只读审查：未修改 worktree 任何文件，未 commit，未 stash。红/绿实验全部在 `/tmp/logdir-review-copy` 副本内完成；worktree diff 哈希 `f881b93c…` 审查前后恒定。

## 9. 逐项结论汇总

| # | 核实项 | 结论 |
|---|--------|------|
| 1 | diff 范围仅两个文件；未触碰 `debug_log.dart`/`resolveLogDirectory`；无 staged | **PASS** |
| 2 | 既有 21 条 `expect` 零改动、零放宽（按序逐条比对为 `True`） | **PASS** |
| 3 | 红→绿真实（红 exit 1 @ line 353；绿 exit 0；整文件 10/10 过）；worktree 恢复原状 | **PASS** |
| 4 | `_logDirectoryLoadFailed` 仅 catch 置位；成功路径不误置；三元短路语义正确；失败态 `_openLogDirectory` 安全 | **PASS** |
| 5 | 新增断言精确匹配（`find.text` 非 contains），字面量字节级一致，红跑证明可捕获回归 | **PASS** |
| 6 | `flutter analyze` 0 issue，exit 0 | **PASS** |
| 7 | 全量失败归因于 worktree 缺 FRB 原生库（framework 确认不存在） | **PASS（带环境说明，未独立复跑）** |

**发现的问题（均非阻塞、不构成 FAIL）**：

1. 边界未覆盖：resolver 成功但 `dir.path == ''` 时副标题渲染空串（既非加载中也非失败文案）。属**既有行为**，改动未引入也未恶化；实际可达性极低。契约外，不建议本任务扩大改动。
2. 同类既存缺陷：`settings_page.dart:272` 版本号副标题 `Text(_version ?? '加载中…')` 在版本加载失败时同样永久停留「加载中…」，与本任务修复同类但不在契约范围，建议后续任务跟进。
3. 冗余断言：新增用例首条 `expect(find.text('日志目录'), findsOneWidget)` 与既有 A3 用例重复，无害。

**verdict: PASS** —— 改动与契约第 2 节逐字一致，未越界，验收条件 A1（红→绿）与 A2（既有不退化）由审查方独立复现，A3 的失败全部可归因于环境且已核实环境事实。

```pipeline-evidence
task-id: log-dir-load-failure-state
role: reviewer
worktree: /Users/alexc/Projects/CardMind/.worktrees/log-dir-load-failure-state
branch: pipeline/log-dir-load-failure-state
head: 521a8c5411b62c6aa711dadfee9fc9ff27b39f72
verdict: PASS
```