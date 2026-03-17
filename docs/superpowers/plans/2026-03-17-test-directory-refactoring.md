# 测试目录重构实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按测试类型重构 Flutter 和 Rust 测试目录结构，统一命名规范

**Architecture:** 将现有按功能域划分的测试目录重构为按测试类型划分（unit/widget/integration/contract/e2e/performance），所有测试文件按新命名规范重命名

**Tech Stack:** Flutter, Dart, Rust, Cargo

**设计文档:** `docs/superpowers/specs/2026-03-17-test-directory-refactoring-design.md`

---

## Chunk 1: Flutter 测试目录重构 - 创建新目录结构

**Files:**
- Create: `test/unit/domain/.gitkeep`
- Create: `test/unit/application/.gitkeep`
- Create: `test/unit/data/.gitkeep`
- Create: `test/unit/presentation/.gitkeep`
- Create: `test/widget/components/.gitkeep`
- Create: `test/widget/pages/.gitkeep`
- Create: `test/integration/features/.gitkeep`
- Create: `test/integration/infrastructure/.gitkeep`
- Create: `test/contract/api/.gitkeep`
- Create: `test/contract/bridge/.gitkeep`
- Create: `test/e2e/flows/.gitkeep`

- [x] **Step 1: 创建 Flutter 新目录结构**

```bash
# 在仓库根目录执行
mkdir -p test/unit/{domain,application,data,presentation}
mkdir -p test/widget/{components,pages}
mkdir -p test/integration/{features,infrastructure}
mkdir -p test/contract/{api,bridge}
mkdir -p test/e2e/flows

# 验证目录创建
ls -la test/
```

Expected: 看到 unit/, widget/, integration/, contract/, e2e/ 目录

- [x] **Step 2: 提交目录创建**

```bash
git add test/
git commit -m "chore(test): create new test directory structure by type

Create test directories organized by test type:
- unit/: domain, application, data, presentation
- widget/: components, pages
- integration/: features, infrastructure
- contract/: api, bridge
- e2e/: flows

Refs: docs/superpowers/specs/2026-03-17-test-directory-refactoring-design.md"
```

---

## Chunk 2: Rust 测试目录重构 - 创建新目录结构

**Files:**
- Create: `rust/tests/unit/domain/.gitkeep`
- Create: `rust/tests/unit/store/.gitkeep`
- Create: `rust/tests/unit/utils/.gitkeep`
- Create: `rust/tests/integration/api/.gitkeep`
- Create: `rust/tests/integration/store/.gitkeep`
- Create: `rust/tests/integration/sync/.gitkeep`
- Create: `rust/tests/contract/api/.gitkeep`
- Create: `rust/tests/contract/store/.gitkeep`
- Create: `rust/tests/performance/.gitkeep`

- [x] **Step 1: 创建 Rust 新目录结构**

```bash
# 在仓库根目录执行
mkdir -p rust/tests/unit/{domain,store,utils}
mkdir -p rust/tests/integration/{api,store,sync}
mkdir -p rust/tests/contract/{api,store}
mkdir -p rust/tests/performance

# 验证目录创建
ls -la rust/tests/
```

Expected: 看到 unit/, integration/, contract/, performance/ 目录

- [x] **Step 2: 提交目录创建**

```bash
git add rust/tests/
git commit -m "chore(test): create new rust test directory structure by type

Create rust test directories organized by test type:
- unit/: domain, store, utils
- integration/: api, store, sync
- contract/: api, store
- performance/

Refs: docs/superpowers/specs/2026-03-17-test-directory-refactoring-design.md"
```

---

## Chunk 3: Flutter 单元测试迁移 - Domain 层

**Files to move:**
- `test/features/cards/domain/card_note_projection_test.dart` → `test/unit/domain/card_note_test.dart`
- `test/features/pool/domain/pool_entity_test.dart` → `test/unit/domain/pool_entity_test.dart`

- [x] **Step 1: 移动并重命名 Domain 层单元测试**

```bash
# 移动文件
mv test/features/cards/domain/card_note_projection_test.dart test/unit/domain/card_note_test.dart
mv test/features/pool/domain/pool_entity_test.dart test/unit/domain/pool_entity_test.dart

# 验证移动
ls -la test/unit/domain/
```

Expected: 看到 card_note_test.dart, pool_entity_test.dart

- [x] **Step 2: 更新导入路径**

编辑 `test/unit/domain/card_note_test.dart`:
- 更新相对导入路径（如有）

编辑 `test/unit/domain/pool_entity_test.dart`:
- 更新相对导入路径（如有）

- [x] **Step 3: 运行测试验证**

```bash
flutter test test/unit/domain/ --verbose
```

Expected: 所有测试通过

- [x] **Step 4: 提交**

```bash
git add test/
git commit -m "refactor(test): migrate domain layer unit tests to new structure

- Move card_note_projection_test.dart → unit/domain/card_note_test.dart
- Move pool_entity_test.dart → unit/domain/pool_entity_test.dart
- Update import paths"
```

---

## Chunk 4: Flutter 单元测试迁移 - Application 层

**Files to move:**
- `test/features/cards/application/cards_command_service_test.dart` → `test/unit/application/cards_command_service_test.dart`
- `test/features/pool/application/pool_command_service_test.dart` → `test/unit/application/pool_command_service_test.dart`

- [x] **Step 1: 移动并重命名 Application 层单元测试**

```bash
mv test/features/cards/application/cards_command_service_test.dart test/unit/application/
mv test/features/pool/application/pool_command_service_test.dart test/unit/application/

ls -la test/unit/application/
```

- [x] **Step 2: 更新导入路径**

编辑移动后的文件，更新相对导入路径

- [x] **Step 3: 运行测试验证**

```bash
flutter test test/unit/application/ --verbose
```

- [x] **Step 4: 提交**

```bash
git add test/
git commit -m "refactor(test): migrate application layer unit tests to new structure

- Move cards_command_service_test.dart → unit/application/
- Move pool_command_service_test.dart → unit/application/"
```

---

## Chunk 5: Flutter 单元测试迁移 - Data 层

**Files to move:**
- `test/features/cards/data/sqlite_cards_read_repository_test.dart` → `test/unit/data/sqlite_cards_repository_test.dart`
- `test/features/pool/data/sqlite_pool_read_repository_test.dart` → `test/unit/data/sqlite_pool_repository_test.dart`

- [x] **Step 1: 移动并重命名 Data 层单元测试**

```bash
mv test/features/cards/data/sqlite_cards_read_repository_test.dart test/unit/data/sqlite_cards_repository_test.dart
mv test/features/pool/data/sqlite_pool_read_repository_test.dart test/unit/data/sqlite_pool_repository_test.dart

ls -la test/unit/data/
```

- [x] **Step 2: 更新导入路径**

- [x] **Step 3: 运行测试验证**

```bash
flutter test test/unit/data/ --verbose
```

- [x] **Step 4: 提交**

```bash
git add test/
git commit -m "refactor(test): migrate data layer unit tests to new structure

- Rename and move sqlite_cards_read_repository_test.dart → unit/data/sqlite_cards_repository_test.dart
- Rename and move sqlite_pool_read_repository_test.dart → unit/data/sqlite_pool_repository_test.dart"
```

---

## Chunk 6: Flutter Widget 测试迁移 - Pages

**Files to move:**
- `test/features/cards/cards_page_test.dart` → `test/widget/pages/cards_page_test.dart`
- `test/features/pool/pool_page_test.dart` → `test/widget/pages/pool_page_test.dart`
- `test/features/settings/settings_page_test.dart` → `test/widget/pages/settings_page_test.dart`
- `test/app/app_homepage_navigation_test.dart` → `test/widget/pages/app_homepage_test.dart`
- `test/app/adaptive_homepage_scaffold_test.dart` → `test/widget/pages/adaptive_homepage_test.dart`

- [x] **Step 1: 移动并重命名 Widget 测试**

```bash
mv test/features/cards/cards_page_test.dart test/widget/pages/
mv test/features/pool/pool_page_test.dart test/widget/pages/
mv test/features/settings/settings_page_test.dart test/widget/pages/
mv test/app/app_homepage_navigation_test.dart test/widget/pages/app_homepage_test.dart
mv test/app/adaptive_homepage_scaffold_test.dart test/widget/pages/adaptive_homepage_test.dart

ls -la test/widget/pages/
```

- [x] **Step 2: 更新导入路径**

编辑所有移动后的文件，更新导入路径

- [x] **Step 3: 运行测试验证**

```bash
flutter test test/widget/pages/ --verbose
```

- [x] **Step 4: 提交**

```bash
git add test/
git commit -m "refactor(test): migrate widget tests to new structure

- Move page tests to widget/pages/
- Rename app_homepage_navigation_test.dart → app_homepage_test.dart
- Rename adaptive_homepage_scaffold_test.dart → adaptive_homepage_test.dart"
```

---

## Chunk 7: Flutter Widget 测试迁移 - Components

**Files to move:**
- `test/features/accessibility/semantic_ids_test.dart` → `test/widget/components/semantic_ids_test.dart`
- `test/features/accessibility/keyboard_navigation_test.dart` → `test/widget/components/keyboard_navigation_test.dart`
- `test/features/sync/sync_controller_test.dart` → `test/widget/components/sync_controller_test.dart`
- `test/features/sync/sync_state_semantics_test.dart` → `test/widget/components/sync_state_test.dart`

- [x] **Step 1: 移动并重命名组件测试**

```bash
mv test/features/accessibility/semantic_ids_test.dart test/widget/components/
mv test/features/accessibility/keyboard_navigation_test.dart test/widget/components/
mv test/features/sync/sync_controller_test.dart test/widget/components/
mv test/features/sync/sync_state_semantics_test.dart test/widget/components/sync_state_test.dart

ls -la test/widget/components/
```

- [x] **Step 2: 更新导入路径**

- [x] **Step 3: 运行测试验证**

```bash
flutter test test/widget/components/ --verbose
```

- [x] **Step 4: 提交**

```bash
git add test/
git commit -m "refactor(test): migrate component widget tests to new structure

- Move accessibility tests to widget/components/
- Move sync tests to widget/components/
- Rename sync_state_semantics_test.dart → sync_state_test.dart"
```

---

## Chunk 8: Flutter 集成测试迁移 - Features

**Files to move:**
- `test/features/pool/pool_sync_interaction_test.dart` → `test/integration/features/pool_sync_test.dart`
- `test/features/pool/join_error_mapper_test.dart` → `test/integration/features/pool_join_error_test.dart`
- `test/features/cards/cards_pool_filter_test.dart` → `test/integration/features/cards_pool_filter_test.dart`
- `test/features/cards/cards_sync_navigation_test.dart` → `test/integration/features/cards_sync_navigation_test.dart`
- `test/features/automation/automation_flow_test.dart` → `test/integration/features/automation_flow_test.dart`

- [x] **Step 1: 移动并重命名集成测试**

```bash
mv test/features/pool/pool_sync_interaction_test.dart test/integration/features/pool_sync_test.dart
mv test/features/pool/join_error_mapper_test.dart test/integration/features/pool_join_error_test.dart
mv test/features/cards/cards_pool_filter_test.dart test/integration/features/
mv test/features/cards/cards_sync_navigation_test.dart test/integration/features/
mv test/features/automation/automation_flow_test.dart test/integration/features/

ls -la test/integration/features/
```

- [x] **Step 2: 更新导入路径**

- [x] **Step 3: 运行测试验证**

```bash
flutter test test/integration/features/ --verbose
```

- [x] **Step 4: 提交**

```bash
git add test/
git commit -m "refactor(test): migrate feature integration tests to new structure

- Rename and move pool_sync_interaction_test.dart → integration/features/pool_sync_test.dart
- Rename and move join_error_mapper_test.dart → integration/features/pool_join_error_test.dart
- Move other feature tests to integration/features/"
```

---

## Chunk 9: Flutter 集成测试迁移 - Infrastructure

**Files to move:**
- `test/bridge/flutter_rust_flow_smoke_test.dart` → `test/integration/infrastructure/rust_bridge_flow_test.dart`
- `test/bridge/backend_api_smoke_test.dart` → `test/integration/infrastructure/backend_api_test.dart`
- `test/bridge/sync_bridge_api_smoke_test.dart` → `test/integration/infrastructure/sync_bridge_test.dart`

- [x] **Step 1: 移动并重命名基础设施测试**

```bash
mv test/bridge/flutter_rust_flow_smoke_test.dart test/integration/infrastructure/rust_bridge_flow_test.dart
mv test/bridge/backend_api_smoke_test.dart test/integration/infrastructure/backend_api_test.dart
mv test/bridge/sync_bridge_api_smoke_test.dart test/integration/infrastructure/sync_bridge_test.dart

ls -la test/integration/infrastructure/
```

- [x] **Step 2: 更新导入路径**

- [x] **Step 3: 运行测试验证**

```bash
flutter test test/integration/infrastructure/ --verbose
```

- [x] **Step 4: 提交**

```bash
git add test/
git commit -m "refactor(test): migrate infrastructure integration tests to new structure

- Rename and move bridge tests to integration/infrastructure/
- Rename flutter_rust_flow_smoke_test.dart → rust_bridge_flow_test.dart
- Rename backend_api_smoke_test.dart → backend_api_test.dart
- Rename sync_bridge_api_smoke_test.dart → sync_bridge_test.dart"
```

---

## Chunk 10: Flutter 契约测试迁移

**Files to move:**
- `test/features/cards/cards_api_client_test.dart` → `test/contract/api/cards_api_contract_test.dart`
- `test/features/pool/pool_api_client_test.dart` → `test/contract/api/pool_api_contract_test.dart`

- [x] **Step 1: 移动并重命名契约测试**

```bash
mv test/features/cards/cards_api_client_test.dart test/contract/api/cards_api_contract_test.dart
mv test/features/pool/pool_api_client_test.dart test/contract/api/pool_api_contract_test.dart

ls -la test/contract/api/
```

- [x] **Step 2: 更新导入路径**

- [x] **Step 3: 运行测试验证**

```bash
flutter test test/contract/api/ --verbose
```

- [x] **Step 4: 提交**

```bash
git add test/
git commit -m "refactor(test): migrate contract tests to new structure

- Rename and move cards_api_client_test.dart → contract/api/cards_api_contract_test.dart
- Rename and move pool_api_client_test.dart → contract/api/pool_api_contract_test.dart"
```

---

## Chunk 11: Flutter 其他测试迁移

**Files to move:**
- `test/features/read_model/query_path_test.dart` → `test/unit/presentation/query_path_test.dart`
- `test/features/shared/storage/loro_doc_store_test.dart` → `test/unit/data/loro_doc_store_test.dart`
- `test/features/shared/storage/loro_doc_path_test.dart` → `test/unit/data/loro_doc_path_test.dart`
- `test/features/shared/projection/loro_projection_worker_test.dart` → `test/unit/presentation/loro_projection_worker_test.dart`
- `test/features/cards/projection/cards_projection_handler_test.dart` → `test/unit/presentation/cards_projection_handler_test.dart`
- `test/features/cards/domain/card_note_projection_test.dart` → `test/unit/domain/card_note_test.dart` (如果还没移动)

- [x] **Step 1: 移动剩余测试文件**

```bash
mv test/features/read_model/query_path_test.dart test/unit/presentation/
mv test/features/shared/storage/loro_doc_store_test.dart test/unit/data/
mv test/features/shared/storage/loro_doc_path_test.dart test/unit/data/
mv test/features/shared/projection/loro_projection_worker_test.dart test/unit/presentation/
mv test/features/cards/projection/cards_projection_handler_test.dart test/unit/presentation/

ls -la test/unit/presentation/
```

- [x] **Step 2: 更新导入路径**

- [x] **Step 3: 运行测试验证**

```bash
flutter test test/unit/ --verbose
```

- [x] **Step 4: 提交**

```bash
git add test/
git commit -m "refactor(test): migrate remaining tests to new structure

- Move read_model, shared storage/projection tests to appropriate directories
- Move cards projection tests to unit/presentation/"
```

---

## Chunk 12: Flutter 根目录测试文件处理

**Files in test/ root:**
- `test/build_cli_test.dart` → `test/integration/infrastructure/build_cli_test.dart`
- `test/quality_cli_test.dart` → `test/integration/infrastructure/quality_cli_test.dart`
- `test/interaction_guard_test.dart` → `test/unit/presentation/interaction_guard_test.dart`
- `test/widget_test.dart` → `test/widget/widget_test.dart` (保留或删除)

- [x] **Step 1: 移动根目录测试文件**

```bash
mv test/build_cli_test.dart test/integration/infrastructure/
mv test/quality_cli_test.dart test/integration/infrastructure/
mv test/interaction_guard_test.dart test/unit/presentation/
mv test/widget_test.dart test/widget/

ls -la test/
```

Expected: 根目录不再有 *_test.dart 文件

- [x] **Step 2: 更新导入路径**

- [x] **Step 3: 运行测试验证**

```bash
flutter test --verbose
```

- [x] **Step 4: 提交**

```bash
git add test/
git commit -m "refactor(test): migrate root level test files to new structure

- Move build_cli_test.dart → integration/infrastructure/
- Move quality_cli_test.dart → integration/infrastructure/
- Move interaction_guard_test.dart → unit/presentation/
- Move widget_test.dart → widget/"
```

---

## Chunk 13: Rust 单元测试迁移 - Domain 层

**Files to move:**
- `rust/tests/card_model_test.rs` → `rust/tests/unit/domain/card_model_test.rs`

- [x] **Step 1: 移动 Domain 层单元测试**

```bash
mv rust/tests/card_model_test.rs rust/tests/unit/domain/

ls -la rust/tests/unit/domain/
```

- [x] **Step 2: 运行测试验证**

```bash
cd rust && cargo test --test card_model_test --verbose
```

- [x] **Step 3: 提交**

```bash
git add rust/tests/
git commit -m "refactor(test): migrate rust domain unit tests to new structure

- Move card_model_test.rs → unit/domain/"
```

---

## Chunk 14: Rust 单元测试迁移 - Store 层

**Files to move:**
- `rust/tests/card_store_test.rs` → `rust/tests/unit/store/card_store_test.rs`
- `rust/tests/card_store_persist_test.rs` → `rust/tests/unit/store/card_store_persist_test.rs`
- `rust/tests/pool_store_test.rs` → `rust/tests/unit/store/pool_store_test.rs`
- `rust/tests/pool_store_persist_test.rs` → `rust/tests/unit/store/pool_store_persist_test.rs`
- `rust/tests/loro_store_test.rs` → `rust/tests/unit/store/loro_store_test.rs`
- `rust/tests/loro_persist_test.rs` → `rust/tests/unit/store/loro_persist_test.rs`
- `rust/tests/sqlite_store_test.rs` → `rust/tests/unit/store/sqlite_store_test.rs`
- `rust/tests/sqlite_store_cards_test.rs` → `rust/tests/unit/store/sqlite_cards_test.rs`
- `rust/tests/sqlite_store_pool_test.rs` → `rust/tests/unit/store/sqlite_pool_test.rs`

- [x] **Step 1: 批量移动 Store 层单元测试**

```bash
mv rust/tests/card_store_test.rs rust/tests/unit/store/
mv rust/tests/card_store_persist_test.rs rust/tests/unit/store/
mv rust/tests/pool_store_test.rs rust/tests/unit/store/
mv rust/tests/pool_store_persist_test.rs rust/tests/unit/store/
mv rust/tests/loro_store_test.rs rust/tests/unit/store/
mv rust/tests/loro_persist_test.rs rust/tests/unit/store/
mv rust/tests/sqlite_store_test.rs rust/tests/unit/store/
mv rust/tests/sqlite_store_cards_test.rs rust/tests/unit/store/sqlite_cards_test.rs
mv rust/tests/sqlite_store_pool_test.rs rust/tests/unit/store/sqlite_pool_test.rs

ls -la rust/tests/unit/store/
```

- [x] **Step 2: 运行测试验证**

```bash
cd rust && cargo test --test card_store_test --verbose
cd rust && cargo test --test pool_store_test --verbose
```

- [x] **Step 3: 提交**

```bash
git add rust/tests/
git commit -m "refactor(test): migrate rust store unit tests to new structure

- Move all store-related tests to unit/store/
- Rename sqlite_store_*_test.rs → sqlite_*_test.rs"
```

---

## Chunk 15: Rust 单元测试迁移 - Utils 层

**Files to move:**
- `rust/tests/uuid_v7_test.rs` → `rust/tests/unit/utils/uuid_v7_test.rs`
- `rust/tests/path_resolver_test.rs` → `rust/tests/unit/utils/path_resolver_test.rs`
- `rust/tests/api_error_test.rs` → `rust/tests/unit/utils/api_error_test.rs`
- `rust/tests/smoke_test.rs` → `rust/tests/unit/utils/smoke_test.rs`

- [x] **Step 1: 移动 Utils 层单元测试**

```bash
mv rust/tests/uuid_v7_test.rs rust/tests/unit/utils/
mv rust/tests/path_resolver_test.rs rust/tests/unit/utils/
mv rust/tests/api_error_test.rs rust/tests/unit/utils/
mv rust/tests/smoke_test.rs rust/tests/unit/utils/

ls -la rust/tests/unit/utils/
```

- [x] **Step 2: 运行测试验证**

```bash
cd rust && cargo test --test uuid_v7_test --verbose
```

- [x] **Step 3: 提交**

```bash
git add rust/tests/
git commit -m "refactor(test): migrate rust utils unit tests to new structure

- Move uuid_v7, path_resolver, api_error, smoke tests to unit/utils/"
```

---

## Chunk 16: Rust 集成测试迁移 - API 层

**Files to move:**
- `rust/tests/pool_join_by_code_test.rs` → `rust/tests/integration/api/pool_join_test.rs`
- `rust/tests/pool_collaboration_test.rs` → `rust/tests/integration/api/pool_lifecycle_test.rs`
- `rust/tests/pool_idempotency_test.rs` → `rust/tests/integration/api/pool_idempotency_test.rs`
- `rust/tests/pool_note_attachment_test.rs` → `rust/tests/integration/api/pool_note_attachment_test.rs`
- `rust/tests/pool_detail_contract_test.rs` → `rust/tests/integration/api/pool_detail_test.rs`
- `rust/tests/current_user_pool_view_test.rs` → `rust/tests/integration/api/current_user_view_test.rs`
- `rust/tests/card_api_delete_restore_test.rs` → `rust/tests/integration/api/card_delete_restore_test.rs`
- `rust/tests/card_query_contract_test.rs` → `rust/tests/integration/api/card_query_test.rs`
- `rust/tests/api_handle_test.rs` → `rust/tests/integration/api/api_handle_test.rs`
- `rust/tests/app_config_api_test.rs` → `rust/tests/integration/api/app_config_test.rs`

- [x] **Step 1: 批量移动 API 集成测试**

```bash
mv rust/tests/pool_join_by_code_test.rs rust/tests/integration/api/pool_join_test.rs
mv rust/tests/pool_collaboration_test.rs rust/tests/integration/api/pool_lifecycle_test.rs
mv rust/tests/pool_idempotency_test.rs rust/tests/integration/api/
mv rust/tests/pool_note_attachment_test.rs rust/tests/integration/api/
mv rust/tests/pool_detail_contract_test.rs rust/tests/integration/api/pool_detail_test.rs
mv rust/tests/current_user_pool_view_test.rs rust/tests/integration/api/current_user_view_test.rs
mv rust/tests/card_api_delete_restore_test.rs rust/tests/integration/api/card_delete_restore_test.rs
mv rust/tests/card_query_contract_test.rs rust/tests/integration/api/card_query_test.rs
mv rust/tests/api_handle_test.rs rust/tests/integration/api/
mv rust/tests/app_config_api_test.rs rust/tests/integration/api/app_config_test.rs

ls -la rust/tests/integration/api/
```

- [x] **Step 2: 运行测试验证**

```bash
cd rust && cargo test --test pool_join_test --verbose
cd rust && cargo test --test pool_lifecycle_test --verbose
```

- [x] **Step 3: 提交**

```bash
git add rust/tests/
git commit -m "refactor(test): migrate rust api integration tests to new structure

- Rename and move pool tests to integration/api/
- Rename and move card tests to integration/api/
- Rename pool_detail_contract_test.rs → pool_detail_test.rs
- Rename card_query_contract_test.rs → card_query_test.rs"
```

---

## Chunk 17: Rust 集成测试迁移 - Sync 层

**Files to move:**
- `rust/tests/pool_sync_test.rs` → `rust/tests/integration/sync/pool_sync_test.rs`
- `rust/tests/pool_multi_member_sync_test.rs` → `rust/tests/integration/sync/multi_member_sync_test.rs`
- `rust/tests/sync_api_flow_test.rs` → `rust/tests/integration/sync/api_flow_test.rs`
- `rust/tests/pool_network_flow_test.rs` → `rust/tests/integration/sync/network_flow_test.rs`
- `rust/tests/pool_net_endpoint_test.rs` → `rust/tests/integration/sync/net_endpoint_test.rs`
- `rust/tests/pool_net_session_test.rs` → `rust/tests/integration/sync/net_session_test.rs`
- `rust/tests/pool_net_codec_test.rs` → `rust/tests/integration/sync/net_codec_test.rs`

- [x] **Step 1: 批量移动 Sync 集成测试**

```bash
mv rust/tests/pool_sync_test.rs rust/tests/integration/sync/
mv rust/tests/pool_multi_member_sync_test.rs rust/tests/integration/sync/multi_member_sync_test.rs
mv rust/tests/sync_api_flow_test.rs rust/tests/integration/sync/api_flow_test.rs
mv rust/tests/pool_network_flow_test.rs rust/tests/integration/sync/network_flow_test.rs
mv rust/tests/pool_net_endpoint_test.rs rust/tests/integration/sync/net_endpoint_test.rs
mv rust/tests/pool_net_session_test.rs rust/tests/integration/sync/net_session_test.rs
mv rust/tests/pool_net_codec_test.rs rust/tests/integration/sync/net_codec_test.rs

ls -la rust/tests/integration/sync/
```

- [x] **Step 2: 运行测试验证**

```bash
cd rust && cargo test --test pool_sync_test --verbose
```

- [x] **Step 3: 提交**

```bash
git add rust/tests/
git commit -m "refactor(test): migrate rust sync integration tests to new structure

- Move pool_sync_test.rs → integration/sync/
- Rename pool_multi_member_sync_test.rs → multi_member_sync_test.rs
- Rename sync_api_flow_test.rs → api_flow_test.rs
- Rename pool_network_flow_test.rs → network_flow_test.rs
- Rename pool_net_*_test.rs → net_*_test.rs"
```

---

## Chunk 18: Rust 集成测试迁移 - Store 层

**Files to move:**
- `rust/tests/projection_flow_test.rs` → `rust/tests/integration/store/projection_flow_test.rs`
- `rust/tests/store_architecture_contract_test.rs` → `rust/tests/integration/store/architecture_contract_test.rs`

- [x] **Step 1: 移动 Store 集成测试**

```bash
mv rust/tests/projection_flow_test.rs rust/tests/integration/store/
mv rust/tests/store_architecture_contract_test.rs rust/tests/integration/store/architecture_contract_test.rs

ls -la rust/tests/integration/store/
```

- [x] **Step 2: 运行测试验证**

```bash
cd rust && cargo test --test projection_flow_test --verbose
```

- [x] **Step 3: 提交**

```bash
git add rust/tests/
git commit -m "refactor(test): migrate rust store integration tests to new structure

- Move projection_flow_test.rs → integration/store/
- Rename store_architecture_contract_test.rs → architecture_contract_test.rs"
```

---

## Chunk 19: Rust 契约测试迁移

**Files to move:**
- `rust/tests/backend_api_contract_test.rs` → `rust/tests/contract/api/backend_api_contract.rs`
- `rust/tests/sync_api_contract_test.rs` → `rust/tests/contract/api/sync_api_contract.rs`
- `rust/tests/backend_config_api_test.rs` → `rust/tests/contract/api/backend_config_contract.rs`

- [x] **Step 1: 移动并重命名契约测试**

```bash
mv rust/tests/backend_api_contract_test.rs rust/tests/contract/api/backend_api_contract.rs
mv rust/tests/sync_api_contract_test.rs rust/tests/contract/api/sync_api_contract.rs
mv rust/tests/backend_config_api_test.rs rust/tests/contract/api/backend_config_contract.rs

ls -la rust/tests/contract/api/
```

Note: 契约测试使用 `.rs` 后缀（不是 `_test.rs`），因为它们通常包含多个测试函数

- [x] **Step 2: 运行测试验证**

```bash
cd rust && cargo test backend_api_contract --verbose
```

- [x] **Step 3: 提交**

```bash
git add rust/tests/
git commit -m "refactor(test): migrate rust contract tests to new structure

- Move backend_api_contract_test.rs → contract/api/backend_api_contract.rs
- Move sync_api_contract_test.rs → contract/api/sync_api_contract.rs
- Rename backend_config_api_test.rs → backend_config_contract.rs

Note: Contract tests use .rs suffix (not _test.rs)"
```

---

## Chunk 20: 清理旧目录和验证

**Tasks:**
- 删除空的旧目录
- 运行全量测试验证
- 更新文档

- [x] **Step 1: 删除 Flutter 旧目录**

```bash
# 检查哪些旧目录为空或可以删除
ls -la test/features/
ls -la test/app/
ls -la test/bridge/

# 删除空的旧目录（谨慎操作）
rm -rf test/features/  # 确认所有文件已移动
rm -rf test/app/       # 确认所有文件已移动
rm -rf test/bridge/    # 确认所有文件已移动
```

- [x] **Step 2: 运行 Flutter 全量测试**

```bash
flutter test --verbose
```

Expected: 所有测试通过

- [x] **Step 3: 删除 Rust 旧测试文件（根目录）**

```bash
# 检查 rust/tests/ 根目录是否还有未移动的文件
ls -la rust/tests/*.rs 2>/dev/null || echo "No files in root"

# 删除已移动的旧文件（如果还有）
# rm rust/tests/xxx_test.rs
```

- [x] **Step 4: 运行 Rust 全量测试**

```bash
cd rust && cargo test --verbose
```

Expected: 所有测试通过

- [x] **Step 5: 提交清理**

```bash
git add test/ rust/tests/
git commit -m "chore(test): remove old test directories after migration

- Delete test/features/, test/app/, test/bridge/
- Clean up rust/tests/ root directory
- All tests migrated to new structure"
```

---

## Chunk 21: 删除 .gitkeep 文件并更新文档

- [x] **Step 1: 删除所有 .gitkeep 文件**

```bash
find test/ rust/tests/ -name ".gitkeep" -delete
```

- [x] **Step 2: 更新 AGENTS.md 或相关文档**

添加测试目录结构说明到文档

- [x] **Step 3: 最终提交**

```bash
git add test/ rust/tests/ docs/
git commit -m "docs(test): finalize test directory refactoring

- Remove .gitkeep placeholder files
- Update documentation with new test structure
- Complete test directory migration

Refs: docs/superpowers/specs/2026-03-17-test-directory-refactoring-design.md"
```

---

## 验收检查清单

重构完成后验证：

- [x] Flutter 所有测试通过: `flutter test`
- [x] Rust 所有测试通过: `cargo test`
- [x] 可以按类型运行测试: `flutter test test/unit/`
- [x] 旧目录已完全删除
- [x] 所有文件命名符合规范
- [x] 文档已更新

---

## 风险评估与回滚

**如果重构过程中出现问题：**

1. **测试失败**: 检查导入路径是否正确更新
2. **文件遗漏**: 对比原始文件列表和新文件列表
3. **紧急回滚**: 
   ```bash
   git reset --hard HEAD~N  # N 为重构提交数
   ```

---

**计划完成**: 2026-03-17  
**计划文档**: `docs/superpowers/plans/2026-03-17-test-directory-refactoring.md`
