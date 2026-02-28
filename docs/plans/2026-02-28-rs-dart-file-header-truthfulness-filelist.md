input: 待清查文件列表与模板化短语扫描结果。
output: 分目录文件清单、抽样复核记录与最终交付列表。
pos: 清查报告文档，记录证据、例外与收口状态。
# Rs/Dart 文件头清查清单与基线证据（2026-02-28）

## 范围与口径
- 扫描范围：`rust/src`、`rust/tests`、`lib`、`test`、`tool`
- 文件类型：`.rs`、`.dart`
- 文件头判定：包含行 `// input:`
- 扫描命令：`rg -n --files-with-matches "^// input:" rust/src rust/tests lib test tool --glob "*.rs" --glob "*.dart" --glob "!lib/**/*.g.dart" --glob "!lib/**/*.freezed.dart"`

## 抽样复核记录（目录级）
- 复核方式：每个目录随机抽样并复读文件头三行（`input/output/pos`）与正文职责是否一致。
- `rust/src`：抽样 3/22（`api.rs`、`net/session.rs`、`store/sqlite_store.rs`），结果：通过。
- `rust/tests`：抽样 3/22（`smoke_test.rs`、`pool_sync_test.rs`、`path_resolver_test.rs`），结果：通过。
- `lib`：抽样 3/23（`main.dart`、`features/pool/pool_controller.dart`、`features/sync/sync_service.dart`），结果：通过。
- `test`：抽样 3/19（`widget_test.dart`、`features/pool/pool_page_test.dart`、`features/cards/cards_page_test.dart`），结果：通过。
- `tool`：抽样 2/3（`fractal_doc_check.dart`、`fractal_doc_checker.dart`），结果：通过。
- 抽样结论：14 个样本均通过，未发现模板化回流或职责失真描述。

## rust/src（22）
- `rust/src/api.rs`
- `rust/src/lib.rs`
- `rust/src/models/api_error.rs`
- `rust/src/models/card.rs`
- `rust/src/models/error.rs`
- `rust/src/models/mod.rs`
- `rust/src/models/pool.rs`
- `rust/src/net/codec.rs`
- `rust/src/net/endpoint.rs`
- `rust/src/net/messages.rs`
- `rust/src/net/mod.rs`
- `rust/src/net/pool_network.rs`
- `rust/src/net/session.rs`
- `rust/src/net/sync.rs`
- `rust/src/store/card_store.rs`
- `rust/src/store/loro_store.rs`
- `rust/src/store/mod.rs`
- `rust/src/store/path_resolver.rs`
- `rust/src/store/pool_store.rs`
- `rust/src/store/sqlite_store.rs`
- `rust/src/utils/mod.rs`
- `rust/src/utils/uuid_v7.rs`

## rust/tests（22）
- `rust/tests/api_error_test.rs`
- `rust/tests/api_handle_test.rs`
- `rust/tests/card_model_test.rs`
- `rust/tests/card_store_persist_test.rs`
- `rust/tests/card_store_test.rs`
- `rust/tests/loro_persist_test.rs`
- `rust/tests/loro_store_test.rs`
- `rust/tests/path_resolver_test.rs`
- `rust/tests/pool_net_codec_test.rs`
- `rust/tests/pool_net_endpoint_test.rs`
- `rust/tests/pool_net_session_test.rs`
- `rust/tests/pool_network_flow_test.rs`
- `rust/tests/pool_store_persist_test.rs`
- `rust/tests/pool_store_test.rs`
- `rust/tests/pool_sync_test.rs`
- `rust/tests/smoke_test.rs`
- `rust/tests/sqlite_store_cards_test.rs`
- `rust/tests/sqlite_store_pool_test.rs`
- `rust/tests/sqlite_store_test.rs`
- `rust/tests/sync_api_contract_test.rs`
- `rust/tests/sync_api_flow_test.rs`
- `rust/tests/uuid_v7_test.rs`

## lib（23）
- `lib/app/app.dart`
- `lib/app/layout/adaptive_shell.dart`
- `lib/app/navigation/app_section.dart`
- `lib/features/cards/card_summary.dart`
- `lib/features/cards/cards_controller.dart`
- `lib/features/cards/cards_desktop_interactions.dart`
- `lib/features/cards/cards_page.dart`
- `lib/features/editor/editor_controller.dart`
- `lib/features/editor/editor_page.dart`
- `lib/features/onboarding/onboarding_controller.dart`
- `lib/features/onboarding/onboarding_page.dart`
- `lib/features/onboarding/onboarding_state.dart`
- `lib/features/pool/join_error_mapper.dart`
- `lib/features/pool/pool_controller.dart`
- `lib/features/pool/pool_page.dart`
- `lib/features/pool/pool_state.dart`
- `lib/features/settings/settings_controller.dart`
- `lib/features/settings/settings_page.dart`
- `lib/features/sync/sync_banner.dart`
- `lib/features/sync/sync_controller.dart`
- `lib/features/sync/sync_service.dart`
- `lib/features/sync/sync_status.dart`
- `lib/main.dart`

## test（19）
- `test/app/adaptive_shell_test.dart`
- `test/bridge/sync_bridge_api_smoke_test.dart`
- `test/build_cli_test.dart`
- `test/features/cards/cards_desktop_interactions_test.dart`
- `test/features/cards/cards_page_test.dart`
- `test/features/cards/cards_sync_navigation_test.dart`
- `test/features/editor/editor_page_test.dart`
- `test/features/editor/editor_shortcuts_test.dart`
- `test/features/onboarding/onboarding_page_test.dart`
- `test/features/pool/join_error_mapper_test.dart`
- `test/features/pool/pool_page_test.dart`
- `test/features/pool/pool_sync_interaction_test.dart`
- `test/features/settings/settings_page_test.dart`
- `test/features/sync/sync_banner_test.dart`
- `test/features/sync/sync_controller_test.dart`
- `test/fractal_doc_checker_test.dart`
- `test/interaction_guard_test.dart`
- `test/ui_interaction_governance_docs_test.dart`
- `test/widget_test.dart`

## tool（3）
- `tool/fractal_doc_bootstrap.dart`
- `tool/fractal_doc_check.dart`
- `tool/fractal_doc_checker.dart`

## 完成证据（模板短语清零）

### 终态扫描命令
- `rg -n "用户操作、外部参数或依赖返回|保持行为不变|Rust 测试模块，验证关键行为、边界条件与错误路径" rust lib test tool --glob "*.rs" --glob "*.dart"`

### 终态扫描结果
- 输出为空（0 命中）。

## 最终清单

### 已修复
- 已修复范围：本文件列出的全部带文件头源码（`rust/src` 22、`rust/tests` 22、`lib` 23、`test` 19、`tool` 3；合计 89）。
- 修复结果：`input/output/pos` 均改为可验证、可区分的真实职责描述。

### 例外（自动生成）
- `rust/src/frb_generated.rs`

### 二次确认
- 无。

排除项：`rust/src/frb_generated.rs`、`lib/**.g.dart`、`lib/**.freezed.dart`、`build/**`、`rust/target/**`
