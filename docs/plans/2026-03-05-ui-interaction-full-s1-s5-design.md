# 2026-03-05 UI Interaction Full S1-S5 Design

## 1. Background and Goal

- This design follows `docs/specs/ui-interaction.md` and lands the full S1-S5 scope.
- Scope strategy is full coverage with independent micro-iterations for `S1` to `S5`.
- Acceptance priority is interaction semantics first, then visual medium constraints.
- Governance is mandatory per iteration: update the governance docs trio and pass guard tests.

## 2. Constraints and Governance

- Source of truth: `docs/specs/ui-interaction.md`.
- Process baseline: `docs/standards/spec-first-execution.md`.
- UI governance baseline: `docs/standards/ui-interaction-governance.md`.
- Hard constraints:
  - Do not merge an `S` iteration that does not pass governance gates.
  - Keep mobile/desktop as independent UIs while preserving semantic parity.
  - Prefer observable behavior assertions over implementation-detail assertions.

## 3. Alternatives Considered

### 3.1 Option A (Selected): Semantic-first layered iteration

- For each `S` iteration, close a four-layer loop:
  1. semantic contract mapping,
  2. route/state flow alignment,
  3. visual medium constraints,
  4. tests and governance updates.
- Pros: strongest alignment with interaction-semantics-first acceptance and per-iteration gate passing.
- Cons: higher process overhead due to frequent doc and test updates.

### 3.2 Option B: Platform-first split

- Finish mobile for each `S` first, then desktop.
- Pros: lower single-platform complexity at the start.
- Cons: increased cross-platform semantic drift risk and late rework.

### 3.3 Option C: Governance-first setup

- Build governance scaffolding first, then fill all `S` implementations.
- Pros: strongest auditability.
- Cons: lower visible product progress early.

## 4. Architecture and Iteration Blueprint

- Unified semantic contract layer governs S1-S5 across two independent UIs.
- Iteration unit is one scenario slice (`S1`, `S2`, `S3`, `S4`, `S5`) with independent release and rollback.
- Per-iteration execution thread:
  1. extract MUST/FORBIDDEN clauses for target `S`,
  2. map to mobile/desktop semantic pages and trigger paths,
  3. model empty/loading/error/disabled/recoverable-failure states,
  4. validate input mapping (touch vs keyboard/mouse),
  5. update governance docs trio and run gate tests.

## 5. Components and Data Flow by Scenario

### 5.1 S1 First screen and shell back semantics

- Semantic components: `ShellRoot`, `PrimaryNav`, `ExitConfirmDialog`.
- Data flow:
  - boot to `CardsRootReady`,
  - back from non-cards shell returns to cards root,
  - back from cards root shows exit confirm.
- Rule: create/join pool entry is only exposed in pool unjoined state.

### 5.2 S2 Card management

- Semantic components: `CardsListPane`, `CardEditorPane`, `SaveStatusBanner`, `LeaveGuardDialog`, `SearchBox`.
- Data flow:
  - `CardsListReady -> EditingDraft -> SavingLocal -> SaveSuccess|SaveFailed`,
  - leaving dirty editor triggers three-way leave guard.
- Rule: save feedback is visible in-page without page leave.

### 5.3 S3 Pool management

- Semantic components: `PoolStatePanel`, `JoinActionPanel`, `ApprovalQueuePanel`, `ExitPoolDialog`, `PoolErrorActionBar`.
- Data flow:
  - `PoolUnjoined -> JoinRequesting -> PoolJoined|JoinFailed(code)`,
  - `ExitConfirm -> Exiting -> ExitDone|ExitPartialFailed`.
- Rule: error prompt is adjacent to action controls and always offers next step.

### 5.4 S4 Settings reachability

- Semantic components: `SettingsOverview`, `TroubleshootEntry`, `QuickReturnActions`.
- Data flow: `SettingsReady -> CardsRootReady` or `SettingsReady -> PoolUnjoined|PoolJoined` in one step.
- Rule: pool-related entry remains visible in upper-middle area.

### 5.5 S5 Sync exception handling

- Semantic components: `SyncHealthBanner`, `RetryReconnectActions`.
- Data flow: `SyncHealthy -> SyncDegraded -> SyncHealthy`.
- Rule: degraded state must not block local card edit/save.

## 6. Unified Error and Recovery Model

- Every failure follows one semantic tuple:
  - what happened,
  - impact scope,
  - next actionable step.
- Recovery action semantics:
  - `retry`: retry in same context,
  - `reconnect`: rebuild connectivity/session path,
  - `navigate`: route to valid continuation context.
- Danger actions (delete/exit/disband) use unified confirm structure across platforms.
- Dirty-leave protection is always three-way: save and leave / discard / cancel.
- `degraded` is persistent, actionable, and non-blocking for local editing.

## 7. Testing and Gate Matrix

- Mandatory per iteration:
  - governance docs updates:
    - `docs/specs/ui-interaction.md`
    - `docs/specs/ui-interaction.md`
    - `docs/specs/ui-interaction.md`
  - gate tests:
    - `flutter test docs/standards/ui-interaction-governance.md`
    - `flutter test test/interaction_guard_test.dart`
- Minimum scenario test coverage per `S`:
  - at least one success-path test,
  - at least one failure/interruption-path test,
  - pool scenarios include at least one stable error-code path.
- Assertion policy:
  - assert external outcomes (texts, dialogs, navigation, list/state change),
  - do not rely on internal implementation details.

## 8. Milestones and Definition of Done

- `M1 / S1`: direct cards entry + two-stage back semantics + exit confirm.
- `M2 / S2`: cards CRUD semantic closure + leave guard + save feedback.
- `M3 / S3`: pool three-state model + join-failure recovery + exit partial-failure retry.
- `M4 / S4`: settings one-step reachability to cards/pool.
- `M5 / S5`: sync degraded prompt + retry/reconnect + local-write continuity.

Per-milestone DoD:

1. MUST/FORBIDDEN clauses are mapped and implemented for target scenario.
2. Governance docs trio is updated.
3. Gate tests pass.
4. One success and one failure path are reproducibly validated.

## 9. Out of Scope

- Framework/library/style-structure choices.
- Pixel-perfect freezing and hardcoded color values.
- New business semantics beyond current `S1-S5` specification.
