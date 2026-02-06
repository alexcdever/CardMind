# 测试体系重构实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 统一 Rust/Flutter 的单元/功能/模糊测试体系，并在 `tool/quality.dart` 中引入基于公开项数量的单元测试覆盖率检查与 `fuzz` 子命令。

**Architecture:** 规格文档先定义测试分类与覆盖率规则；质量脚本在常规流程中执行覆盖率检查，`fuzz` 子命令独立执行模糊测试。Rust 遵循官方测试组织方式（模块内单元 + `rust/tests` 功能），Flutter 使用 `test/unit|feature|fuzz` 目录并统一 `it_should_` 命名。

**Tech Stack:** Rust, Flutter/Dart, cargo-fuzz, flutter_test.

---

### Task 1: 更新规格索引中的测试分类与覆盖率规则

**Files:**
- Modify: `docs/specs/README.md`

**Step 1: 增加“测试分类与覆盖率定义”段落**

```markdown
## 测试分类与覆盖率定义

- **单元测试**：面向逻辑代码的单模块验证（不跨多层调用）
- **功能测试**：跨模块/多层行为验证；规格测试默认归为功能测试
- **模糊测试**：随机/属性驱动输入的边界与异常探索

**单元测试覆盖率**：
- 统计规则：公开项数量与对应单元测试数量之比
- 阈值：≥ 90%
- 计数范围：
  - Rust：`rust/src` 逻辑代码（排除生成文件）
  - Flutter：`lib/models|services|utils|providers|constants`（排除 `lib/bridge` 与生成文件）
```

**Step 2: 轻量检查**

Run: `rg -n "测试分类与覆盖率定义" docs/specs/README.md`  
Expected: 命中 1 处新增标题

**Step 3: Commit**

```bash
git add docs/specs/README.md
git commit -m "docs: add test taxonomy and coverage rules"
```

---

### Task 2: 规格文档测试覆盖术语统一为“功能测试”

**Files:**
- Modify: `docs/specs/domain/card.md`
- Modify: `docs/specs/domain/pool.md`
- Modify: `docs/specs/domain/sync.md`
- Modify: `docs/specs/domain/types.md`
- Modify: `docs/specs/architecture/storage/dual_layer.md`
- Modify: `docs/specs/architecture/storage/card_store.md`
- Modify: `docs/specs/architecture/storage/pool_store.md`
- Modify: `docs/specs/architecture/storage/sqlite_cache.md`
- Modify: `docs/specs/architecture/storage/loro_integration.md`
- Modify: `docs/specs/architecture/storage/device_config.md`
- Modify: `docs/specs/architecture/sync/service.md`
- Modify: `docs/specs/architecture/sync/peer_discovery.md`
- Modify: `docs/specs/architecture/sync/subscription.md`
- Modify: `docs/specs/architecture/sync/conflict_resolution.md`
- Modify: `docs/specs/architecture/security/password.md`
- Modify: `docs/specs/architecture/security/keyring.md`
- Modify: `docs/specs/architecture/security/privacy.md`
- Modify: `docs/specs/features/card_management/spec.md`
- Modify: `docs/specs/features/pool_management/spec.md`
- Modify: `docs/specs/features/p2p_sync/spec.md`
- Modify: `docs/specs/features/search_and_filter/spec.md`
- Modify: `docs/specs/features/settings/spec.md`
- Modify: `docs/specs/features/home_screen/shared.md`
- Modify: `docs/specs/features/home_screen/home_screen.md`
- Modify: `docs/specs/features/card_list/card_list_item.md`
- Modify: `docs/specs/features/card_list/desktop.md`
- Modify: `docs/specs/features/card_list/mobile.md`
- Modify: `docs/specs/features/card_list/note_card.md`
- Modify: `docs/specs/features/card_list/note_editor_fullscreen.md`
- Modify: `docs/specs/features/card_editor/card_editor_screen.md`
- Modify: `docs/specs/features/card_editor/desktop.md`
- Modify: `docs/specs/features/card_editor/mobile.md`
- Modify: `docs/specs/features/card_editor/note_card.md`
- Modify: `docs/specs/features/card_editor/fullscreen_editor.md`
- Modify: `docs/specs/features/card_detail/card_detail_screen.md`
- Modify: `docs/specs/features/navigation/mobile_nav.md`
- Modify: `docs/specs/features/navigation/mobile.md`
- Modify: `docs/specs/features/gestures/mobile.md`
- Modify: `docs/specs/features/fab/mobile.md`
- Modify: `docs/specs/features/search/mobile.md`
- Modify: `docs/specs/features/search/desktop.md`
- Modify: `docs/specs/features/sync/sync_screen.md`
- Modify: `docs/specs/features/sync_feedback/shared.md`
- Modify: `docs/specs/features/sync_feedback/sync_details_dialog.md`
- Modify: `docs/specs/features/sync_feedback/desktop.md`
- Modify: `docs/specs/features/settings/device_manager_panel.md`
- Modify: `docs/specs/features/settings/settings_screen.md`
- Modify: `docs/specs/features/settings/settings_panel.md`
- Modify: `docs/specs/features/onboarding/shared.md`
- Modify: `docs/specs/features/context_menu/desktop.md`
- Modify: `docs/specs/features/toolbar/desktop.md`
- Modify: `docs/specs/ui/components/shared/device_manager_panel.md`
- Modify: `docs/specs/ui/components/shared/sync_details_dialog.md`
- Modify: `docs/specs/ui/components/shared/settings_panel.md`
- Modify: `docs/specs/ui/components/shared/sync_status_indicator.md`
- Modify: `docs/specs/ui/components/shared/note_card.md`
- Modify: `docs/specs/ui/components/shared/fullscreen_editor.md`
- Modify: `docs/specs/ui/components/desktop/card_list_item.md`
- Modify: `docs/specs/ui/components/desktop/context_menu.md`
- Modify: `docs/specs/ui/components/desktop/desktop_nav.md`
- Modify: `docs/specs/ui/components/desktop/toolbar.md`
- Modify: `docs/specs/ui/components/mobile/card_list_item.md`
- Modify: `docs/specs/ui/components/mobile/fab.md`
- Modify: `docs/specs/ui/components/mobile/gestures.md`
- Modify: `docs/specs/ui/components/mobile/mobile_nav.md`
- Modify: `docs/specs/ui/screens/desktop/card_editor_screen.md`
- Modify: `docs/specs/ui/screens/desktop/home_screen.md`
- Modify: `docs/specs/ui/screens/desktop/settings_screen.md`
- Modify: `docs/specs/ui/screens/mobile/card_detail_screen.md`
- Modify: `docs/specs/ui/screens/mobile/card_editor_screen.md`
- Modify: `docs/specs/ui/screens/mobile/home_screen.md`
- Modify: `docs/specs/ui/screens/mobile/settings_screen.md`
- Modify: `docs/specs/ui/screens/mobile/sync_screen.md`
- Modify: `docs/specs/ui/screens/shared/onboarding_screen.md`
- Modify: `docs/specs/ui/adaptive/components.md`
- Modify: `docs/specs/ui/adaptive/layouts.md`
- Modify: `docs/specs/ui/adaptive/platform_detection.md`

**Step 1: 统一术语**
- 将“集成测试”统一替换为“功能测试”
- 将“集成测试通过”统一替换为“功能测试通过”
- 对“Widget 测试”类描述，改写为“功能测试（Widget）”

**Step 2: 重点示例（应用到所有测试覆盖段落）**

```markdown
**功能测试**:
- ...

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有功能测试通过
```

**Step 3: 轻量检查**

Run: `rg -n "集成测试" docs/specs`  
Expected: 0 matches

**Step 4: Commit**

```bash
git add docs/specs
git commit -m "docs: rename integration tests to feature tests"
```

---

### Task 3: 更新工具文档说明覆盖率与 fuzz 子命令

**Files:**
- Modify: `tool/README.md`

**Step 1: 更新 quality.dart 说明**

```markdown
**用途**:
- 单元测试覆盖率检查（公开项数量 vs 单元测试数量，阈值 ≥ 90%）
- Rust/Dart 常规检查与测试

**用法**:
dart tool/quality.dart
dart tool/quality.dart fuzz

**fuzz 子命令**:
- Rust: cargo-fuzz 目标列表（默认 2–3 个目标，每目标 60 秒）
- Flutter: flutter test test/fuzz
```

**Step 2: Commit**

```bash
git add tool/README.md
git commit -m "docs: document coverage check and fuzz subcommand"
```

---

### Task 4: 先写覆盖率解析单元测试（TDD）

**Files:**
- Create: `test/unit/tool/coverage_parser_unit_test.dart`

**Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import '../../../tool/quality/coverage.dart';

void main() {
  test('it_should_parse_rust_public_items', () {
    const source = '''
pub struct Pool {}
pub enum Mode {}
pub fn do_work() {}
impl Pool { pub fn rename(&self) {} }
''';
    final items = parseRustPublicItems(source);
    expect(items, containsAll(<String>{
      'Pool',
      'Mode',
      'do_work',
      'Pool__rename',
    }));
  });

  test('it_should_parse_dart_public_items', () {
    const source = '''
class Device { void ping() {} }
String formatId(String id) => id;
''';
    final items = parseDartPublicItems(source);
    expect(items, containsAll(<String>{'Device', 'Device__ping', 'formatId'}));
  });
}
```

**Step 2: 运行并确认失败**

Run: `flutter test test/unit/tool/coverage_parser_unit_test.dart`  
Expected: FAIL（找不到解析函数）

---

### Task 5: 实现覆盖率解析模块

**Files:**
- Create: `tool/quality/coverage.dart`

**Step 1: 最小实现解析函数**

```dart
Set<String> parseRustPublicItems(String source) { /* ... */ }
Set<String> parseDartPublicItems(String source) { /* ... */ }
```

**Step 2: 运行单测**

Run: `flutter test test/unit/tool/coverage_parser_unit_test.dart`  
Expected: PASS

**Step 3: Commit**

```bash
git add tool/quality/coverage.dart test/unit/tool/coverage_parser_unit_test.dart
git commit -m "test: add coverage parser with unit tests"
```

---

### Task 6: 将覆盖率检查与 fuzz 子命令接入 quality.dart

**Files:**
- Modify: `tool/quality.dart`

**Step 1: 增加参数分发**

```dart
if (arguments.isNotEmpty && arguments.first == 'fuzz') {
  await runFuzzChecks();
  return;
}
```

**Step 2: 常规流程增加覆盖率检查**

```dart
if (!await runCoverageCheck()) exit(1);
```

**Step 3: 实现 fuzz 子命令**

```dart
Future<bool> runFuzzChecks() async {
  return await runRustFuzzTargets() && await runFlutterFuzzTests();
}
```

**Step 4: 验证脚本**

Run: `dart tool/quality.dart`  
Expected: PASS（覆盖率检查通过或提示缺失）  

Run: `dart tool/quality.dart fuzz`  
Expected: 若未安装 cargo-fuzz，应提示安装并退出非 0

**Step 5: Commit**

```bash
git add tool/quality.dart
git commit -m "feat(tool): add coverage check and fuzz subcommand"
```

---

### Task 7: Rust 功能测试文件命名与函数命名统一

**Files:**
- Modify: `rust/tests/*`
- Modify: `rust/src/**`
- Modify: `rust/tests/verify_tests.sh`

**Step 1: 重命名测试文件为 *_feature_test.rs**

示例：
```
rust/tests/card_store_test.rs -> rust/tests/card_store_feature_test.rs
rust/tests/dual_layer_test.rs -> rust/tests/dual_layer_feature_test.rs
rust/tests/sp_mdns_001_spec.rs -> rust/tests/sp_mdns_001_feature_test.rs
```

**Step 2: 重命名测试函数为 it_should_***

```rust
#[test]
fn it_should_create_card() { /* ... */ }
```

**Step 3: 更新 verify_tests.sh 中的文件名与示例**

**Step 4: 运行测试**

Run: `cargo test`  
Expected: PASS

**Step 5: Commit**

```bash
git add rust/tests rust/src
git commit -m "refactor(rust): rename tests to it_should and feature files"
```

---

### Task 8: Rust 模糊测试引入（cargo-fuzz）

**Files:**
- Create: `rust/fuzz/Cargo.toml`
- Create: `rust/fuzz/fuzz_targets/fuzz_password_strength.rs`
- Create: `rust/fuzz/fuzz_targets/fuzz_pool_validation.rs`
- Create: `rust/fuzz/fuzz_targets/fuzz_pool_hash.rs`
- Modify: `.gitignore`

**Step 1: 添加 fuzz target**

```rust
#![no_main]
use libfuzzer_sys::fuzz_target;
use cardmind_rust::security::password::evaluate_password_strength;

fuzz_target!(|data: &str| {
  let _ = evaluate_password_strength(data);
});
```

**Step 2: 更新 .gitignore**

```
rust/fuzz/target/
rust/fuzz/corpus/
rust/fuzz/artifacts/
```

**Step 3: 运行（短时）**

Run: `cargo fuzz run fuzz_password_strength -- -max_total_time=60`  
Expected: PASS（无 crash）

**Step 4: Commit**

```bash
git add rust/fuzz .gitignore
git commit -m "test(fuzz): add cargo-fuzz targets"
```

---

### Task 9: Flutter 测试目录重排与文件命名

**Files:**
- Modify: `test/**`

**Step 1: 建立新目录并移动文件**

示例映射（实际全部移动）：
```
test/utils/text_truncator_test.dart -> test/unit/utils/text_truncator_unit_test.dart
test/models/device_model_test.dart -> test/unit/models/device_model_unit_test.dart
test/services/qr_code_generator_test.dart -> test/unit/services/qr_code_generator_unit_test.dart
test/providers/settings_provider_test.dart -> test/unit/providers/settings_provider_unit_test.dart

test/widgets/note_card_test.dart -> test/feature/widgets/note_card_feature_test.dart
test/screens/settings_screen_test.dart -> test/feature/screens/settings_screen_feature_test.dart
test/features/card_management_test.dart -> test/feature/features/card_management_feature_test.dart
test/specs/home_screen_spec_test.dart -> test/feature/specs/home_screen_spec_feature_test.dart
```

**Step 2: 统一测试命名为 it_should_***

```dart
test('it_should_display_current_device', () { /* ... */ });
```

**Step 3: 运行测试**

Run: `flutter test test/unit`  
Expected: PASS  

Run: `flutter test test/feature`  
Expected: PASS

**Step 4: Commit**

```bash
git add test
git commit -m "refactor(test): reorganize flutter tests into unit/feature"
```

---

### Task 10: Flutter 模糊测试新增

**Files:**
- Create: `test/fuzz/text_truncator_fuzz_test.dart`
- Create: `test/fuzz/qr_code_parser_fuzz_test.dart`

**Step 1: 新增 fuzz 测试**

```dart
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/utils/text_truncator.dart';

void main() {
  test('it_should_handle_random_text_without_crash', () {
    final random = Random(42);
    for (var i = 0; i < 500; i++) {
      final text = String.fromCharCodes(
        List.generate(256, (_) => random.nextInt(128)),
      );
      final cleaned = TextUtils.cleanTextForDisplay(text);
      expect(
        cleaned.contains(RegExp(r'[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]')),
        isFalse,
      );
    }
  });
}
```

**Step 2: 运行 fuzz 子集**

Run: `flutter test test/fuzz`  
Expected: PASS

**Step 3: Commit**

```bash
git add test/fuzz
git commit -m "test(fuzz): add flutter fuzz tests"
```

---

### Task 11: 覆盖率规则与测试路径的规格文档同步

**Files:**
- Modify: `docs/specs/ui/components/shared/sync_details_dialog.md`
- Modify: `docs/specs/ui/components/shared/device_manager_panel.md`
- Modify: `docs/specs/ui/components/shared/settings_panel.md`
- Modify: `docs/specs/ui/components/shared/sync_status_indicator.md`
- Modify: `docs/specs/ui/components/shared/note_card.md`
- Modify: 其他引用具体 test 路径的 specs 文件（按 `rg -n "test/" docs/specs` 列表逐一调整）

**Step 1: 更新 test 路径与命名**

```markdown
- `test/feature/widgets/sync_details_dialog_feature_test.dart` - 功能测试
```

**Step 2: 校验无旧路径**

Run: `rg -n "test/.*_test.dart" docs/specs`  
Expected: 仅出现新路径

**Step 3: Commit**

```bash
git add docs/specs
git commit -m "docs: align spec test references with new structure"
```

---

### Task 12: 全量验证

**Step 1: 常规质量检查**

Run: `dart tool/quality.dart`  
Expected: PASS（覆盖率 ≥ 90%）

**Step 2: Fuzz 子命令**

Run: `dart tool/quality.dart fuzz`  
Expected: PASS（cargo-fuzz + flutter fuzz）

**Step 3: Commit**

```bash
git add .
git commit -m "test: finalize test system refactor"
```

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-02-05-test-system-refactor-implementation-plan.md`. Two execution options:

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration  
**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

Which approach?
