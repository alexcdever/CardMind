# Flutter 单元测试覆盖率补齐设计

**背景**
- 2026-02-06 运行 `dart tool/quality.dart`：Flutter 单元覆盖率 59.2% (171/289)，未达 90% 门槛。

**目标**
- 在不修改生产逻辑的前提下，将 Flutter 单元测试覆盖率提升至 ≥90%。
- 保持测试目录结构与命名规范（`test/unit/**` + `it_should_`）。

**非目标**
- 不调整覆盖率统计规则或阈值。
- 不引入新的测试依赖（除非现有依赖不足）。
- 不覆盖直接依赖 Rust FFI 或平台插件的路径（如 `CardService/PoolProvider/SyncProvider/LoroFileService`）。

**范围**
- models：`sort_option.dart`、`sync_history_entry.dart`、`pairing_request.dart`
- utils：`device_utils.dart`、`responsive_utils.dart`、`snackbar_utils.dart`、`toast_utils.dart`
- constants：`storage_keys.dart`
- providers：`theme_provider.dart`、`device_manager_provider.dart`、`card_editor_state.dart`、`card_provider.dart`
- services：`mock_card_api.dart`、`device_discovery_service.dart`（不触发 FFI 分支）

**策略**
- 以“公开项数量 → 单元测试数量”规则为准，每个公开项对应至少一个 `it_should_` 测试。
- 复用已有 mock/fake（如 `MockCardApi`、`VerificationCodeService` 实例）。
- 对计时/异步逻辑使用现有 `WidgetTester` 与 `pump`/`pumpAndSettle`，避免引入 `fake_async`。
- 对 UI utils（`SnackBarUtils`）只验证渲染结果（文本/颜色/图标），不测试视觉细节。

**提交策略**
- 按大类拆分三次提交：
  1) models + utils + constants
  2) providers
  3) services

**验证**
- 每批提交后运行 `dart tool/quality.dart`，确保覆盖率与全量测试通过。
