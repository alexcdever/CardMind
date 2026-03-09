# 2026-03-09 Flutter Rust Backend Frontend Design

## 1. Background and Goal

- This design turns CardMind into an embedded frontend-backend architecture: Flutter acts as the frontend, Rust acts as the backend, and `flutter_rust_bridge` acts as the in-process RPC boundary.
- The immediate goal is to implement the behaviors already defined in `docs/specs/pool.md` and `docs/specs/card-note.md`, with Rust as the single source of business truth.
- The first-phase observable closed loop is: create pool, join pool, create card note, edit card note, auto-attach note references into pool metadata, and make synchronized results eventually visible to members.
- Delivery priority is business outcome first, sync control second, while still requiring explicit sync APIs and recoverable sync feedback.

## 2. Locked Decisions

- `Flutter` is the frontend only: UI composition, interaction flow, page state, API invocation, and user-facing recovery actions.
- `Rust` is the backend only: domain rules, persistence, pool-note association, synchronization flow, stable error semantics, and DTO production.
- `FRB` is a thin boundary layer and must not become a second business layer.
- Flutter must not remain a business write truth source.
- Phase 1 uses explicit sync triggering after key business actions instead of background-first automatic sync.
- Long-term compatibility layers are not allowed. If a short-term compatibility path is unavoidable, the code must include explicit Chinese comments stating that it is temporary compatibility code, what old path it is bridging, what new path replaces it, and that it must be removed later.

## 3. Alternatives Considered

### 3.1 Option A (Selected): Rust source of truth with use-case APIs

- Flutter invokes use-case-oriented Rust APIs such as create pool, join pool, create card note, update card note, and run sync.
- Pros:
  - best match for the desired frontend-backend split,
  - keeps domain rules concentrated in Rust,
  - makes spec enforcement and cross-platform consistency easier,
  - makes failure diagnosis clearer because the call chain is explicit.
- Cons:
  - requires broader Rust API and DTO design,
  - requires removing or bypassing existing Flutter-side write paths.

### 3.2 Option B: Rust resource APIs with Flutter-side orchestration

- Rust exposes finer-grained CRUD-like resources while Flutter assembles business workflows.
- Pros:
  - reusable API surface,
  - flexible for many pages.
- Cons:
  - business rules can drift back into Flutter,
  - less aligned with the chosen backend ownership model.

### 3.3 Option C: Incremental coexistence with existing Flutter write paths

- Keep current Flutter write logic for now and gradually migrate selected flows to Rust.
- Pros:
  - lowest short-term migration pressure.
- Cons:
  - creates dual sources of truth,
  - directly conflicts with the chosen architecture,
  - high long-term maintenance risk.

## 4. Architecture and Responsibility Boundaries

### 4.1 Top-level architecture

- `UI -> PageController -> ApiClient -> FRB -> Rust backend -> store + sync -> DTO/error -> Flutter state -> UI`

### 4.2 Flutter responsibilities

- Build and render UI components.
- Handle routing and page-level interaction flow.
- Hold view state for loading, success, empty, degraded, and error cases.
- Invoke backend APIs through thin Dart clients.
- Convert stable error codes into user-facing messages and recovery actions.

### 4.3 Rust responsibilities

- Enforce domain rules from the pool and card-note specs.
- Own all business writes and business invariants.
- Persist data and manage synchronization execution.
- Maintain pool metadata, including note reference attachment rules.
- Return stable DTOs and stable error codes.

### 4.4 FRB responsibilities

- Carry request and response data across the language boundary.
- Expose generated callable APIs to Flutter.
- Avoid domain branching, rule duplication, or long-lived translation logic beyond transport needs.

## 5. Frontend Naming Model

- Replace abstract names such as `Feature Facade` with direct frontend terms.
- Recommended Flutter naming model:
  - `ApiClient`: Dart-side wrapper for Rust APIs, such as `PoolApiClient`, `CardApiClient`, `SyncApiClient`.
  - `PageController`: page action orchestration, such as `PoolPageController`, `CardsPageController`.
  - `ViewState`: render-oriented page state, such as `PoolPageState`, `CardsPageState`.
  - `UI`: widgets and pages.
- This keeps the Flutter side understandable as a frontend stack rather than a partial backend.

## 6. Backend API Surface

### 6.1 Session/App APIs

- Initialize backend runtime context.
- Open local data directory or equivalent app backend session.
- Initialize network handle(s) needed for sync.
- Query backend readiness and current runtime status.

### 6.2 Pool APIs

- `createPool`
- `joinPool` or `requestJoinPool` depending on current product semantics
- `listPools`
- `getPoolDetail`
- Pool APIs must own membership rules, role semantics, and pool metadata changes.
- Joining a pool must automatically attach the user's existing note references inside the same backend use case.

### 6.3 Card APIs

- `createCardNote`
- `updateCardNote`
- `listCardNotes`
- `getCardNoteDetail`
- When card creation happens inside a pool context, Rust must attach the new `noteId` into pool metadata in the same backend flow.
- Updating or deleting an already attached note must not create duplicate note references.

### 6.4 Sync APIs

- `connectSyncTarget`
- `runSyncNow`
- `getSyncStatus`
- `disconnectSync`
- Phase 1 uses explicit sync invocation from Flutter after key successful business actions.

## 7. Data Flow and Closed Loops

### 7.1 Create pool

- Flutter triggers `createPool` through `PoolPageController` and `PoolApiClient`.
- Rust creates the pool, assigns the creator as the first admin, persists the result, and returns `PoolDto`.
- Flutter refreshes pool queries and may explicitly trigger sync if the environment is connected.

### 7.2 Join pool

- Flutter triggers `joinPool`.
- Rust completes join semantics and auto-attaches all existing note references required by the card-note spec.
- Flutter must not add a second client-side attachment step.
- Flutter then explicitly triggers sync and reloads pool and note views.

### 7.3 Create card note

- Flutter triggers `createCardNote`.
- Rust persists the note and, when pool context exists, adds the pool metadata note reference in the same backend transaction or equivalent atomic flow.
- Flutter explicitly triggers sync and reloads list/detail views.

### 7.4 Update card note

- Flutter triggers `updateCardNote`.
- Rust persists the updated content while preserving the no-duplicate-reference rule.
- Flutter explicitly triggers sync and reloads current views.

### 7.5 Business success versus sync failure

- Business write success and sync failure must be represented separately.
- Flutter must be able to show: data saved successfully, sync not completed yet, retry available.
- Sync failure must never falsely rewrite a successful business write as a business failure.

## 8. DTO and Error Contracts

### 8.1 DTO principles

- Rust must return stable, view-friendly DTOs instead of leaking internal storage or sync model details.
- DTOs should expose only fields needed by the current UI and acceptance scope.
- Over-broad future-proofing is forbidden under YAGNI.

### 8.2 Core DTOs

- `PoolDto`: pool id, name, dissolved state, current user role, member summary, basic sync summary.
- `PoolDetailDto`: pool basics, note reference summary, member list, pending join state if applicable.
- `CardNoteDto`: note id, title, content, timestamps, pool summary, delete state.
- `SyncStatusDto`: current sync state, last result, retryability, recommended recovery action.
- `SyncResultDto`: success or degraded result, error code when applicable, next-step hint.

### 8.3 Error contract

- Rust returns a unified `ApiError` shape.
- Flutter branches only on stable `error.code`.
- `error.message` is user-facing text.
- `error.details` is diagnostic only and must not drive product logic.

### 8.4 Error categories

- `VALIDATION_*`
- `PERMISSION_*`
- `NOT_FOUND_*`
- `CONFLICT_*`
- `SYNC_*`
- `TRANSPORT_*`
- `INTERNAL`

### 8.5 Recovery mapping principles

- Validation errors ask the user to fix input.
- Permission errors stop retry and explain denial.
- Conflict errors refresh or re-query current state.
- Sync errors offer retry sync or reconnect actions.
- Transport errors offer retry or backend reinitialization.
- Internal errors fall back to generic retry and diagnostics.

## 9. Migration Strategy

### 9.1 Migration goal

- Remove Flutter-side business write truth from the main path.
- Converge frontend code into `UI + PageController + ViewState + ApiClient`.
- Move overlapping business logic and persistence control into Rust.

### 9.2 Migration order

- Build the new Rust use-case APIs first.
- Rewire Flutter pages to the new `ApiClient` path.
- Stop page main flows from calling Flutter-side business write layers.
- Delete obsolete Flutter-side write/storage/application code after the new path is proven.

### 9.3 Legacy code handling

- `lib/features/pool/data/*`
- `lib/features/cards/data/*`
- `lib/features/shared/storage/*`
- `lib/features/*/application/*`
- Any code in these areas that acts as direct business write logic, persistence truth, or sync control must leave the main path and be removed in phases.
- If temporary compatibility code is unavoidable, it must carry explicit Chinese comments documenting its temporary nature and removal intent.

## 10. Testing Strategy

### 10.1 Rust domain and application tests

- Verify create pool, join pool, create card note, update card note, auto-attachment, idempotency, and stable error semantics.

### 10.2 Rust sync tests

- Verify explicit sync flow, sync state transitions, degraded or failed sync semantics, and separation between business success and sync failure.

### 10.3 Flutter frontend orchestration tests

- Verify page action flows such as `createCard -> runSyncNow -> reloadCards`.
- Do not duplicate Rust business rule assertions here.

### 10.4 Cross-language smoke tests

- Use real FRB for a small number of critical end-to-end bridge checks.
- Confirm request and response DTOs, plus error propagation, work through the real boundary.

## 11. Acceptance Focus for Phase 1

- Given no pool, when creating a pool, then the creator becomes admin.
- Given existing notes, when joining a pool, then pool metadata includes those existing `noteId` references.
- Given pool context, when creating a note, then pool metadata includes the new `noteId`.
- Given an attached note, when editing it, then no duplicate `noteId` is created in pool metadata.
- Given member changes and explicit sync, when another member refreshes after convergence, then the result is eventually consistent.
- Given business write success but sync failure, when the page renders the outcome, then the user sees saved-but-not-synced feedback and a recovery action.

## 12. Out of Scope for Phase 1

- Multi-pool concurrent sync control panels.
- Full background-first automatic sync strategy.
- Over-generalized public API surfaces for hypothetical future domains.
- Long-term coexistence of Flutter and Rust as dual business write authorities.
