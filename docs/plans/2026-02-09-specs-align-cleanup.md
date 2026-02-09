# Specs Alignment & Tag Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 统一架构/领域/功能规格表述并移除剩余标签相关代码与测试，更新“最后编辑节点”文案。

**Architecture:** 以规格文档为单一事实来源，先做术语与约束一致性清理，再移除无效标签组件与跳过测试，最后更新本地化文案并跑全量测试。

**Tech Stack:** Markdown 规格文档、Flutter/Dart、Rust、Flutter 测试、Cargo 测试

---

### Task 1: 领域规格一致性整理

**Files:**
- Modify: `docs/specs/domain/card.md`
- Modify: `docs/specs/domain/pool.md`
- Modify: `docs/specs/domain/sync.md`
- Modify: `docs/specs/domain/types.md`

**Step 1: 写入需要澄清/补齐的规格条目（文档视为测试）**

```text
- 确认 last_edit_peer/owner_type/pool_id 规则语义清晰
- 确认节点昵称与成员列表约束完整
```

**Step 2: 运行检查以定位不一致术语**

Run: `rg -n "最后编辑设备|last_edit_device|tag|标签" docs/specs/domain`
Expected: 命中旧术语（若有）

**Step 3: 更新领域规格条目为最新规则**

```text
- 用 last_edit_peer 与节点语义统一字段描述
- 删除任何残留标签/设备表述
```

**Step 4: 复查是否清除旧术语**

Run: `rg -n "最后编辑设备|last_edit_device|tag|标签" docs/specs/domain`
Expected: 无匹配

**Step 5: Commit（用户未要求则跳过）**

```bash
git add docs/specs/domain/*.md
git commit -m "docs: align domain specs"
```

---

### Task 2: 架构规格一致性整理

**Files:**
- Modify: `docs/specs/architecture/storage/dual_layer.md`
- Modify: `docs/specs/architecture/storage/card_store.md`
- Modify: `docs/specs/architecture/storage/pool_store.md`
- Modify: `docs/specs/architecture/storage/device_config.md`
- Modify: `docs/specs/architecture/storage/sqlite_cache.md`
- Modify: `docs/specs/architecture/storage/loro_integration.md`
- Modify: `docs/specs/architecture/sync/service.md`
- Modify: `docs/specs/architecture/sync/peer_discovery.md`
- Modify: `docs/specs/architecture/sync/subscription.md`
- Modify: `docs/specs/architecture/sync/conflict_resolution.md`
- Modify: `docs/specs/architecture/security/password.md`
- Modify: `docs/specs/architecture/security/privacy.md`

**Step 1: 写入需要澄清/补齐的架构约束**

```text
- 同步仅校验 pool_id 哈希
- 加入时才校验 secretkey 哈希
- mDNS 仅加入后启用
```

**Step 2: 运行检查定位旧约束**

Run: `rg -n "secretkey|密钥|哈希|mDNS" docs/specs/architecture`
Expected: 命中条目（用于核对）

**Step 3: 更新架构规格条目为最新规则**

```text
- 统一同步与加入校验逻辑描述
- 校对隐私与发现的约束一致
```

**Step 4: 复查关键词仍与最新规则一致**

Run: `rg -n "同步时.*secretkey|加入前.*mDNS" docs/specs/architecture`
Expected: 无匹配

**Step 5: Commit（用户未要求则跳过）**

```bash
git add docs/specs/architecture/**/*.md
git commit -m "docs: align architecture specs"
```

---

### Task 3: 功能规格一致性整理

**Files:**
- Modify: `docs/specs/features/README.md`
- Modify: `docs/specs/features/card/README.md`
- Modify: `docs/specs/features/card/creation.md`
- Modify: `docs/specs/features/card/editing.md`
- Modify: `docs/specs/features/card/viewing.md`
- Modify: `docs/specs/features/card/deletion.md`
- Modify: `docs/specs/features/card/list_search_filter.md`
- Modify: `docs/specs/features/pool/README.md`
- Modify: `docs/specs/features/pool/creation.md`
- Modify: `docs/specs/features/pool/joining.md`
- Modify: `docs/specs/features/pool/leaving.md`
- Modify: `docs/specs/features/pool/discovery.md`
- Modify: `docs/specs/features/pool/sync.md`
- Modify: `docs/specs/features/pool/members.md`
- Modify: `docs/specs/features/pool/settings.md`
- Modify: `docs/specs/features/pool/auth_security.md`
- Modify: `docs/specs/features/pool/single_pool_constraint.md`
- Modify: `docs/specs/features/pool/info_view.md`
- Modify: `docs/specs/features/settings/README.md`
- Modify: `docs/specs/features/settings/appearance.md`
- Modify: `docs/specs/features/settings/app_info.md`

**Step 1: 写入需要澄清/补齐的功能条目**

```text
- 搜索仅限标题/内容
- 加入仅二维码 + 手动密钥
- 同步仅校验 pool_id 哈希
- 取消所有标签功能描述
```

**Step 2: 运行检查定位旧描述**

Run: `rg -n "标签|tag|设备.*编辑|last_edit_device" docs/specs/features`
Expected: 命中旧描述（若有）

**Step 3: 更新功能规格条目为最新规则**

```text
- 清理标签相关叙述
- 统一节点/peer 术语
```

**Step 4: 复查是否清除旧描述**

Run: `rg -n "标签|tag|last_edit_device" docs/specs/features`
Expected: 无匹配

**Step 5: Commit（用户未要求则跳过）**

```bash
git add docs/specs/features/**/*.md
git commit -m "docs: align feature specs"
```

---

### Task 4: 移除标签相关代码与跳过测试

**Files:**
- Delete: `lib/widgets/tag_filter_bar.dart`
- Delete or Modify: `test/feature/integration/home_screen_search_feature_test.dart.skip`
- Delete or Modify: `test/feature/integration/home_screen_flow_feature_test.dart.skip`
- Delete or Modify: `test/feature/integration/toast_notification_feature_test.dart.skip`

**Step 1: 写入“移除标签残留”的失败检查**

Run: `rg -n "tags?|TagFilterBar" lib test/feature/integration/*.skip`
Expected: 命中标签残留

**Step 2: 删除无用组件与跳过测试中的标签内容**

```text
- 移除 tag_filter_bar.dart
- 若 .skip 文件仅包含标签相关测试则删除，否则仅删除标签段落
```

**Step 3: 复查是否清除残留**

Run: `rg -n "tags?|TagFilterBar" lib test/feature/integration/*.skip`
Expected: 无匹配

**Step 4: Commit（用户未要求则跳过）**

```bash
git add lib/widgets/tag_filter_bar.dart test/feature/integration/*.skip
git commit -m "refactor: remove tag feature remnants"
```

---

### Task 5: 更新“最后编辑节点”文案

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

**Step 1: 写入需要变更的文案条目**

```text
- noteEditorFullscreenLastEditDevice -> 最后编辑节点
- English wording aligned to peer/node
```

**Step 2: 修改 ARB 文案**

```text
- zh: "最后编辑节点: {peer}"
- en: "Last edited by: {peer}"
```

**Step 3: 复查文案只在 ARB 中存在**

Run: `rg -n "noteEditorFullscreenLastEditDevice" lib/l10n`
Expected: 仅 ARB 中命中

**Step 4: Commit（用户未要求则跳过）**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb
git commit -m "docs: update last edit peer wording"
```

---

### Task 6: 全量验证

**Files:**
- Test: `flutter test`
- Test: `cd rust && cargo test`

**Step 1: 运行 Flutter 测试**

Run: `flutter test`
Expected: `All tests passed!`

**Step 2: 运行 Rust 测试**

Run: `cd rust && cargo test`
Expected: `test result: ok`

**Step 3: Commit（用户未要求则跳过）**

```bash
git add -A
git commit -m "chore: verify specs and cleanup"
```
