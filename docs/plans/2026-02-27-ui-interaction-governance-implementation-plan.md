# UI Interaction Governance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 UI 交互治理设计落地为可持续执行的文档基线与自动化守卫，确保“规范、完整性、验收标准”可长期维护。

**Architecture:** 采用“文档三件套 + 自动化守卫测试”架构。`design` 负责原则与场景定义，`acceptance-matrix` 负责双轨量化条目，`release-gate` 负责发布门禁。测试侧新增治理文档校验与矩阵完整性校验，形成“改交互必须改规范”闭环。

**Tech Stack:** Markdown, Flutter test (dart:io 文档校验), Dart

---

### Task 1: 建立治理三件套文档

**Files:**
- Create: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Create: `docs/plans/2026-02-27-ui-interaction-release-gate.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-governance-design.md`

**Step 1: Write the failing test**

```dart
test('governance companion docs exist', () {
  expect(File('docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md').existsSync(), isTrue);
  expect(File('docs/plans/2026-02-27-ui-interaction-release-gate.md').existsSync(), isTrue);
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart --plain-name "governance companion docs exist"`
Expected: FAIL（两份 companion 文档尚未创建）

**Step 3: Write minimal implementation**

```markdown
# UI 交互验收矩阵（2026-02-27）

| 场景 | 入口 | 研发轨断言 | 体验轨阈值 | 门禁 |
| --- | --- | --- | --- | --- |
| S1 引导分流 | 先本地使用 | 点击后进入卡片页 | <= 1 步进入主工作区 | 必过 |
```

```markdown
# UI 交互发布门禁（2026-02-27）

- 未通过研发轨自动化，不可合并。
- 未通过体验轨阈值，不可发布。
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart --plain-name "governance companion docs exist"`
Expected: PASS

**Step 5: Commit**

```bash
git add docs/plans/2026-02-27-ui-interaction-governance-design.md docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md docs/plans/2026-02-27-ui-interaction-release-gate.md
git commit -m "docs(governance): add interaction acceptance matrix and release gate"
```

---

### Task 2: 新增治理文档自动化守卫测试

**Files:**
- Create: `test/ui_interaction_governance_docs_test.dart`

**Step 1: Write the failing test**

```dart
test('design doc includes required scenarios', () {
  final content = File('docs/plans/2026-02-27-ui-interaction-governance-design.md').readAsStringSync();
  for (final scenario in ['S1 引导分流', 'S2 卡片管理', 'S3 池管理', 'S4 设置', 'S5 全局同步异常']) {
    expect(content, contains(scenario));
  }
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart --plain-name "design doc includes required scenarios"`
Expected: FAIL（测试文件尚不存在）

**Step 3: Write minimal implementation**

```dart
// input: docs/plans governance markdown files
// output: fast fail when required governance sections are missing
// pos: test guard for ui governance docs; 修改本文件需同步更新文件头与所属 DIR.md
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // governance doc checks
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add test/ui_interaction_governance_docs_test.dart
git commit -m "test(governance): add ui interaction governance doc guards"
```

---

### Task 3: 强化验收矩阵完整性校验（双轨必填）

**Files:**
- Modify: `test/ui_interaction_governance_docs_test.dart`
- Modify: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`

**Step 1: Write the failing test**

```dart
test('acceptance matrix has both dev and experience tracks for all scenarios', () {
  final content = File('docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md').readAsStringSync();
  for (final scenario in ['S1', 'S2', 'S3', 'S4', 'S5']) {
    expect(content, contains('$scenario '));
  }
  expect(content, contains('研发轨断言'));
  expect(content, contains('体验轨阈值'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart --plain-name "acceptance matrix has both dev and experience tracks for all scenarios"`
Expected: FAIL（矩阵初始内容不完整）

**Step 3: Write minimal implementation**

```markdown
| 场景 | 入口 | 研发轨断言 | 体验轨阈值 | 门禁 |
| --- | --- | --- | --- | --- |
| S1 引导分流 | ... | ... | ... | 必过 |
| S2 卡片管理 | ... | ... | ... | 必过 |
| S3 池管理 | ... | ... | ... | 必过 |
| S4 设置 | ... | ... | ... | 必过 |
| S5 全局同步异常 | ... | ... | ... | 必过 |
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md test/ui_interaction_governance_docs_test.dart
git commit -m "docs(governance): complete dual-track acceptance matrix coverage"
```

---

### Task 4: 更新计划目录索引与说明

**Files:**
- Modify: `docs/plans/DIR.md`

**Step 1: Write the failing test**

```dart
test('plans DIR includes governance plan and companion docs', () {
  final dirContent = File('docs/plans/DIR.md').readAsStringSync();
  expect(dirContent, contains('2026-02-27-ui-interaction-governance-design.md'));
  expect(dirContent, contains('2026-02-27-ui-interaction-governance-implementation-plan.md'));
  expect(dirContent, contains('2026-02-27-ui-interaction-acceptance-matrix.md'));
  expect(dirContent, contains('2026-02-27-ui-interaction-release-gate.md'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart --plain-name "plans DIR includes governance plan and companion docs"`
Expected: FAIL（DIR.md 尚未登记完整）

**Step 3: Write minimal implementation**

```text
在 docs/plans/DIR.md 追加四条记录：design / implementation plan / matrix / release gate。
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: PASS

**Step 5: Commit**

```bash
git add docs/plans/DIR.md
git commit -m "docs(plans): register ui interaction governance documentation set"
```

---

### Task 5: 执行全量验证并确认门禁可用

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`

**Step 1: Write the failing test**

```dart
test('release gate doc references required verification commands', () {
  final content = File('docs/plans/2026-02-27-ui-interaction-release-gate.md').readAsStringSync();
  expect(content, contains('flutter analyze'));
  expect(content, contains('flutter test'));
  expect(content, contains('dart run tool/fractal_doc_check.dart --base'));
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/ui_interaction_governance_docs_test.dart --plain-name "release gate doc references required verification commands"`
Expected: FAIL（发布门禁命令未完整声明）

**Step 3: Write minimal implementation**

```markdown
## 必跑校验命令
- flutter analyze
- flutter test
- dart run tool/fractal_doc_check.dart --base <commit>
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`
Expected: PASS

**Step 5: Run full verification suite**

Run: `flutter analyze && flutter test`
Expected: PASS

**Step 6: Commit**

```bash
git add docs/plans/2026-02-27-ui-interaction-release-gate.md test/ui_interaction_governance_docs_test.dart
git commit -m "test(governance): enforce release gate verification commands"
```
