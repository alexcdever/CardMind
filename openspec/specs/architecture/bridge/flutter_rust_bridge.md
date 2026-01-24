# Flutter-Rust Bridge Architecture Specification
# Flutter-Rust 桥接架构规格

**Version**: 1.0.0
**版本**: 1.0.0
**Status**: Active
**状态**: Active
**Dependencies**: All Rust API modules
**依赖**: 所有 Rust API 模块
**Related Tests**: `rust/tests/api/bridge_test.rs`, `test/bridge_test.dart`
**相关测试**: `rust/tests/api/bridge_test.rs`, `test/bridge_test.dart`

---

## Overview
## 概述

This specification defines the cross-language communication mechanism between Flutter frontend and Rust backend in CardMind. The system uses Flutter Rust Bridge 2.11.1 to automatically generate FFI binding code, implementing efficient cross-language calls through SSE (Serialized Sync Encoding), supporting both synchronous and asynchronous operations.

本规格定义了 CardMind 中 Flutter 前端与 Rust 后端的跨语言通信机制。系统使用 Flutter Rust Bridge 2.11.1 自动生成 FFI 绑定代码，通过 SSE（Serialized Sync Encoding）编码方式实现高效的跨语言调用，支持同步和异步操作。

**Technology Stack**:
**技术栈**:
- flutter_rust_bridge = "2.11.1" (Rust)
- flutter_rust_bridge: ^2.11.0 (Dart)
- ffi: ^2.1.0 (Dart)

---

## Requirement: Automatic Code Generation
## 需求：自动代码生成

The system SHALL use Flutter Rust Bridge to automatically generate FFI binding code for Rust and Dart, ensuring type safety and interface consistency.

系统应使用 Flutter Rust Bridge 自动生成 Rust 和 Dart 的 FFI 绑定代码，确保类型安全和接口一致性。

### Scenario: Generate binding code when adding new API
### 场景：添加新 API 时生成绑定代码

- **GIVEN**: New API function defined in Rust, marked with `#[flutter_rust_bridge::frb]` macro
- **前置条件**: 在 Rust 中定义新的 API 函数，使用 `#[flutter_rust_bridge::frb]` 宏标记
- **WHEN**: Run code generation tool
- **操作**: 运行代码生成工具
- **THEN**: Rust FFI wrapper code and Dart API code SHALL be automatically generated
- **预期结果**: 应自动生成 Rust FFI 包装代码和 Dart API 代码
- **AND**: Generated code SHALL include type conversion, error handling, and memory management
- **并且**: 生成的代码应包含类型转换、错误处理和内存管理

**Generated Files**:
**生成的文件**:
- Rust: `rust/src/frb_generated.rs` - FFI binding code
- Rust: `rust/src/frb_generated.rs` - FFI 绑定代码
- Dart: `lib/bridge/frb_generated.dart` - Main entry
- Dart: `lib/bridge/frb_generated.dart` - 主入口
- Dart: `lib/bridge/api/*.dart` - API modules
- Dart: `lib/bridge/api/*.dart` - API 模块

**Implementation Logic**:
**实现逻辑**:

```
// Mark functions as exposable using macro
// 使用宏标记可暴露的函数
// Design decision: Use macro for declarative API exposure
// 设计决策：使用宏实现声明式 API 暴露
#[flutter_rust_bridge::frb]
function create_pool(name: String, password: String) -> Result<Pool>:
    // Implementation logic
    // 实现逻辑
    pool = PoolStore.create(name, password)
    return ok(pool)

// Automatically generate FFI wrapper code
// 自动生成 FFI 包装代码
// - Type conversion (Rust <-> C <-> Dart)
// - 类型转换（Rust <-> C <-> Dart）
// - Error handling (Result -> Exception)
// - 错误处理（Result -> Exception）
// - Memory management (ownership transfer)
// - 内存管理（所有权转移）
```

---

## Requirement: FFI Communication Mechanism
## 需求：FFI 通信机制

The system SHALL use Dart FFI (Foreign Function Interface) for low-level C interoperation, transmitting data through SSE encoding.

系统应使用 Dart FFI（Foreign Function Interface）进行低级 C 互操作，通过 SSE 编码方式传输数据。

### Scenario: Flutter calls Rust function
### 场景：Flutter 调用 Rust 函数

- **GIVEN**: Flutter needs to call Rust's card creation function
- **前置条件**: Flutter 需要调用 Rust 的卡片创建函数
- **WHEN**: Call Dart API `createCard(title: "My Note", content: "# Hello")`
- **操作**: 调用 Dart API `createCard(title: "My Note", content: "# Hello")`
- **THEN**: Data SHALL be transmitted to Rust via SSE encoding, Rust executes function and returns result
- **预期结果**: 数据应通过 SSE 编码传输到 Rust，Rust 执行函数并返回结果
- **AND**: Result SHALL be decoded via SSE and returned to Dart
- **并且**: 结果应通过 SSE 解码返回到 Dart

**Encoding Methods**:
**编码方式**:
- SSE (Serialized Sync Encoding) - Synchronous calls
- SSE (Serialized Sync Encoding) - 同步调用
- Message Port - Asynchronous calls
- Message Port - 异步调用

---

## Requirement: Synchronous and Asynchronous Support
## 需求：同步和异步支持

The system SHALL support both synchronous and asynchronous API calls, with synchronous calls using SSE encoding and asynchronous calls using message ports.

系统应支持同步和异步 API 调用，同步调用使用 SSE 编码，异步调用使用消息端口。

### Scenario: Asynchronously call Rust function
### 场景：异步调用 Rust 函数

- **GIVEN**: Flutter needs to asynchronously call Rust's pool creation function
- **前置条件**: Flutter 需要异步调用 Rust 的数据池创建函数
- **WHEN**: Call `await createPool(name: "Work Notes", password: "mypassword123")`
- **操作**: 调用 `await createPool(name: "工作笔记", password: "mypassword123")`
- **THEN**: Dart SHALL send request through message port without blocking UI thread
- **预期结果**: Dart 应通过消息端口发送请求，不阻塞 UI 线程
- **AND**: After Rust completes operation, result SHALL be returned through message port
- **并且**: Rust 完成操作后，应通过消息端口返回结果

---

## Requirement: Thread Safety
## 需求：线程安全

The system SHALL use thread-local storage to ensure thread safety of SQLite connections, with each thread maintaining an independent storage instance.

系统应使用线程本地存储确保 SQLite 连接的线程安全，每个线程维护独立的存储实例。

### Scenario: Multi-threaded storage access
### 场景：多线程访问存储

- **GIVEN**: Multiple Flutter isolates simultaneously call Rust API
- **前置条件**: 多个 Flutter isolate 同时调用 Rust API
- **WHEN**: Each isolate accesses SQLite database
- **操作**: 每个 isolate 访问 SQLite 数据库
- **THEN**: Each thread SHALL use independent SQLite connection
- **预期结果**: 每个线程应使用独立的 SQLite 连接
- **AND**: No data races or deadlocks SHALL occur
- **并且**: 不应发生数据竞争或死锁

**Implementation Logic**:
**实现逻辑**:

```
// Rust-side thread-local storage
// Rust 端线程本地存储
// Design decision: Use thread-local to avoid lock contention
// 设计决策：使用线程本地存储避免锁竞争
thread_local! {
    static POOL_STORE: RefCell<Option<PoolStore>> = RefCell::new(None);
}

// Initialize storage (independent per thread)
// 初始化存储（每个线程独立）
function init_pool_store(path: String):
    POOL_STORE.with(|store| {
        *store.borrow_mut() = Some(PoolStore::new(path));
    });

// Access storage (thread-safe)
// 访问存储（线程安全）
function get_pool_store() -> PoolStore:
    POOL_STORE.with(|store| {
        store.borrow().clone()
    });
```

---

## Requirement: Cross-Platform Support
## 需求：跨平台支持

The system SHALL support iOS, Android, Windows, macOS, Linux, and Web platforms, automatically handling platform differences.

系统应支持 iOS、Android、Windows、macOS、Linux 和 Web 平台，自动处理平台差异。

### Scenario: Load Rust library on different platforms
### 场景：在不同平台加载 Rust 库

- **GIVEN**: Application starts on a specific platform
- **前置条件**: 应用在特定平台上启动
- **WHEN**: Initialize Flutter Rust Bridge
- **操作**: 初始化 Flutter Rust Bridge
- **THEN**: Corresponding platform's Rust dynamic library SHALL be automatically loaded
- **预期结果**: 应自动加载对应平台的 Rust 动态库
- **AND**: iOS/Android use embedded library, desktop platforms use external library
- **并且**: iOS/Android 使用嵌入式库，桌面平台使用外部库

**Platform Library Paths**:
**平台库路径**:
- iOS/Android: Embedded library (compiled into app)
- iOS/Android: 嵌入式库（编译到应用中）
- Desktop: `rust/target/release/libcardmind_rust.{so,dylib,dll}`
- Desktop: `rust/target/release/libcardmind_rust.{so,dylib,dll}`
- Web: `pkg/cardmind_rust.wasm`
- Web: `pkg/cardmind_rust.wasm`

**Implementation Logic**:
**实现逻辑**:

```
// Dart-side library loading config
// Dart 端库加载配置
static const kDefaultExternalLibraryLoaderConfig =
    ExternalLibraryLoaderConfig(
        stem: 'cardmind_rust',
        ioDirectory: 'rust/target/release/',
        webPrefix: 'pkg/',
    );

// Initialize library
// 初始化库
// Design decision: Platform-specific loading strategy
// 设计决策：平台特定的加载策略
async function init():
    if (Platform.isIOS || Platform.isAndroid):
        // Mobile uses embedded library
        // 移动端使用嵌入式库
        await RustLib.init();
    else:
        // Desktop loads external library
        // 桌面端加载外部库
        await RustLib.init(
            externalLibrary: ExternalLibrary.open(
                kDefaultExternalLibraryLoaderConfig.stem
            )
        );
```

---

## Requirement: API Modularization
## 需求：API 模块化

The system SHALL organize APIs by functional modules, including card, pool, sync, and device config modules.

系统应将 API 按功能模块组织，包括卡片、数据池、同步和设备配置模块。

### Scenario: Call APIs from different modules
### 场景：调用不同模块的 API

- **GIVEN**: Flutter needs to call APIs from different functions
- **前置条件**: Flutter 需要调用不同功能的 API
- **WHEN**: Import corresponding module's API file
- **操作**: 导入对应模块的 API 文件
- **THEN**: All API functions from that module SHALL be callable
- **预期结果**: 应可以调用该模块的所有 API 函数
- **AND**: Modules SHALL be independent of each other for easy maintenance
- **并且**: 模块间应相互独立，便于维护

**API Modules**:
**API 模块**:
- `api/card.dart` - Card CRUD operations
- `api/card.dart` - 卡片 CRUD 操作
- `api/pool.dart` - Pool management, password verification, Keyring operations
- `api/pool.dart` - 数据池管理、密码验证、Keyring 操作
- `api/sync.dart` - P2P sync functionality
- `api/sync.dart` - P2P 同步功能
- `api/device_config.dart` - Device config, mDNS management
- `api/device_config.dart` - 设备配置、mDNS 管理

**Implementation Logic**:
**实现逻辑**:

```
// Card API
// 卡片 API
async function createCard(title, content):
    return await rust_bridge.create_card(title, content)

async function getActiveCards():
    return await rust_bridge.get_active_cards()

// Pool API
// 数据池 API
async function createPool(name, password):
    return await rust_bridge.create_pool(name, password)

async function verifyPoolPassword(poolId, password):
    return await rust_bridge.verify_pool_password(poolId, password)

// Keyring API
// Keyring API
async function storePoolPasswordInKeyring(poolId, password):
    await rust_bridge.store_pool_password_in_keyring(poolId, password)

async function getPoolPasswordFromKeyring(poolId):
    return await rust_bridge.get_pool_password_from_keyring(poolId)

// Sync API
// 同步 API
async function getLocalPeerId():
    return await rust_bridge.get_local_peer_id()

async function startDiscovery():
    await rust_bridge.start_discovery()
```

---

## Test Coverage
## 测试覆盖

**Test Files**:
**测试文件**:
- `rust/tests/api/bridge_test.rs` - Rust-side tests
- `rust/tests/api/bridge_test.rs` - Rust 端测试
- `test/bridge_test.dart` - Dart-side tests
- `test/bridge_test.dart` - Dart 端测试

**Unit Tests**:
**单元测试**:
- `test_ffi_type_conversion()` - Test FFI type conversion
- `test_ffi_type_conversion()` - 测试 FFI 类型转换
- `test_error_handling()` - Test error handling
- `test_error_handling()` - 测试错误处理
- `test_memory_management()` - Test memory management
- `test_memory_management()` - 测试内存管理
- `test_thread_local_storage()` - Test thread-local storage
- `test_thread_local_storage()` - 测试线程本地存储

**Integration Tests**:
**集成测试**:
- `test_card_api()` - Test card API
- `test_card_api()` - 测试卡片 API
- `test_pool_api()` - Test pool API
- `test_pool_api()` - 测试数据池 API
- `test_sync_api()` - Test sync API
- `test_sync_api()` - 测试同步 API
- `test_keyring_api()` - Test Keyring API
- `test_keyring_api()` - 测试 Keyring API

**Platform Tests**:
**平台测试**:
- `test_ios_library_loading()` - Test iOS library loading
- `test_ios_library_loading()` - 测试 iOS 库加载
- `test_android_library_loading()` - Test Android library loading
- `test_android_library_loading()` - 测试 Android 库加载
- `test_desktop_library_loading()` - Test desktop library loading
- `test_desktop_library_loading()` - 测试桌面库加载
- `test_web_wasm_loading()` - Test Web WASM loading
- `test_web_wasm_loading()` - 测试 Web WASM 加载

**Acceptance Criteria**:
**验收标准**:
- [x] All unit tests pass
- [x] 所有单元测试通过
- [x] All platform tests pass
- [x] 所有平台测试通过
- [x] FFI type conversion correct
- [x] FFI 类型转换正确
- [x] Error handling works correctly
- [x] 错误处理正常
- [x] Memory management without leaks
- [x] 内存管理无泄漏
- [x] Thread-safe
- [x] 线程安全
- [x] Code review approved
- [x] 代码审查通过
- [x] Documentation updated
- [x] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [../storage/card_store.md](../storage/card_store.md) - Card store implementation
- [../storage/card_store.md](../storage/card_store.md) - 卡片存储实现
- [../storage/pool_store.md](../storage/pool_store.md) - Pool store implementation
- [../storage/pool_store.md](../storage/pool_store.md) - 数据池存储实现
- [../security/keyring.md](../security/keyring.md) - Keyring password storage
- [../security/keyring.md](../security/keyring.md) - Keyring 密码存储
- [../sync/peer_discovery.md](../sync/peer_discovery.md) - mDNS peer discovery
- [../sync/peer_discovery.md](../sync/peer_discovery.md) - mDNS 设备发现

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0002-dual-layer-storage.md](../../../docs/adr/0002-dual-layer-storage.md) - Dual-layer storage architecture
- [../../../docs/adr/0002-dual-layer-storage.md](../../../docs/adr/0002-dual-layer-storage.md) - 双层存储架构
- [../../../docs/adr/0003-p2p-sync-architecture.md](../../../docs/adr/0003-p2p-sync-architecture.md) - P2P sync architecture
- [../../../docs/adr/0003-p2p-sync-architecture.md](../../../docs/adr/0003-p2p-sync-architecture.md) - P2P 同步架构

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23
**Authors**: CardMind Team
**作者**: CardMind Team
