# 2026-03-15 Remove CardStore Handle Design

## 1. Background And Problem

- Current FRB product-path APIs expose `initCardStore(basePath)` and return a `storeId` handle to Flutter.
- Rust then requires that handle on later card/pool query and write calls.
- This leaks Rust-internal resource lifecycle details across the language boundary.
- `CardStore` and `storeId` are not required by `docs/specs/architecture.md`, `docs/specs/card-note.md`, or `docs/specs/pool.md`.
- The current shape makes Flutter carry implementation knowledge that should stay inside Rust.

## 2. Design Goal

- Remove `CardStore` and `storeId` from the FRB product path.
- Replace `initCardStore(...)` with an app-level configuration entrypoint named `initAppConfig(appDataDir)`.
- Keep Flutter on a stable resource-API model: initialize config once, then call handle-free card/pool/sync APIs.
- Preserve the existing architecture constraints:
  - Flutter writes only through FRB -> Rust.
  - Rust writes business truth into `LoroDoc`.
  - Rust queries product read results from `SQLite`.

## 3. Locked Decisions

- Product-path FRB APIs MUST NOT expose `storeId`.
- Rust main implementation MUST NOT keep `CardStore` as the externally visible runtime unit.
- The new app-level configuration API name is `initAppConfig`.
- The new configuration input is `appDataDir`.
- `initAppConfig` repeat-call semantics are:
  - same `appDataDir` -> success (idempotent)
  - different `appDataDir` -> stable error
- Flutter pages and controllers MUST NOT know `CardStore`, `storeId`, `LoroDoc`, or `SQLite`.

## 4. Target Architecture

### 4.1 Product Boundary

- Startup path:
  - `Flutter -> FRB -> Rust initAppConfig(appDataDir)`
- Resource path after configuration:
  - cards: `createCardNote`, `updateCardNote`, `deleteCardNote`, `restoreCardNote`, `listCardNotes`, `getCardNoteDetail`
  - pools: `createPool`, `joinByCode`, `listPools`, `getPoolDetail`
  - sync: `syncStatus`, `syncConnect`, `syncDisconnect`, `syncPush`, `syncPull`
- These APIs no longer accept `storeId`.

### 4.2 Rust Internal Runtime

- Rust owns a single app-level configured runtime for the active `appDataDir`.
- That runtime internally coordinates:
  - `LoroDoc` write-side access
  - `SQLite` read-model access
  - projection/update flow
  - pool metadata operations
  - sync resources and connection state
- Internal naming is an implementation choice, but it MUST express an app-level runtime/configuration concept rather than a card-scoped store concept.

### 4.3 Read/Write Boundary

- Write path remains:
  - `Flutter -> FRB -> Rust -> LoroDoc -> Projection -> SQLite`
- Query path remains:
  - `Flutter -> FRB -> Rust Query API -> SQLite -> DTO -> Flutter`
- Removing `CardStore` changes internal composition only; it MUST NOT weaken the architecture boundary.

## 5. API Contract Changes

### 5.1 New Configuration API

- Add `initAppConfig(appDataDir)` as the explicit app-start configuration step.
- This API configures the runtime and prepares the internal data environment for later resource APIs.
- If called before product actions, resource APIs become available.

### 5.2 Resource APIs

- Remove `storeId` parameters from all product-path FRB card and pool query/write APIs.
- Keep resource semantics stable from Flutter's perspective.
- Sync APIs should follow the same no-handle principle wherever they are part of the product path.

### 5.3 Error Semantics

- Before configuration, resource APIs MUST return a stable "app config not initialized" style error.
- Reconfiguring with a different `appDataDir` MUST return a stable conflict-style error.
- Repeating configuration with the same `appDataDir` MUST succeed.
- Underlying IO/SQLite/projection/sync failures MUST continue to map to stable DTO/error-code contracts rather than raw exception text.

## 6. Domain Behavior Preservation

### 6.1 Card Notes

- Card note create/update/delete/restore semantics remain unchanged.
- Default list visibility, pool note reference behavior, and delete/restore behavior continue to follow `docs/specs/card-note.md`.

### 6.2 Pools

- Pool creation still makes the creator admin.
- `joinByCode` remains a Rust-owned backend action.
- Existing note attachment semantics continue to follow `docs/specs/pool.md` and `docs/specs/card-note.md`.

### 6.3 Sync / Projection

- Removing the handle layer does not change the requirement to distinguish write success, projection lag/failure, and sync lag/failure.
- The runtime must preserve shared state required for sync and projection without leaking that state to Flutter.

## 7. Testing Strategy

### 7.1 FRB Contract Tests

- Verify `initAppConfig(appDataDir)` exists and behaves as specified.
- Verify product-path FRB APIs no longer expose `storeId`.

### 7.2 Rust Integration Tests

- Rebuild the backend integration tests around `initAppConfig`.
- Cover cards, pools, queries, and sync through the new handle-free APIs.
- Add explicit tests for:
  - config required before product actions
  - same-dir re-init succeeds
  - different-dir re-init fails with stable error

### 7.3 Flutter Architecture Guards

- Prevent pages/controllers from depending on `storeId` or card-scoped runtime handles.
- Keep guards that ban production composition from instantiating legacy/local clients.

## 8. Migration Strategy

1. Introduce `initAppConfig(appDataDir)` and stable configuration error semantics.
2. Convert Rust FRB card/pool APIs to handle-free signatures.
3. Update generated FRB bindings.
4. Update Dart clients and startup composition to use `initAppConfig`.
5. Delete `CardStore` and the Rust handle map/sequence logic.
6. Rewrite tests and guards to prevent regression.
7. Resume the broader FRB mainpath repair work on top of the corrected boundary.

## 9. Completion Criteria

- No product-path FRB API exposes `storeId`.
- `CardStore` no longer exists in Rust main implementation.
- Flutter startup uses `initAppConfig(appDataDir)`.
- Flutter page/controller composition only sees handle-free resource APIs.
- Architecture and integration tests prevent the handle model from returning.
