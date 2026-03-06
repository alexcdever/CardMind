input: 已批准的“仅补丁/次版本”依赖升级设计
output: 可执行实施计划，覆盖 Flutter 与 Rust 依赖升级、验证与结果归档
pos: 以最低风险完成双端依赖保守升级并保持现有行为稳定

# Flutter + Rust Conservative Dependency Upgrade Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Upgrade Flutter and Rust dependencies using patch/minor-only strategy and keep the repository passing existing quality gates.

**Architecture:** The implementation updates dependency lockfiles first, only adjusts manifest constraints when required, and validates behavior through existing analysis/test commands. Work is split into small, auditable tasks to isolate failures and avoid cross-stack regression coupling.

**Tech Stack:** Flutter/Dart pub, Rust cargo, FRB-integrated project structure, git.

---

## Global Execution Rule

All tasks follow **Red -> Green -> Blue -> Commit**.

- Red: capture baseline state and expected upgrade opportunities.
- Green: apply minimal lockfile/constraint changes.
- Blue: clean up and ensure documentation/reporting clarity.
- Commit: only after verification commands pass.

### Task 1: Capture dependency baseline and upgrade scope

**Files:**
- Read: `pubspec.yaml`
- Read: `rust/Cargo.toml`
- Observe: `pubspec.lock`
- Observe: `rust/Cargo.lock`

**Step 1: Red - inspect Flutter outdated state**

Run: `flutter pub outdated`
Expected: command succeeds and lists outdated dependencies plus resolvable versions.

**Step 2: Red - inspect Rust outdated state**

Run: `cargo outdated -R`
Expected: command succeeds and lists direct/resolvable updates.

**Step 3: Blue - classify upgrade candidates**

Create a short note grouping candidates into:
- lockfile-only upgradable,
- manifest-constraint-limited,
- intentionally pinned (if any).

**Step 4: Commit**

No commit in this baseline-only task.

### Task 2: Apply conservative Flutter dependency upgrade

**Files:**
- Modify: `pubspec.lock`
- Potentially modify: `pubspec.yaml`

**Step 1: Red - verify current lockfile fingerprint**

Run: `git status --short pubspec.yaml pubspec.lock`
Expected: shows baseline state before Flutter upgrade.

**Step 2: Green - upgrade Flutter dependencies without major bump intent**

Run: `flutter pub upgrade`
Expected: lockfile updates to latest compatible versions under existing constraints.

**Step 3: Green (conditional) - minimal constraint adjustments**

If `flutter pub outdated` still shows resolvable patch/minor updates blocked by strict constraints, adjust only those specific constraints in `pubspec.yaml` and rerun `flutter pub upgrade`.

**Step 4: Blue - verify no accidental major migration work**

Run: `flutter pub outdated`
Expected: remaining outdated items are either major-only or intentionally constrained.

**Step 5: Commit**

Defer commit until full-stack verification passes.

### Task 3: Apply conservative Rust dependency upgrade

**Files:**
- Modify: `rust/Cargo.lock`
- Potentially modify: `rust/Cargo.toml`

**Step 1: Red - verify current Rust lock/manifest state**

Run: `git status --short rust/Cargo.toml rust/Cargo.lock`
Expected: baseline visible before Rust upgrade.

**Step 2: Green - update Rust lockfile to latest compatible versions**

Run: `cargo update`
Expected: `rust/Cargo.lock` advances compatible dependency versions.

**Step 3: Green (conditional) - minimal manifest relaxation**

If patch/minor updates are blocked by strict version pins in `rust/Cargo.toml`, relax only target constraints minimally and rerun `cargo update`.

**Step 4: Blue - confirm remaining outdated are major-only or intentionally fixed**

Run: `cargo outdated -R`
Expected: unresolved items correspond to major constraints or explicit pins.

**Step 5: Commit**

Defer commit until unified verification passes.

### Task 4: Verify Flutter and Rust quality gates

**Files:**
- Verify impacted code paths from lockfile updates

**Step 1: Red - validate changed file set**

Run: `git status --short`
Expected: dependency-related files are clearly visible.

**Step 2: Green - run Flutter analysis/tests**

Run: `flutter analyze && flutter test`
Expected: PASS.

**Step 3: Green - run Rust tests**

Run: `cargo test`
Expected: PASS.

**Step 4: Blue - perform minimal compatibility fixes if needed**

If any command fails due to dependency behavior drift, apply smallest possible code fix, rerun failing command, then rerun full verification.

**Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock rust/Cargo.toml rust/Cargo.lock
git commit -m "chore(deps): upgrade flutter and rust dependencies conservatively"
```

### Task 5: Produce upgrade report and completion checklist

**Files:**
- Optionally modify: `docs/plans/DIR.md`
- Optionally add: upgrade summary note (if team requires archival)

**Step 1: Red - capture final diff footprint**

Run: `git diff -- pubspec.yaml pubspec.lock rust/Cargo.toml rust/Cargo.lock`
Expected: only dependency-related changes.

**Step 2: Green - summarize upgrade outcome**

Report:
- upgraded packages (Flutter/Rust),
- blocked packages and reason,
- verification command results.

**Step 3: Blue - keep report concise and actionable**

Ensure summary distinguishes:
- done now,
- deferred major upgrades.

**Step 4: Verification - clean status check**

Run: `git status`
Expected: clean if committed, or staged changes only if awaiting reviewer decision.

**Step 5: Commit**

No extra commit if Task 4 commit already includes all changes.

## Done Criteria

- Flutter and Rust dependencies are upgraded within patch/minor scope.
- No intentional major-version migration work is included.
- `flutter analyze`, `flutter test`, and `cargo test` pass.
- Upgrade report clearly states completed and deferred items.
