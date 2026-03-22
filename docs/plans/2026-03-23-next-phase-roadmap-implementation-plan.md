# Next Phase Roadmap Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 以 Rust 作为主实现层，落地 `Phase 1` 的“跨设备延续成立 + 最低恢复能力成立”基线，并让 Flutter 仅负责如实呈现这些后端契约。

**Architecture:** 按 `docs/specs/architecture.md` 的分层约束执行：Rust 负责同步状态、错误语义、恢复动作边界与“是否仍是同一份数据”的稳定契约；FRB 只做跨语言边界传输；Flutter 只消费 Rust DTO 并呈现 UI 反馈。本计划先收紧规格，再从 Rust contract/integration tests 入手定义 `Phase 1` 语义，随后修改 Rust 同步主链与 API 输出，最后只做必要的 Flutter 展示对齐与回归验证。

**Tech Stack:** Rust、Flutter/Dart、flutter_rust_bridge、Markdown 规格文档、`cargo test`、`flutter test`、git

---

## File Structure

- Modify: `docs/specs/ui-interaction.md`
  - 补齐 `Phase 1` 在交互层的可观察约束，但不把业务判断下沉到 Flutter。
- Modify: `docs/specs/pool.md`
  - 补齐池域内最低恢复能力语义：同一份数据判断、内容安全边界、下一步动作。
- Modify: `rust/src/net/pool_network.rs`
  - 作为当前同步主链，收紧 `sync_state / sync_push / sync_pull / last_sync_error` 相关语义输出。
- Modify: `rust/src/api.rs`
  - 把 Rust 内部同步语义暴露为稳定 API/FRB 契约，供 Flutter 消费。
- Modify: `rust/src/models/api_error.rs`
  - 仅在需要新增或收紧稳定错误码时修改。
- Test: `rust/tests/contract/api/sync_api_contract.rs`
  - 锁定对外同步状态/错误契约。
- Test: `rust/tests/integration/sync/api_flow_test.rs`
  - 锁定 API 层最小恢复能力语义。
- Test: `rust/tests/integration/sync/network_flow_test.rs`
  - 锁定跨节点“同一份数据延续”主路径。
- Test: `rust/tests/integration/sync/pool_sync_test.rs`
  - 锁定池域同步与恢复动作的端到端语义。
- Test: `rust/tests/unit/net/pool_network_sync_test.rs`
  - 锁定 `PoolNetwork` 内部状态转换与错误码边界。
- Modify: `lib/features/sync/sync_service.dart`
  - 仅对齐 Flutter 对 Rust 契约的消费方式，不新增业务判断。
- Modify: `lib/features/pool/pool_page.dart`
  - 仅把 Rust 已定义的“当前状态 / 内容安全 / 下一步动作”可视化到池域局部反馈。
- Test: `test/widget/components/sync_state_test.dart`
  - 锁定 Flutter 对 Rust 同步 DTO 的映射展示，不复制 Rust 规则。
- Test: `test/integration/features/pool_sync_test.dart`
  - 锁定池页 UI 对 Rust 恢复语义的呈现。
- Verify: `docs/plans/DIR.md`
  - 确保本实施计划索引条目存在。

---

## Chunk 1: Tighten The Phase 1 Truth Source

### Task 1: Align `docs/specs/ui-interaction.md` to Rust-first Phase 1 delivery

**Files:**
- Modify: `docs/specs/ui-interaction.md`
- Reference: `docs/plans/2026-03-23-next-phase-roadmap-design.md`
- Reference: `docs/specs/architecture.md`

- [ ] **Step 1: Write the failing spec checklist**

Record this checklist before editing:

```text
1. 是否明确 Rust 输出同步/恢复真相，Flutter 只负责展示
2. 是否把 Phase 1 交互验证收束为“同一份数据 / 内容安全 / 下一步动作”
3. 是否继续保证池域反馈局部可见且不阻断卡片域本地记录
4. 是否没有把 Phase 2 系统性恢复提前写成近期实现要求
```

- [ ] **Step 2: Verify current mismatch**

Run: `rg "同一份数据|内容安全|下一步|局部反馈|Flutter|Rust" docs/specs/ui-interaction.md`
Expected: 命中部分相关语义，但尚未完整表达上述 4 条 checklist

- [ ] **Step 3: Apply the minimum spec update**

Only modify:

- `4.3 反馈时机`
- `4.4 空态与错误态`
- `4.8 关键流程语义（主页/卡片/数据池/数据池域同步反馈）`

If needed, add at most one small subsection under `4.8` named `Phase 1 最低恢复能力`.

The new spec text must make these constraints explicit:

- 近期 Phase 1 的交互验收围绕“跨设备延续成立”
- 交互层只验证 Rust 输出的稳定语义是否被正确呈现
- 用户可感知结果必须回答：是不是同一份数据、内容是否安全、下一步是什么
- 卡片域本地记录在同步降级下仍不得被阻断

- [ ] **Step 4: Verify alignment**

Run: `rg "同一份数据|内容安全|下一步|局部反馈|不阻断本地卡片读写" docs/specs/ui-interaction.md`
Expected: 命中新语义

Run: `rg "Phase 2|系统性恢复|长期信任稳定" docs/specs/ui-interaction.md`
Expected: 不新增“近期必须实现”的相关语义

- [ ] **Step 5: Run formatting verification**

Run: `git diff --check`
Expected: no whitespace or patch formatting issues

- [ ] **Step 6: Commit task 1**

```bash
git add docs/specs/ui-interaction.md
git commit -m "docs: align phase1 interaction rules with rust-first delivery"
```

### Task 2: Align `docs/specs/pool.md` to minimum recovery semantics

**Files:**
- Modify: `docs/specs/pool.md`
- Reference: `docs/plans/2026-03-23-next-phase-roadmap-design.md`
- Reference: `docs/specs/architecture.md`

- [ ] **Step 1: Write the failing pool-spec checklist**

```text
1. 是否明确池域最低恢复能力由 Rust 契约定义，而不是 Flutter 发明
2. 是否要求池域能回答“是否仍是同一份数据/同一条延续路径”
3. 是否要求池域能回答“内容是否安全 / 下一步动作是什么”
4. 是否没有把协作扩展或复杂恢复流程提前写入近期范围
```

- [ ] **Step 2: Verify current mismatch**

Run: `rg "同步|恢复|错误|重试|重新连接|同一份数据|延续" docs/specs/pool.md`
Expected: 命中池域同步/错误内容，但尚未完整覆盖 checklist

- [ ] **Step 3: Apply the smallest pool-spec update**

Only modify:

- `6.2 成员间同步`
- `7. 错误语义与恢复`
- `8.1 最小验收集`

If needed, add at most one small subsection under section 7 named `最低恢复能力（Phase 1）`.

The new text must make these constraints explicit:

- Rust 负责定义池域同步/恢复稳定契约
- 池域最低恢复能力必须回答：是否仍是同一份数据、内容是否安全、下一步动作
- 轻度异常下必须存在局部可恢复动作
- 不得把复杂协作恢复流转扩张为近期主路径

- [ ] **Step 4: Verify alignment**

Run: `rg "同一份数据|延续|内容安全|下一步|重试|重新连接" docs/specs/pool.md`
Expected: 命中最低恢复能力三要素与恢复动作语义

Run: `rg "Phase 2|Phase 3|系统性恢复|长期信任稳定" docs/specs/pool.md`
Expected: 不新增为当前近期实现项

- [ ] **Step 5: Run formatting verification**

Run: `git diff --check`
Expected: no whitespace or patch formatting issues

- [ ] **Step 6: Commit task 2**

```bash
git add docs/specs/pool.md
git commit -m "docs: align pool phase1 recovery semantics"
```

---

## Chunk 2: Define Phase 1 Truth In Rust Contracts First

### Task 3: Lock the external sync contract before implementation

**Files:**
- Modify: `rust/tests/contract/api/sync_api_contract.rs`
- Modify: `rust/tests/integration/sync/api_flow_test.rs`
- Modify: `rust/tests/integration/sync/network_flow_test.rs`
- Modify: `rust/tests/integration/sync/pool_sync_test.rs`

- [ ] **Step 1: Write failing Rust tests for Phase 1 semantics**

Add or extend tests to express these outcomes:

```rust
#[test]
fn sync_status_should_tell_whether_user_is_still_on_the_same_data_path() {
    // status/result distinguishes continuity from restart semantics
}

#[test]
fn sync_result_should_distinguish_content_safe_from_sync_not_finished() {
    // write success + projection pending + sync failed remain distinguishable
}

#[test]
fn sync_contract_should_expose_explicit_next_action_for_minimum_recovery() {
    // retry / reconnect / recheck-status semantics are contractually visible
}
```

- [ ] **Step 2: Run the focused Rust tests to verify RED**

Run:

```bash
cargo test --test integration api_integration_test::api_pool_network_lifecycle_and_sync_state -- --exact
cargo test --test integration api_integration_test::api_sync_status_returns_degraded_when_projection_pending -- --exact
cargo test --test unit pool_network_sync_test::test_sync_state_priority_over_session_state -- --exact
cargo test --test unit pool_network_sync_test::test_sync_push_sets_error_code -- --exact
cargo test --test unit pool_network_sync_test::test_sync_pull_sets_error_code -- --exact
```

Expected: 至少部分 FAIL，因为当前 contract 还未完整编码所有 Phase 1 语义

- [ ] **Step 3: Refine the tests until they describe only Phase 1**

Before touching implementation, confirm the tests do **not** require:

- Phase 2 system-level recovery orchestration
- collaboration expansion
- Flutter-specific display wording

- [ ] **Step 4: Commit the RED contract tests**

```bash
git add rust/tests/contract/api/sync_api_contract.rs rust/tests/integration/sync/api_flow_test.rs rust/tests/integration/sync/network_flow_test.rs rust/tests/integration/sync/pool_sync_test.rs
git commit -m "test(sync): define phase1 continuity contract"
```

### Task 4: Implement the minimum Rust contract to satisfy Phase 1

**Files:**
- Modify: `rust/src/net/pool_network.rs`
- Modify: `rust/src/api.rs`
- Optional Modify: `rust/src/models/api_error.rs`
- Test: `rust/tests/contract/api/sync_api_contract.rs`
- Test: `rust/tests/integration/sync/api_flow_test.rs`
- Test: `rust/tests/integration/sync/network_flow_test.rs`
- Test: `rust/tests/integration/sync/pool_sync_test.rs`
- Test: `rust/tests/unit/net/pool_network_sync_test.rs`

- [ ] **Step 1: Run the focused Rust suite from Task 3**

Run:

```bash
cargo test --test integration api_integration_test::api_pool_network_lifecycle_and_sync_state -- --exact
cargo test --test integration api_integration_test::api_sync_status_returns_degraded_when_projection_pending -- --exact
cargo test --test unit pool_network_sync_test::test_sync_state_priority_over_session_state -- --exact
cargo test --test unit pool_network_sync_test::test_sync_push_sets_error_code -- --exact
cargo test --test unit pool_network_sync_test::test_sync_pull_sets_error_code -- --exact
```

Expected: FAIL

- [ ] **Step 2: Implement the smallest Rust change**

Apply only the changes needed so Rust can output stable Phase 1 semantics:

- `PoolNetwork` can distinguish continuity-safe degraded states from restart/break states
- API output makes “同一份数据 / 内容安全 / 下一步动作” derivable without Flutter inventing logic
- if needed, add or tighten stable error codes in `api_error.rs`

Do not implement Phase 2 system recovery orchestration.

- [ ] **Step 3: Add/extend unit coverage for `PoolNetwork`**

Use `rust/tests/unit/net/pool_network_sync_test.rs` to lock:

- `sync_state()` transitions
- `last_sync_error_code()` semantics
- `sync_push()` / `sync_pull()` minimum recovery outcomes

- [ ] **Step 4: Run Rust tests to verify GREEN**

Run:

```bash
cargo test --test integration api_integration_test::api_pool_network_lifecycle_and_sync_state -- --exact
cargo test --test integration api_integration_test::api_sync_status_returns_degraded_when_projection_pending -- --exact
cargo test --test unit pool_network_sync_test::test_sync_state_priority_over_session_state -- --exact
cargo test --test unit pool_network_sync_test::test_sync_push_sets_error_code -- --exact
cargo test --test unit pool_network_sync_test::test_sync_pull_sets_error_code -- --exact
```

Expected: PASS

- [ ] **Step 5: Blue refactor**

- keep continuity/recovery contract mapping centralized in Rust
- remove duplicated status/error mapping logic if introduced
- keep FRB-facing output stable and minimal

- [ ] **Step 6: Re-run focused Rust verification**

Run:

```bash
cargo test --test integration api_integration_test::api_pool_network_lifecycle_and_sync_state -- --exact
cargo test --test integration api_integration_test::api_sync_status_returns_degraded_when_projection_pending -- --exact
cargo test --test unit pool_network_sync_test::test_sync_state_priority_over_session_state -- --exact
cargo test --test unit pool_network_sync_test::test_sync_push_sets_error_code -- --exact
cargo test --test unit pool_network_sync_test::test_sync_pull_sets_error_code -- --exact
```

Expected: PASS

- [ ] **Step 7: Commit task 4**

```bash
git add rust/src/net/pool_network.rs rust/src/api.rs rust/src/models/api_error.rs rust/tests/contract/api/sync_api_contract.rs rust/tests/integration/sync/api_flow_test.rs rust/tests/integration/sync/network_flow_test.rs rust/tests/integration/sync/pool_sync_test.rs rust/tests/unit/net/pool_network_sync_test.rs
git commit -m "feat(sync): encode phase1 continuity semantics in rust"
```

If `rust/src/models/api_error.rs` was unchanged, do not stage it.

---

## Chunk 3: Keep Flutter As A Thin Consumer Of Rust Truth

### Task 5: Align Flutter sync mapping with the Rust contract

**Files:**
- Modify: `lib/features/sync/sync_service.dart`
- Test: `test/widget/components/sync_state_test.dart`
- Optional Test: `test/unit/presentation/sync_service_test.dart`

- [ ] **Step 1: Write the failing Flutter-facing contract test**

Extend `test/widget/components/sync_state_test.dart` so it verifies:

```dart
test('flutter should surface rust continuity semantics without adding new business rules', () async {
  // dto -> SyncStatus mapping preserves same-data / safe-content / next-action meaning
});
```

- [ ] **Step 2: Run focused Flutter tests to verify RED**

Run: `flutter test test/widget/components/sync_state_test.dart test/unit/presentation/sync_service_test.dart`
Expected: FAIL if Flutter mapping still hides or distorts the new Rust contract

- [ ] **Step 3: Implement the minimal Flutter change**

Limit changes to:

- consuming the Rust/FRB contract faithfully in `sync_service.dart`
- keeping Flutter-side mapping declarative
- not creating new business states beyond what Rust already defines

- [ ] **Step 4: Run focused Flutter tests to verify GREEN**

Run: `flutter test test/widget/components/sync_state_test.dart test/unit/presentation/sync_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit task 5**

```bash
git add lib/features/sync/sync_service.dart test/widget/components/sync_state_test.dart test/unit/presentation/sync_service_test.dart
git commit -m "refactor(sync): align flutter mapping with rust contract"
```

If `test/unit/presentation/sync_service_test.dart` was unchanged, do not stage it.

### Task 6: Make pool-page recovery feedback display the Rust truth

**Files:**
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/integration/features/pool_sync_test.dart`

- [ ] **Step 1: Write the failing pool-page feedback test**

Add or extend tests so they verify pool-page feedback can visibly answer:

```text
1. 当前是不是仍在同一条延续路径
2. 内容是否安全/仍可继续本地操作
3. 下一步是等待、重试还是重新连接
```

The test must assert display of Rust-provided semantics, not Flutter-invented rules.

- [ ] **Step 2: Run the focused pool-page test to verify RED**

Run: `flutter test test/integration/features/pool_sync_test.dart`
Expected: FAIL if current UI wording cannot faithfully express the Rust contract

- [ ] **Step 3: Implement the minimal pool-page change**

Only change local feedback rendering in `PoolPage`:

- keep feedback local to pool domain
- render the Rust continuity/recovery semantics clearly
- do not add global banners or multi-step recovery flows

- [ ] **Step 4: Run the focused pool-page test to verify GREEN**

Run: `flutter test test/integration/features/pool_sync_test.dart`
Expected: PASS

- [ ] **Step 5: Run a small safety net**

Run: `flutter test test/integration/features/cards_sync_navigation_test.dart test/widget/pages/pool_page_test.dart`
Expected: PASS

- [ ] **Step 6: Commit task 6**

```bash
git add lib/features/pool/pool_page.dart test/integration/features/pool_sync_test.dart test/integration/features/cards_sync_navigation_test.dart test/widget/pages/pool_page_test.dart
git commit -m "feat(pool): show rust phase1 recovery feedback"
```

If a listed test file was unchanged, do not stage it.

---

## Chunk 4: Final Verification And Handoff

### Task 7: Verify plan registration and Phase 1 handoff outputs

**Files:**
- Verify: `docs/plans/DIR.md`

- [ ] **Step 1: Verify this plan is indexed**

Run: `rg "2026-03-23-next-phase-roadmap-implementation-plan.md" docs/plans/DIR.md`
Expected: hit the current plan entry

- [ ] **Step 2: Record the implementation handoff outputs in working notes**

Create this checklist:

```text
1. 近期主清单：仅含 Phase 1 工作项
2. defer 清单：最小可信设置中心、协作扩展、Phase 2 系统性恢复
3. Rust 契约验证清单：sync_api_contract/api_flow/network_flow/pool_sync/unit tests
   - 当前仓库以 `integration` / `unit` 聚合 target 运行，并通过 test name filter 精确命中相关场景。
4. Flutter 展示验证清单：sync_state_test、pool_sync_test、cards_sync_navigation_test
```

- [ ] **Step 3: Run Rust verification**

Run: `cargo test`
Expected: PASS

- [ ] **Step 4: Run Flutter verification**

Run: `flutter test`
Expected: PASS

- [ ] **Step 5: Run formatting verification**

Run: `git diff --check`
Expected: no whitespace or patch formatting issues

- [ ] **Step 6: Commit this chunk only if a tracked file changed**

If this chunk changed a tracked file, commit it. Otherwise do not create an empty commit.

---

## Defer List

- [ ] `最小可信设置中心`
  - 延后原因：当前不能比“跨设备延续成立”更直接证明产品核心价值。
  - 重开条件：设置能力已明确成为主路径理解、延续或恢复的必要支点。
  - 所属后续阶段：阶段外独立设计议题。

- [ ] `数据池协作扩展能力`
  - 延后原因：当前会分散个人多设备主路径注意力。
  - 重开条件：`Phase 1` 与 `Phase 2` 已基本成立，且候选扩展能力能直接增强主路径流转。
  - 所属后续阶段：`Phase 3` 优先级重评估。

- [ ] `Phase 2 系统性恢复能力`
  - 延后原因：近期只要求最低恢复能力，不要求复杂恢复编排。
  - 重开条件：`Phase 1` 已证明用户不会因轻度波动或单步受阻而误判主路径断裂。
  - 所属后续阶段：`Phase 2`。

---

## Final Verification

Run:

```bash
cargo test --test integration api_integration_test::api_pool_network_lifecycle_and_sync_state -- --exact
cargo test --test integration api_integration_test::api_sync_status_returns_degraded_when_projection_pending -- --exact
cargo test --test unit pool_network_sync_test::test_sync_state_priority_over_session_state -- --exact
cargo test --test unit pool_network_sync_test::test_sync_push_sets_error_code -- --exact
cargo test --test unit pool_network_sync_test::test_sync_pull_sets_error_code -- --exact
```

Expected: PASS

- [ ] Run: `flutter test test/widget/components/sync_state_test.dart test/integration/features/pool_sync_test.dart test/integration/features/cards_sync_navigation_test.dart`
Expected: PASS

- [ ] Run: `git status --short`
Expected: working tree clean after all planned commits
