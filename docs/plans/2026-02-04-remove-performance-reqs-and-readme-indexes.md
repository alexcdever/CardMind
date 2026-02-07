# Remove Performance Requirements + Update README Indexes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 删除 docs/specs 中的性能测试/阈值/要求描述，同时更新项目内所有 README 的目录索引（不含 `.dart_tool/`）。

**Architecture:** 仅移除“性能测试/性能要求/性能阈值/测试用例名称”相关的规格文本，保留性能考虑/优化/设计说明。README 只更新目录索引与结构说明，不改业务内容。

**Tech Stack:** Markdown, Flutter/Dart specs

### Task 1: 盘点性能测试/阈值/要求的规格内容

**Files:**
- Modify: `docs/specs/**` (inventory only)
- Test: `rg "性能要求|性能测试|Performance Tests|test_.*performance|< ?\d+ms|< ?\d+秒|within_" docs/specs`

**Step 1: Write the failing test**

```bash
rg "性能要求|性能测试|Performance Tests|test_.*performance|< ?\\d+ms|< ?\\d+秒|within_" docs/specs
```

**Step 2: Run test to verify it fails**

Run: same command
Expected: prints current matches (non-empty).

**Step 3: Write minimal implementation**

记录命中的文件路径，作为下一任务的修改清单。

**Step 4: Run test to verify it passes**

N/A（本任务仅盘点）。

**Step 5: Commit**

Skip (no file changes).

### Task 2: 删除 specs 中的性能测试/阈值/要求文本

**Files:**
- Modify: `docs/specs/features/**`
- Modify: `docs/specs/ui/**`
- Modify: `docs/specs/domain/**` (仅移除“性能特征/性能要求/性能测试”段落，不动性能考虑)
- Modify: `docs/specs/architecture/**` (仅移除性能测试/阈值/要求段落)
- Test: `rg "性能要求|性能测试|Performance Tests|test_.*performance|< ?\d+ms|< ?\d+秒|within_" docs/specs`

**Step 1: Write the failing test**

```bash
rg "性能要求|性能测试|Performance Tests|test_.*performance|< ?\\d+ms|< ?\\d+秒|within_" docs/specs
```

**Step 2: Run test to verify it fails**

Expected: 非空结果。

**Step 3: Write minimal implementation**

删除或改写以下类型内容（保留“性能考虑/优化/设计决策”）：
- “Performance Tests / 性能测试 / 性能要求 / 性能特征”小节
- `test_*_performance()` 等性能测试用例名称
- 明确阈值（如 `< 200ms`, `< 10ms`, `60fps`）的要求语句

**Step 4: Run test to verify it passes**

Run same `rg` command
Expected: no matches.

**Step 5: Commit**

```bash
git add docs/specs
git commit -m "docs(specs): remove performance test requirements"
```

### Task 3: 更新所有 README 的目录索引

**Files:**
- Modify: `README.md`
- Modify: `.project-guardian/README.md`
- Modify: `docs/specs/README.md`
- Modify: `docs/specs/features/README.md`
- Modify: `docs/specs/ui/README.md`
- Modify: `tool/README.md`
- Modify: `react_ui_reference/README.md`
- Test: `find . -name "README.md" -maxdepth 4` (excluding `.dart_tool/`)

**Step 1: Write the failing test**

```bash
find . -name "README.md" -maxdepth 4
```

**Step 2: Run test to verify it fails**

Expected: list of README files to review.

**Step 3: Write minimal implementation**

逐一更新 README 中的目录树/索引/目录引用，使其与当前实际结构一致（不改业务描述）。

**Step 4: Run test to verify it passes**

N/A（人工校对）。

**Step 5: Commit**

```bash
git add README.md .project-guardian/README.md docs/specs/README.md docs/specs/features/README.md docs/specs/ui/README.md tool/README.md react_ui_reference/README.md
git commit -m "docs(readme): refresh directory indexes"
```

### Task 4: 验证

**Files:**
- Test: `rg "性能要求|性能测试|Performance Tests|test_.*performance|< ?\d+ms|< ?\d+秒|within_" docs/specs`

**Step 1: Write the failing test**

```bash
rg "性能要求|性能测试|Performance Tests|test_.*performance|< ?\\d+ms|< ?\\d+秒|within_" docs/specs
```

**Step 2: Run test to verify it fails**

Expected: no matches.

**Step 3: Write minimal implementation**

N/A

**Step 4: Run test to verify it passes**

Expected: empty output, exit code 1.

**Step 5: Commit**

Skip (verification only).
