input: 现有 AGENTS/docs/specs/docs/plans/docs/standards 的职责混淆现状，以及新的文档结构重构目标。
output: 文档体系结构性重构实施计划，明确目标结构、迁移顺序、逐文档处理策略与验收标准。
pos: 指导将仓库文档体系重构为“入口文档 + 正式规格 + 变更计划 + 长期标准”的低歧义结构。

# Documentation Structure Refactor Implementation Plan

**Goal:** Reorganize the repository documentation system so contributors and AI agents can consistently distinguish product truth (`specs`), change plans (`plans`), long-lived rules (`standards`), and the repository entrypoint (`AGENTS.md`).

**Architecture:** The refactor is documentation-first. It starts by defining a stable document role model, then rewrites the entrypoint and standards around that model, and finally migrates or retires conflicting legacy rules. The core change is replacing the current blanket "spec-first for everything" interpretation with a lifecycle rule based on whether formal product behavior changes.

**Tech Stack:** Markdown governance documents, repository conventions, AI-agent collaboration workflow.

---

## Target Structure

### 1. `AGENTS.md`

- Role: repository entrypoint and collaboration contract.
- Contains:
  - project goal and structure,
  - build / test / verification commands,
  - document type definitions,
  - AI execution entry rules,
  - references to canonical standards.
- Must not contain:
  - over-detailed phase choreography,
  - hard-coded default worktree / push / merge actions,
  - duplicated standards that belong in `docs/standards/`.

### 2. `docs/specs/`

- Role: source of truth for the system's currently confirmed formal behavior.
- Contains:
  - product behavior,
  - business rules,
  - state transitions,
  - error handling expectations,
  - acceptance criteria,
  - explicit non-goals.
- Must not contain:
  - implementation steps,
  - technical decomposition,
  - temporary design alternatives,
  - task execution order.

### 3. `docs/plans/`

- Role: design and implementation plans for a specific change.
- Contains:
  - context and motivation,
  - design decisions,
  - task breakdown,
  - risks,
  - sequencing,
  - validation strategy.
- Is not the long-term product truth source.

### 4. `docs/standards/`

- Role: long-lived engineering and collaboration rules.
- Contains only rules that are:
  - reusable across multiple changes,
  - stable over time,
  - explicit enough for AI execution and human review.

---

## Core Governance Decisions

### Decision 1: Spec definition

Canonical definition:

> A spec describes the system's currently confirmed formal behavior, constraints, and acceptance criteria. It defines how the system should behave, not how a specific change will be implemented.

### Decision 2: Spec update trigger

Canonical rule:

> Specs are updated when formal product behavior has been confirmed to change, not merely because implementation work is about to start.

Implications:

- exploration does not automatically update `docs/specs/`;
- confirmed behavior changes do update `docs/specs/`;
- restoring existing intended behavior usually does not require a spec update;
- pure engineering refactors usually do not require a spec update.

### Decision 3: Plans are not specs

Canonical rule:

> Plans describe how a change will be executed. Specs describe what the system should formally do.

### Decision 4: AI execution gate

Canonical rule:

> Before implementation, AI must confirm the goal, scope, and acceptance criteria. Whether `docs/specs/` must change depends on whether the task changes confirmed product behavior.

---

## Task Classification Model

### Class A: Formal behavior changes

Examples:

- new feature,
- user-visible behavior change,
- data model rule change,
- sync semantics change,
- Flutter/Rust/FRB contract change.

Required flow:

1. clarify and confirm behavior change;
2. update `docs/specs/`;
3. write or update `docs/plans/`;
4. implement;
5. verify implementation matches the updated spec.

### Class B: Scoped behavioral adjustments

Examples:

- bounded UX enhancement,
- medium-sized local rule extension,
- partial behavior hardening with clear acceptance scope.

Required flow:

1. clarify goal, scope, and acceptance criteria;
2. decide whether the confirmed behavior meaningfully changes;
3. update `docs/specs/` only if the formal behavior changes;
4. create a plan or equivalent implementation breakdown;
5. implement and verify.

### Class C: Restorative or engineering-only work

Examples:

- bugfix restoring existing intended behavior,
- refactor,
- test additions,
- lint/build repair,
- automation anchor additions.

Required flow:

1. confirm it does not redefine product behavior;
2. implement directly;
3. explain impact scope in the final delivery;
4. upgrade to Class A/B if implementation reveals a real behavior change.

---

## Document-by-Document Migration Strategy

### 1. `AGENTS.md`

Action: **rewrite and slim down**.

Keep:

- project overview,
- repository structure,
- canonical build/test commands,
- runtime truth notes such as the official macOS dylib path,
- references to `specs`, `plans`, and `standards`.

Remove or downgrade:

- mandatory default worktree creation for every task,
- mandatory dual-agent confrontation for every change,
- mandatory commit-per-TDD-stage requirements,
- default merge/push expectations.

Add:

- document role model,
- spec lifecycle summary,
- AI document reading order,
- task classification entry rule.

### 2. `docs/standards/spec-first-execution.md`

Action: **replace with spec lifecycle governance standard**.

Recommended rename:

- `docs/standards/spec-lifecycle.md`
  or
- `docs/standards/spec-governance.md`

New responsibilities:

- define what a spec is,
- define when a spec changes,
- define spec vs plan boundaries,
- define Class A/B/C execution rules,
- define what to do when behavior intent is unclear.

### 3. `docs/standards/ai-collaboration.md`

Action: **rewrite as an execution protocol**.

Replace the current heavy default dual-agent narrative with a scaled model:

- small task: clarify -> implement -> verify;
- medium task: clarify -> plan -> implement -> review -> verify;
- large task: spec -> plan -> implement -> review -> full quality gate.

Dual-agent review should become an optional high-rigor strategy for complex work, not a blanket requirement.

### 4. `docs/standards/tdd.md`

Action: **retain, but narrow the applicability language**.

Keep:

- Red -> Green -> Blue -> Verify/Commit as the preferred engineering loop for code changes.

Add:

- which task classes require full TDD,
- which documentation-only or mechanical tasks do not,
- how verification scope maps to change scope.

### 5. `docs/standards/testing.md`

Action: **compress into rules, move examples out**.

Keep:

- test directory conventions,
- Rust test entrypoint rules,
- naming rules,
- boundary priority rules.

Remove or move:

- long teaching-style templates,
- speculative or non-enforced coverage thresholds,
- scanner implementation details that may drift from tooling reality.

### 6. `docs/standards/tech-stack-baseline.md`

Action: **retain and repair drift**.

Required cleanup:

- remove or fix references to missing standards files,
- separate factual baseline from governance rules,
- preserve version lockstep and build/runtime truth constraints.

### 7. `docs/standards/git-and-pr.md`

Action: **either strengthen or merge elsewhere**.

If retained, it must define:

- commit message conventions,
- what verification evidence a PR must include,
- expectations for UI / contract / FRB-affecting changes.

If not strengthened, merge the surviving content into `AGENTS.md`.

### 8. `docs/standards/coding-style.md`

Action: **either strengthen or merge elsewhere**.

If retained, it must include project-level guidance not already obvious from linting, such as:

- naming and explicitness preferences,
- acceptable comment usage,
- reuse vs abstraction thresholds,
- code shape expectations relevant to AI contributors.

If not strengthened, merge the surviving content into `AGENTS.md` or `tdd.md`.

### 9. `docs/standards/flutter-automation-anchors.md`

Action: **retain with a narrower applicability note**.

Add one clarifying rule:

- apply to new or touched critical interaction surfaces first;
- do not require unrelated retrofitting across the whole repository during every UI change.

### 10. `docs/standards/docs-dir-indexing.md`

Action: **delete or sharply downgrade**.

Reason:

- it imposes high-maintenance metadata work,
- it is not proportional to contributor or AI value,
- it shifts effort from solving problems to maintaining navigation ceremony.

If any part is retained, keep only a lightweight indexing recommendation for key directories.

### 11. `docs/standards/DIR.md`

Action: **retain only as directory index**.

Do not keep it as a central governance mechanism.

### 12. `docs/DIR.md`

Action: **update wording to match the new role model**.

It should explicitly say:

- `plans/` are historical or change-scoped artifacts,
- `specs/` are the current formal truth source,
- `standards/` are long-lived rules,
- `AGENTS.md` is the repository entrypoint.

---

## Migration Phases

## Phase 1: Freeze the role model

**Goal:** establish the new document definitions before rewriting any dependent text.

### Task 1.1

- Write the canonical definitions for `AGENTS.md`, `docs/specs/`, `docs/plans/`, and `docs/standards/`.
- Write the spec lifecycle rules and A/B/C task classification model.

### Task 1.2

- Review all current references to `spec-first` and mark whether they remain valid, need rewrite, or should be deleted.

**Exit criteria:**

- there is a single agreed definition for spec, plan, standard, and repository entrypoint;
- contributors can tell when a spec must change and when it must not.

## Phase 2: Rewrite the entrypoint

**Goal:** make `AGENTS.md` reflect the new system instead of the old blanket workflow.

### Task 2.1

- Rewrite `AGENTS.md` around:
  - project summary,
  - structure,
  - canonical commands,
  - document role model,
  - AI execution entry rules.

### Task 2.2

- Remove redundant or over-prescriptive workflow text that now belongs in standards.

**Exit criteria:**

- reading `AGENTS.md` alone does not imply all work must run a heavyweight universal spec-first pipeline.

## Phase 3: Rebuild standards around the new model

**Goal:** convert `docs/standards/` into a small set of high-trust, executable rules.

### Task 3.1

- Replace `spec-first-execution.md` with the new spec lifecycle standard.

### Task 3.2

- Rewrite `ai-collaboration.md` into a scaled execution protocol.

### Task 3.3

- Update `tdd.md` to define applicability boundaries.

### Task 3.4

- Compress `testing.md` into a rule-oriented document.

### Task 3.5

- Repair `tech-stack-baseline.md` drift.

### Task 3.6

- Strengthen or merge `git-and-pr.md` and `coding-style.md`.

### Task 3.7

- Rename and retain it as a docs-only indexing note (`docs-dir-indexing.md`), or remove it if the guidance is folded elsewhere.

**Exit criteria:**

- each remaining standard has a clear scope and low overlap;
- no standard depends on an outdated definition of spec or plan.

## Phase 4: Clean indexes and references

**Goal:** ensure the repository no longer contains contradictory navigation or obsolete rule references.

### Task 4.1

- Update `docs/DIR.md`, `docs/plans/DIR.md`, `docs/standards/DIR.md`, and any affected `docs/specs/` index text.

### Task 4.2

- Search for stale mentions of:
  - blanket spec-first wording,
  - deprecated documentation rules,
  - removed standard filenames.

### Task 4.3

- Normalize wording so the same concept is described once canonically and referenced elsewhere.

**Exit criteria:**

- no index or entrypoint text contradicts the new role model;
- directory descriptions match actual usage.

---

## Recommended Execution Order

1. create and approve the role model;
2. rewrite `AGENTS.md`;
3. replace the spec-first standard with spec lifecycle governance;
4. rewrite `ai-collaboration.md`;
5. update `tdd.md` and `testing.md`;
6. repair `tech-stack-baseline.md`;
7. decide the final scope of `docs-dir-indexing.md`;
8. update all indexes and residual references.

This order prevents downstream documents from being rewritten against an unstable definition.

---

## Verification Strategy

This refactor changes documentation structure, not product behavior. Verification should focus on coherence and executability.

### Required checks

1. `AGENTS.md` clearly distinguishes `spec`, `plan`, `standard`, and repository entrypoint responsibilities.
2. A contributor can answer, from the docs alone:
   - what a spec is,
   - when a spec changes,
   - when a plan is required,
   - which standards apply to their task.
3. No surviving document still implies that every task must update `docs/specs/` before any implementation.
4. No surviving document still treats plans as the primary long-term truth source.
5. Index files and references point only to existing, canonical documents.

### Optional validation aid

- Run a repository-wide content search for `spec-first`, `双代理`, `DIR.md`, and similar legacy anchors after each migration batch to catch stale wording early.

---

## Acceptance Criteria

This refactor is complete when all of the following are true:

1. The repository has a stable, documented role model for `AGENTS.md`, `docs/specs/`, `docs/plans/`, and `docs/standards/`.
2. The spec lifecycle rule is explicit: spec updates are triggered by confirmed formal behavior changes, not by implementation start alone.
3. `AGENTS.md` no longer encodes a blanket heavyweight workflow for all tasks.
4. `docs/standards/` contains fewer, clearer, higher-trust rules with minimal overlap.
5. `docs-dir-indexing.md` remains a lightweight docs-only note and no longer implies a repository-wide metadata regime.
6. Directory indexes reflect the new structure and do not contradict the canonical role model.

---

## Out of Scope

- rewriting individual product specs for feature content correctness,
- changing product behavior,
- updating historical plan documents except where indexes or canonical references require it,
- introducing automated doc-governance scripts as part of this refactor.
