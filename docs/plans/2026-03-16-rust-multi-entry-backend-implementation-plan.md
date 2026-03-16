# Rust Multi-Entry Backend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Turn the Rust side into a single backend core that serves FRB by default and can optionally expose HTTP, MCP, and debug CLI entrypoints with consistent semantics.

**Architecture:** First update formal specs so the multi-entry runtime and config model are normative. Then refactor Rust into application/runtime-centered modules, add persistent entry enablement config plus runtime entry management, and finally adapt FRB, HTTP, MCP, and CLI onto the same use-case layer with shared DTO/error/state semantics.

**Tech Stack:** Rust, flutter_rust_bridge, serde, tokio, loro, rusqlite, Flutter, markdown specs in `docs/specs/`

---

### Task 1: Update formal architecture spec before code changes

**Files:**
- Modify: `docs/specs/architecture.md`
- Test/Check: `docs/specs/DIR.md`
- Test/Check: `docs/DIR.md`

**Step 1: Write the failing spec delta as explicit TODO bullets in the spec draft**

```md
### 4.x Backend multi-entry responsibilities

1. Rust MAY serve multiple entry adapters, including FRB, CLI, HTTP, and MCP.
2. FRB MUST remain the default Flutter-facing entry path.
3. Optional entries MUST be disabled by default and controlled by Rust-owned persistent config.
4. Enabled runtime entries MUST remain available while the app session is running.
```

**Step 2: Review current spec wording before editing**

Run: `python - <<'PY'
from pathlib import Path
print(Path('docs/specs/architecture.md').read_text())
PY`

Expected: existing project-level architecture spec does not yet fully describe multi-entry runtime behavior.

**Step 3: Update `docs/specs/architecture.md` minimally but normatively**

```md
### 4.2 Rust 后端职责

4. Rust MAY 通过多个入口适配层对外暴露能力，例如 FRB、CLI、HTTP、MCP。
5. 多入口仅是访问后端能力的协议边界，不改变 Rust 作为唯一后端内核的职责。

### 6.x 多入口运行时约束

1. FRB MUST 作为 Flutter 默认入口。
2. 其他入口 MUST 默认关闭，并由 Rust 持久化配置控制。
3. 被启用的入口 MUST 在应用运行期间保持可访问或可调用。
4. 多入口 MUST 共享同一业务语义、错误语义与状态语义。
```

**Step 4: Verify the spec edit reads cleanly**

Run: `python - <<'PY'
from pathlib import Path
text = Path('docs/specs/architecture.md').read_text()
assert 'FRB MUST 作为 Flutter 默认入口' in text
assert '其他入口 MUST 默认关闭' in text
print('ok')
PY`

Expected: `ok`

**Step 5: Commit**

```bash
git add docs/specs/architecture.md
git commit -m "docs(spec): extend architecture for rust multi-entry backend"
```

### Task 2: Update spec indexes if spec scope or files changed

**Files:**
- Modify: `docs/specs/DIR.md`
- Modify: `docs/DIR.md` (only if directory semantics changed)

**Step 1: Write the failing index expectation**

```py
from pathlib import Path
text = Path('docs/specs/DIR.md').read_text()
assert 'architecture.md - 功能规格 - 项目级架构约束' in text
```

**Step 2: Run the check and inspect whether index wording needs refresh**

Run: `python - <<'PY'
from pathlib import Path
print(Path('docs/specs/DIR.md').read_text())
print('---')
print(Path('docs/DIR.md').read_text())
PY`

Expected: if wording no longer reflects multi-entry architecture scope, update it.

**Step 3: Apply minimal index edits only if needed**

```md
architecture.md - 功能规格 - 项目级架构约束（前后端分层、读写分离、真源与查询链路、多入口后端约束）
```

**Step 4: Re-run the index check**

Run: `python - <<'PY'
from pathlib import Path
assert '多入口后端约束' in Path('docs/specs/DIR.md').read_text()
print('ok')
PY`

Expected: `ok` if wording changed; otherwise document that no index update was needed.

**Step 5: Commit**

```bash
git add docs/specs/DIR.md docs/DIR.md
git commit -m "docs(spec): refresh spec indexes for multi-entry backend"
```

### Task 3: Add backend config contract tests for entry enablement

**Files:**
- Create: `rust/tests/backend_config_api_test.rs`
- Modify: `rust/src/api.rs`
- Modify: `rust/src/models/api_error.rs`

**Step 1: Write the failing test**

```rust
#[test]
fn backend_config_defaults_disable_optional_entries() {
    let dir = tempfile::tempdir().unwrap();
    super::set_app_config_dir_for_test(dir.path());

    let config = crate::api::get_backend_config().unwrap();

    assert!(!config.http_enabled);
    assert!(!config.mcp_enabled);
    assert!(!config.cli_enabled);
}

#[test]
fn backend_config_update_persists_entry_flags() {
    let dir = tempfile::tempdir().unwrap();
    super::set_app_config_dir_for_test(dir.path());

    crate::api::update_backend_config(true, false, true).unwrap();
    let reloaded = crate::api::get_backend_config().unwrap();

    assert!(reloaded.http_enabled);
    assert!(!reloaded.mcp_enabled);
    assert!(reloaded.cli_enabled);
}
```

**Step 2: Run the test to verify it fails**

Run: `cargo test backend_config_api_test --manifest-path rust/Cargo.toml`

Expected: FAIL because config DTO/functions do not exist yet.

**Step 3: Write the minimal implementation**

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackendConfigDto {
    pub http_enabled: bool,
    pub mcp_enabled: bool,
    pub cli_enabled: bool,
}

pub fn get_backend_config() -> Result<BackendConfigDto, ApiError> {
    backend_config_store().load().map_err(map_err)
}

pub fn update_backend_config(
    http_enabled: bool,
    mcp_enabled: bool,
    cli_enabled: bool,
) -> Result<BackendConfigDto, ApiError> {
    backend_config_store()
        .save(BackendConfigDto { http_enabled, mcp_enabled, cli_enabled })
        .map_err(map_err)
}
```

**Step 4: Run the tests to verify they pass**

Run: `cargo test backend_config_api_test --manifest-path rust/Cargo.toml`

Expected: PASS

**Step 5: Commit**

```bash
git add rust/tests/backend_config_api_test.rs rust/src/api.rs rust/src/models/api_error.rs
git commit -m "feat(rust): add backend entry config contract"
```

### Task 4: Extract a dedicated backend config store under infrastructure

**Files:**
- Create: `rust/src/runtime/config.rs`
- Modify: `rust/src/lib.rs`
- Modify: `rust/src/DIR.md`
- Test: `rust/tests/backend_config_api_test.rs`

**Step 1: Write the failing test for file-backed config storage**

```rust
#[test]
fn backend_config_store_creates_default_file_when_missing() {
    let dir = tempfile::tempdir().unwrap();
    let store = crate::runtime::config::BackendConfigStore::new(dir.path());

    let config = store.load().unwrap();

    assert_eq!(config.http_enabled, false);
    assert!(dir.path().join("backend_config.json").exists());
}
```

**Step 2: Run the test to verify it fails**

Run: `cargo test backend_config_store_creates_default_file_when_missing --manifest-path rust/Cargo.toml`

Expected: FAIL because runtime config module does not exist.

**Step 3: Write minimal implementation in a dedicated module**

```rust
pub struct BackendConfigStore {
    path: PathBuf,
}

impl BackendConfigStore {
    pub fn new(base_dir: &Path) -> Self { /* ... */ }

    pub fn load(&self) -> Result<BackendConfigDto, CardMindError> { /* ... */ }

    pub fn save(&self, config: &BackendConfigDto) -> Result<(), CardMindError> { /* ... */ }
}
```

**Step 4: Run the focused tests**

Run: `cargo test backend_config --manifest-path rust/Cargo.toml`

Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/runtime/config.rs rust/src/lib.rs rust/src/DIR.md rust/tests/backend_config_api_test.rs
git commit -m "feat(rust): add backend config store"
```

### Task 5: Introduce a runtime entry manager contract

**Files:**
- Create: `rust/src/runtime/entry_manager.rs`
- Create: `rust/tests/runtime_entry_manager_test.rs`
- Modify: `rust/src/lib.rs`
- Modify: `rust/src/DIR.md`

**Step 1: Write the failing tests**

```rust
#[test]
fn entry_manager_reports_default_disabled_entries() {
    let manager = crate::runtime::entry_manager::RuntimeEntryManager::new_for_test();
    let status = manager.status();

    assert!(!status.http_active);
    assert!(!status.mcp_active);
    assert!(!status.cli_active);
}

#[test]
fn entry_manager_applies_config_to_runtime_state() {
    let manager = crate::runtime::entry_manager::RuntimeEntryManager::new_for_test();
    manager.apply_config(true, false, true).unwrap();

    let status = manager.status();
    assert!(status.http_active);
    assert!(!status.mcp_active);
    assert!(status.cli_active);
}
```

**Step 2: Run the tests to verify they fail**

Run: `cargo test runtime_entry_manager_test --manifest-path rust/Cargo.toml`

Expected: FAIL because runtime manager/status DTO does not exist.

**Step 3: Write the minimal runtime manager**

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuntimeEntryStatusDto {
    pub http_active: bool,
    pub mcp_active: bool,
    pub cli_active: bool,
}

pub struct RuntimeEntryManager {
    state: Mutex<RuntimeEntryStatusDto>,
}

impl RuntimeEntryManager {
    pub fn apply_config(&self, http: bool, mcp: bool, cli: bool) -> Result<(), CardMindError> {
        *self.state.lock().unwrap() = RuntimeEntryStatusDto { http_active: http, mcp_active: mcp, cli_active: cli };
        Ok(())
    }
}
```

**Step 4: Re-run the focused tests**

Run: `cargo test runtime_entry_manager_test --manifest-path rust/Cargo.toml`

Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/runtime/entry_manager.rs rust/src/lib.rs rust/src/DIR.md rust/tests/runtime_entry_manager_test.rs
git commit -m "feat(rust): add runtime entry manager contract"
```

### Task 6: Refactor API surface toward application/runtime services without breaking FRB behavior

**Files:**
- Create: `rust/src/application/mod.rs`
- Create: `rust/src/application/backend_service.rs`
- Modify: `rust/src/api.rs`
- Modify: `rust/src/lib.rs`
- Modify: `rust/src/DIR.md`
- Test: `rust/tests/app_config_api_test.rs`
- Test: `rust/tests/backend_api_contract_test.rs`

**Step 1: Write the failing service-level test**

```rust
#[test]
fn backend_service_reads_config_and_runtime_status() {
    let service = crate::application::backend_service::BackendService::new_for_test();

    let config = service.get_backend_config().unwrap();
    let runtime = service.get_runtime_entry_status().unwrap();

    assert!(!config.http_enabled);
    assert!(!runtime.http_active);
}
```

**Step 2: Run the test to verify it fails**

Run: `cargo test backend_service_reads_config_and_runtime_status --manifest-path rust/Cargo.toml`

Expected: FAIL because application service module does not exist.

**Step 3: Write the minimal application service and adapt `api.rs` to delegate**

```rust
pub struct BackendService {
    config_store: BackendConfigStore,
    runtime: Arc<RuntimeEntryManager>,
}

impl BackendService {
    pub fn get_backend_config(&self) -> Result<BackendConfigDto, ApiError> { /* ... */ }
    pub fn update_backend_config(&self, req: UpdateBackendConfigRequest) -> Result<BackendConfigDto, ApiError> { /* ... */ }
    pub fn get_runtime_entry_status(&self) -> Result<RuntimeEntryStatusDto, ApiError> { /* ... */ }
}
```

**Step 4: Run focused API and service tests**

Run: `cargo test backend_service --manifest-path rust/Cargo.toml && cargo test app_config_api_test --manifest-path rust/Cargo.toml && cargo test backend_api_contract_test --manifest-path rust/Cargo.toml`

Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/application/mod.rs rust/src/application/backend_service.rs rust/src/api.rs rust/src/lib.rs rust/src/DIR.md rust/tests/app_config_api_test.rs rust/tests/backend_api_contract_test.rs
git commit -m "refactor(rust): route api through backend service"
```

### Task 7: Add HTTP runtime contract and loopback-only listener

**Files:**
- Create: `rust/src/http/mod.rs`
- Create: `rust/src/http/server.rs`
- Create: `rust/tests/http_runtime_test.rs`
- Modify: `rust/src/lib.rs`
- Modify: `rust/src/DIR.md`
- Modify: `rust/Cargo.toml`

**Step 1: Write the failing tests**

```rust
#[tokio::test]
async fn http_runtime_starts_only_when_enabled() {
    let runtime = crate::runtime::entry_manager::RuntimeEntryManager::new_for_test();

    assert!(runtime.http_addr().is_none());
    runtime.apply_config(true, false, false).unwrap();

    assert_eq!(runtime.http_addr().unwrap().ip().to_string(), "127.0.0.1");
}
```

**Step 2: Run the test to verify it fails**

Run: `cargo test http_runtime_test --manifest-path rust/Cargo.toml`

Expected: FAIL because no HTTP module/server exists.

**Step 3: Write the minimal loopback HTTP server implementation**

```rust
pub struct HttpServerHandle {
    local_addr: SocketAddr,
}

impl HttpServerHandle {
    pub fn local_addr(&self) -> SocketAddr { self.local_addr }
}

pub async fn start_loopback_server(service: Arc<BackendService>) -> Result<HttpServerHandle, CardMindError> {
    let addr: SocketAddr = "127.0.0.1:0".parse().unwrap();
    // bind and spawn
    Ok(HttpServerHandle { local_addr: bound_addr })
}
```

**Step 4: Re-run the tests**

Run: `cargo test http_runtime_test --manifest-path rust/Cargo.toml`

Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/http/mod.rs rust/src/http/server.rs rust/src/lib.rs rust/src/DIR.md rust/Cargo.toml rust/tests/http_runtime_test.rs
git commit -m "feat(rust): add loopback http runtime"
```

### Task 8: Add MCP adapter contract on top of application services

**Files:**
- Create: `rust/src/mcp/mod.rs`
- Create: `rust/src/mcp/server.rs`
- Create: `rust/tests/mcp_adapter_test.rs`
- Modify: `rust/src/lib.rs`
- Modify: `rust/src/DIR.md`

**Step 1: Write the failing tests**

```rust
#[test]
fn mcp_tool_catalog_exposes_core_use_cases() {
    let server = crate::mcp::server::McpServer::new_for_test();
    let tools = server.list_tools();

    assert!(tools.iter().any(|tool| tool.name == "create_pool"));
    assert!(tools.iter().any(|tool| tool.name == "create_card_note"));
    assert!(tools.iter().any(|tool| tool.name == "run_sync_now"));
}
```

**Step 2: Run the test to verify it fails**

Run: `cargo test mcp_adapter_test --manifest-path rust/Cargo.toml`

Expected: FAIL because no MCP module exists.

**Step 3: Write the minimal MCP adapter**

```rust
pub struct McpTool {
    pub name: String,
    pub description: String,
}

pub struct McpServer {
    service: Arc<BackendService>,
}

impl McpServer {
    pub fn list_tools(&self) -> Vec<McpTool> { /* ... */ }
}
```

**Step 4: Re-run the tests**

Run: `cargo test mcp_adapter_test --manifest-path rust/Cargo.toml`

Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/mcp/mod.rs rust/src/mcp/server.rs rust/src/lib.rs rust/src/DIR.md rust/tests/mcp_adapter_test.rs
git commit -m "feat(rust): add mcp adapter contract"
```

### Task 9: Add debug CLI adapter contract

**Files:**
- Create: `rust/src/cli/mod.rs`
- Create: `rust/src/cli/debug_console.rs`
- Create: `rust/tests/cli_adapter_test.rs`
- Modify: `rust/src/lib.rs`
- Modify: `rust/src/DIR.md`

**Step 1: Write the failing tests**

```rust
#[test]
fn cli_debug_console_dispatches_backend_commands() {
    let console = crate::cli::debug_console::DebugConsole::new_for_test();

    let result = console.run_json(r#"{"command":"get_backend_config"}"#).unwrap();

    assert!(result.contains("http_enabled"));
}
```

**Step 2: Run the test to verify it fails**

Run: `cargo test cli_adapter_test --manifest-path rust/Cargo.toml`

Expected: FAIL because no CLI adapter module exists.

**Step 3: Write the minimal debug CLI adapter**

```rust
pub struct DebugConsole {
    service: Arc<BackendService>,
}

impl DebugConsole {
    pub fn run_json(&self, input: &str) -> Result<String, ApiError> {
        // parse command, dispatch to backend service, serialize response
    }
}
```

**Step 4: Re-run the tests**

Run: `cargo test cli_adapter_test --manifest-path rust/Cargo.toml`

Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/cli/mod.rs rust/src/cli/debug_console.rs rust/src/lib.rs rust/src/DIR.md rust/tests/cli_adapter_test.rs
git commit -m "feat(rust): add debug cli adapter"
```

### Task 10: Keep FRB as default entry while delegating to the shared backend service

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `lib/bridge_generated/api.dart`
- Modify: `lib/features/settings/settings_controller.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Test: `rust/tests/backend_api_contract_test.rs`
- Test: `test/` relevant Flutter settings tests

**Step 1: Write the failing tests**

```dart
testWidgets('settings can read and toggle optional backend entries', (tester) async {
  // render settings page with mocked FRB client
  // expect default disabled, then toggle HTTP on
});
```

```rust
#[test]
fn frb_api_exposes_backend_config_and_runtime_status() {
    let config = crate::api::get_backend_config().unwrap();
    assert!(!config.http_enabled);
}
```

**Step 2: Run the tests to verify they fail**

Run: `cargo test backend_api_contract_test --manifest-path rust/Cargo.toml && flutter test test/features/settings`

Expected: FAIL because FRB/Flutter do not expose entry config UI yet.

**Step 3: Write the minimal implementation**

```dart
class BackendSettingsState {
  final bool httpEnabled;
  final bool mcpEnabled;
  final bool cliEnabled;
}
```

```rust
pub fn get_runtime_entry_status() -> Result<RuntimeEntryStatusDto, ApiError> {
    backend_service().get_runtime_entry_status()
}
```

**Step 4: Re-run the tests**

Run: `cargo test backend_api_contract_test --manifest-path rust/Cargo.toml && flutter test test/features/settings`

Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/api.rs lib/bridge_generated/api.dart lib/features/settings/settings_controller.dart lib/features/settings/settings_page.dart rust/tests/backend_api_contract_test.rs test/features/settings
git commit -m "feat(settings): expose backend entry toggles via frb"
```

### Task 11: Add multi-entry consistency tests for pool/card/sync semantics

**Files:**
- Create: `rust/tests/multi_entry_consistency_test.rs`
- Modify: `rust/tests/backend_api_contract_test.rs`
- Modify: `rust/tests/sync_api_contract_test.rs`
- Modify: `rust/tests/pool_detail_contract_test.rs`
- Modify: `rust/tests/card_query_contract_test.rs`

**Step 1: Write the failing tests**

```rust
#[test]
fn pool_create_semantics_match_between_frb_http_cli_and_mcp() {
    let harness = MultiEntryHarness::new();

    let frb = harness.create_pool_via_frb("Pool A").unwrap();
    let http = harness.get_pool_via_http(&frb.id).unwrap();
    let cli = harness.get_pool_via_cli(&frb.id).unwrap();
    let mcp = harness.get_pool_via_mcp(&frb.id).unwrap();

    assert_eq!(frb.id, http.id);
    assert_eq!(http.id, cli.id);
    assert_eq!(cli.id, mcp.id);
}
```

**Step 2: Run the tests to verify they fail**

Run: `cargo test multi_entry_consistency_test --manifest-path rust/Cargo.toml`

Expected: FAIL because harness/adapters are incomplete or inconsistent.

**Step 3: Write the minimal harness and adapter glue**

```rust
struct MultiEntryHarness {
    service: Arc<BackendService>,
    // frb/http/cli/mcp handles
}
```

**Step 4: Re-run the tests**

Run: `cargo test multi_entry_consistency_test --manifest-path rust/Cargo.toml`

Expected: PASS

**Step 5: Commit**

```bash
git add rust/tests/multi_entry_consistency_test.rs rust/tests/backend_api_contract_test.rs rust/tests/sync_api_contract_test.rs rust/tests/pool_detail_contract_test.rs rust/tests/card_query_contract_test.rs
git commit -m "test(rust): verify multi-entry contract consistency"
```

### Task 12: Run full quality gates and update directory docs for new Rust modules

**Files:**
- Modify: `rust/src/DIR.md`
- Modify: `rust/DIR.md` (if module surface summary changes)
- Modify: `docs/plans/2026-03-16-rust-multi-entry-backend-implementation-plan.md` only if execution notes must be corrected after verification

**Step 1: Review directory docs for missing new modules**

```md
application/ - 目录 - 后端应用服务与 DTO 边界
runtime/ - 目录 - 入口配置与运行时管理
http/ - 目录 - 本机 HTTP 入口适配
mcp/ - 目录 - MCP 工具入口适配
cli/ - 目录 - 调试 CLI 入口适配
```

**Step 2: Run Rust quality gates**

Run: `dart run tool/quality.dart rust`

Expected: PASS (`cargo fmt --check`, `cargo clippy -D warnings`, `cargo test` all pass)

**Step 3: Run Flutter quality gates if FRB/settings bridge changed**

Run: `dart run tool/quality.dart flutter`

Expected: PASS (`flutter analyze`, `flutter test` pass)

**Step 4: Verify clean status except intended changes**

Run: `git status --short`

Expected: no unexpected untracked/generated files remain.

**Step 5: Commit**

```bash
git add rust/src/DIR.md rust/DIR.md
git commit -m "docs(rust): update module indexes for multi-entry backend"
```
