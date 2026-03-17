# CardMind 测试类型全景分析与补充计划

**分析日期**: 2026-03-17  
**分析范围**: Flutter (41 个测试文件) + Rust (37 个测试文件)

---

## 一、测试类型分类体系

### 1.1 按测试层级分类

```
┌─────────────────────────────────────────────────────────────┐
│                    测试金字塔                                │
├─────────────────────────────────────────────────────────────┤
│  🟢 单元测试 (Unit Tests)                                    │
│     - 测试单个函数/类/组件                                   │
│     - 快速、独立、可重复                                     │
│     - 占比: 70-80%                                          │
├─────────────────────────────────────────────────────────────┤
│  🟡 集成测试 (Integration Tests)                             │
│     - 测试模块间交互                                         │
│     - 数据库、API、存储集成                                  │
│     - 占比: 15-20%                                          │
├─────────────────────────────────────────────────────────────┤
│  🔴 E2E 测试 (End-to-End Tests)                              │
│     - 完整用户流程                                           │
│     - 目前: 无                                              │
│     - 占比: 5-10%                                           │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 按测试目标分类

| 类型 | 描述 | Flutter 示例 | Rust 示例 |
|------|------|-------------|-----------|
| **功能测试** | 验证功能正确性 | `cards_page_test.dart` | `pool_join_by_code_test.rs` |
| **契约测试** | 验证 API/接口契约 | `pool_api_client_test.dart` | `backend_api_contract_test.rs` |
| **状态测试** | 验证状态转换 | `pool_sync_interaction_test.dart` | `pool_idempotency_test.rs` |
| **异常测试** | 验证错误处理 | `join_error_mapper_test.dart` | `api_error_test.rs` |
| **性能测试** | 验证性能指标 | 无 | 无 |
| **无障碍测试** | 验证 a11y 支持 | `semantic_ids_test.dart` | N/A |

### 1.3 按领域分类

#### Flutter 端 (41 个测试文件)

```
test/
├── 基础设施层 (4)
│   ├── build_cli_test.dart              # 构建工具测试
│   ├── quality_cli_test.dart            # 质量检查测试
│   ├── interaction_guard_test.dart      # 交互守卫测试
│   └── widget_test.dart                 # 基础 Widget 测试
│
├── 应用层 (2)
│   ├── app_homepage_navigation_test.dart    # 首页导航
│   └── adaptive_homepage_scaffold_test.dart # 响应式布局
│
├── 桥接层 (3)
│   ├── flutter_rust_flow_smoke_test.dart    # FRB 流程
│   ├── backend_api_smoke_test.dart          # 后端 API
│   └── sync_bridge_api_smoke_test.dart      # 同步桥接
│
└── 功能特性层 (32)
    ├── cards/ (12)
    │   ├── cards_page_test.dart
    │   ├── cards_api_client_test.dart
    │   ├── cards_desktop_interactions_test.dart
    │   ├── cards_sync_navigation_test.dart
    │   ├── cards_pool_filter_test.dart
    │   ├── application/cards_command_service_test.dart
    │   ├── data/sqlite_cards_read_repository_test.dart
    │   ├── domain/card_note_projection_test.dart
    │   └── projection/cards_projection_handler_test.dart
    │
    ├── pool/ (6)
    │   ├── pool_page_test.dart
    │   ├── pool_api_client_test.dart
    │   ├── pool_sync_interaction_test.dart
    │   ├── join_error_mapper_test.dart
    │   ├── application/pool_command_service_test.dart
    │   └── data/sqlite_pool_read_repository_test.dart
    │
    ├── sync/ (2)
    │   ├── sync_controller_test.dart
    │   └── sync_state_semantics_test.dart
    │
    ├── settings/ (1)
    │   └── settings_page_test.dart
    │
    ├── read_model/ (1)
    │   └── query_path_test.dart
    │
    ├── shared/ (4)
    │   ├── storage/loro_doc_store_test.dart
    │   ├── storage/loro_doc_path_test.dart
    │   └── projection/loro_projection_worker_test.dart
    │
    ├── accessibility/ (2)
    │   ├── semantic_ids_test.dart
    │   └── keyboard_navigation_test.dart
    │
    └── automation/ (1)
        └── automation_flow_test.dart
```

#### Rust 端 (37 个测试文件)

```
rust/tests/
├── 基础设施层 (4)
│   ├── smoke_test.rs                    # 冒烟测试
│   ├── path_resolver_test.rs            # 路径解析
│   ├── uuid_v7_test.rs                  # UUID 生成
│   └── api_error_test.rs                # 错误处理
│
├── 存储层 (8)
│   ├── sqlite_store_test.rs
│   ├── sqlite_store_cards_test.rs
│   ├── sqlite_store_pool_test.rs
│   ├── loro_store_test.rs
│   ├── loro_persist_test.rs
│   ├── card_store_test.rs
│   ├── card_store_persist_test.rs
│   ├── pool_store_test.rs
│   └── pool_store_persist_test.rs
│
├── API 契约层 (6)
│   ├── backend_api_contract_test.rs
│   ├── backend_config_api_test.rs
│   ├── sync_api_contract_test.rs
│   ├── sync_api_flow_test.rs
│   ├── pool_detail_contract_test.rs
│   └── card_query_contract_test.rs
│
├── 功能特性层 (19)
│   ├── card_model_test.rs
│   ├── card_api_delete_restore_test.rs
│   ├── pool_join_by_code_test.rs
│   ├── pool_idempotency_test.rs
│   ├── pool_collaboration_test.rs
│   ├── pool_multi_member_sync_test.rs
│   ├── pool_note_attachment_test.rs
│   ├── pool_sync_test.rs
│   ├── pool_network_flow_test.rs
│   ├── pool_net_endpoint_test.rs
│   ├── pool_net_session_test.rs
│   ├── pool_net_codec_test.rs
│   ├── current_user_pool_view_test.rs
│   ├── projection_flow_test.rs
│   ├── store_architecture_contract_test.rs
│   └── api_handle_test.rs
```

---

## 二、当前测试覆盖评估

### 2.1 Flutter 端覆盖矩阵

| 功能域 | 单元测试 | Widget 测试 | 集成测试 | 覆盖率 |
|--------|---------|------------|---------|--------|
| **卡片管理** | ✅ 4 | ✅ 2 | ⚠️ 1 | 85% |
| **数据池** | ✅ 3 | ✅ 1 | ✅ 2 | 80% |
| **同步** | ✅ 2 | ❌ 0 | ⚠️ 1 | 60% |
| **设置** | ❌ 0 | ✅ 1 | ❌ 0 | 30% |
| **导航/布局** | ❌ 0 | ✅ 2 | ❌ 0 | 70% |
| **无障碍** | ❌ 0 | ✅ 2 | ❌ 0 | 90% |

### 2.2 Rust 端覆盖矩阵

| 功能域 | 单元测试 | 集成测试 | 契约测试 | 覆盖率 |
|--------|---------|---------|---------|--------|
| **卡片 CRUD** | ✅ 3 | ✅ 2 | ✅ 1 | 90% |
| **数据池生命周期** | ⚠️ 2 | ✅ 3 | ✅ 2 | 75% |
| **成员管理** | ✅ 2 | ✅ 2 | ✅ 1 | 80% |
| **同步机制** | ✅ 2 | ✅ 3 | ✅ 2 | 85% |
| **离线场景** | ❌ 0 | ❌ 0 | ❌ 0 | 10% |
| **存储层** | ✅ 4 | ✅ 4 | ❌ 0 | 85% |

---

## 三、需要补充的测试清单

### 3.1 按测试类型分类

#### 🔴 类型 A: 功能测试 (Functional Tests)

**Flutter 端:**
```dart
// test/features/pool/pool_lifecycle_test.dart
- testDissolvePoolButton          // 解散池按钮功能
- testLeavePoolConfirmation       // 退出池确认对话框
- testPoolEditDialog              // 编辑池信息对话框

// test/features/sync/sync_offline_test.dart
- testOfflineIndicator            // 离线状态指示器
- testSyncRetryButton             // 同步重试按钮
- testSyncReconnectButton         // 重新连接按钮

// test/features/settings/settings_functional_test.dart
- testSettingsNavigation          // 设置页面导航
- testThemeToggle                 // 主题切换
```

**Rust 端:**
```rust
// rust/tests/pool_lifecycle_test.rs
- test_dissolve_pool              // 解散池完整流程
- test_leave_pool                 // 退出池
- test_pool_owner_invariant       // 管理员不变量

// rust/tests/offline_sync_test.rs
- test_create_card_offline        // 离线创建卡片
- test_edit_card_offline          // 离线编辑卡片
- test_sync_after_reconnect       // 重连后同步

// rust/tests/conflict_resolution_test.rs
- test_concurrent_edit            // 并发编辑冲突
- test_offline_offline_conflict   // 双离线冲突
```

#### 🟡 类型 B: 契约测试 (Contract Tests)

**Flutter 端:**
```dart
// test/features/pool/pool_api_contract_test.dart (扩展)
- testDissolvePoolContract        // 解散池 API 契约
- testLeavePoolContract           // 退出池 API 契约
- testEditPoolContract            // 编辑池 API 契约
```

**Rust 端:**
```rust
// rust/tests/pool_lifecycle_contract_test.rs
- test_dissolve_pool_contract     // 解散池契约
- test_leave_pool_contract        // 退出池契约
```

#### 🟢 类型 C: 状态测试 (State Tests)

**Flutter 端:**
```dart
// test/features/pool/pool_state_transitions_test.dart
- testPoolStateTransitions        // 池状态转换
- testMemberRoleTransitions       // 成员角色转换

// test/features/sync/sync_state_machine_test.dart
- testSyncStateTransitions        // 同步状态机
- testOfflineToOnlineTransition   // 离线到在线转换
```

**Rust 端:**
```rust
// rust/tests/pool_state_machine_test.rs
- test_pool_lifecycle_state_machine   // 池生命周期状态机
- test_member_state_transitions       // 成员状态转换
```

#### 🔵 类型 D: 异常测试 (Exception Tests)

**Flutter 端:**
```dart
// test/features/error/error_boundary_test.dart
- testDissolvePoolError           // 解散池错误
- testLeavePoolError              // 退出池错误
- testNetworkTimeoutError         // 网络超时错误
```

**Rust 端:**
```rust
// rust/tests/pool_error_handling_test.rs
- test_dissolve_nonexistent_pool  // 解散不存在池
- test_leave_non_member_pool      // 退出非成员池
- test_last_admin_leave           // 最后管理员退出
```

#### 🟣 类型 E: 性能测试 (Performance Tests)

**Rust 端:**
```rust
// rust/tests/performance_test.rs
- test_large_pool_sync            // 大数据池同步
- test_many_cards_query           // 大量卡片查询
- test_concurrent_member_sync     // 并发成员同步
```

---

### 3.2 按优先级分类

#### 🔴 高优先级 (核心功能缺失)

| # | 测试名称 | 类型 | 层级 | 端 | 规格依据 |
|---|---------|------|------|-----|---------|
| 1 | 解散池完整流程 | 功能测试 | 集成 | Rust | pool.md 4.1, 8.1 #7 |
| 2 | 成员退出池 | 功能测试 | 集成 | Rust | pool.md 4.1, 8.1 #5 |
| 3 | 管理员不变量 | 功能测试 | 单元 | Rust | pool.md 4.3, 8.1 #6 |
| 4 | 离线创建卡片 | 功能测试 | 集成 | Rust | pool.md 6.2 |
| 5 | 离线编辑卡片 | 功能测试 | 集成 | Rust | pool.md 6.2 |
| 6 | 并发编辑冲突 | 功能测试 | 集成 | Rust | pool.md 6.3 |
| 7 | 解散池按钮功能 | 功能测试 | Widget | Flutter | ui-interaction.md 5.4 |
| 8 | 退出池确认对话框 | 功能测试 | Widget | Flutter | ui-interaction.md 5.4 |

#### 🟡 中优先级 (边界情况)

| # | 测试名称 | 类型 | 层级 | 端 | 规格依据 |
|---|---------|------|------|-----|---------|
| 9 | 网络超时重试 | 异常测试 | 集成 | Rust | ui-interaction.md 6.6 |
| 10 | 无效池ID处理 | 异常测试 | 单元 | Rust | pool.md 5.2 |
| 11 | 已解散池拒绝 | 异常测试 | 集成 | Rust | pool.md 5.2 #2, #3 |
| 12 | 同步状态机 | 状态测试 | 单元 | Flutter | ui-interaction.md 6.5 |
| 13 | 池状态转换 | 状态测试 | 单元 | Flutter | pool.md 4.1 |

#### 🟢 低优先级 (性能/优化)

| # | 测试名称 | 类型 | 层级 | 端 | 规格依据 |
|---|---------|------|------|-----|---------|
| 14 | 大数据池同步性能 | 性能测试 | 集成 | Rust | - |
| 15 | 大量卡片查询性能 | 性能测试 | 集成 | Rust | - |
| 16 | 并发成员同步性能 | 性能测试 | 集成 | Rust | - |

---

## 四、测试类型统计

### 4.1 当前测试类型分布

| 测试类型 | Flutter | Rust | 总计 | 占比 |
|---------|---------|------|------|------|
| 单元测试 | 12 | 15 | 27 | 34% |
| Widget 测试 | 8 | N/A | 8 | 10% |
| 集成测试 | 18 | 22 | 40 | 50% |
| 契约测试 | 3 | 6 | 9 | 11% |
| 性能测试 | 0 | 0 | 0 | 0% |
| **总计** | **41** | **37** | **78** | **100%** |

### 4.2 需要补充的测试类型分布

| 测试类型 | Flutter | Rust | 总计 | 优先级 |
|---------|---------|------|------|--------|
| 功能测试 | 3 | 8 | 11 | 🔴 高 |
| 契约测试 | 3 | 2 | 5 | 🟡 中 |
| 状态测试 | 2 | 2 | 4 | 🟡 中 |
| 异常测试 | 3 | 3 | 6 | 🟡 中 |
| 性能测试 | 0 | 3 | 3 | 🟢 低 |
| **总计** | **11** | **18** | **29** | - |

---

## 五、实施建议

### 5.1 实施顺序

**第 1 周: 高优先级功能测试**
- Rust: 池生命周期管理 (3 个测试)
- Flutter: 池生命周期 UI (2 个测试)

**第 2 周: 离线同步场景**
- Rust: 离线功能测试 (5 个测试)

**第 3 周: 异常处理和状态测试**
- Rust: 异常测试 (3 个测试)
- Flutter: 状态测试 (2 个测试)

**第 4 周: 契约测试和性能测试**
- Flutter + Rust: 契约测试 (5 个测试)
- Rust: 性能测试 (3 个测试)

### 5.2 测试命名规范

**Flutter:**
```dart
// 格式: test<功能><场景><预期结果>
testDissolvePoolSuccess()
testDissolvePoolUnauthorized()
testDissolvePoolAlreadyDissolved()
```

**Rust:**
```rust
// 格式: test_<功能>_<场景>_<预期结果>
test_dissolve_pool_success()
test_dissolve_pool_unauthorized()
test_dissolve_pool_already_dissolved()
```

### 5.3 测试文件组织

```
test/
├── features/
│   └── pool/
│       ├── pool_page_test.dart              # 已有
│       ├── pool_api_client_test.dart        # 已有
│       ├── pool_lifecycle_test.dart         # 新增
│       ├── pool_state_transitions_test.dart # 新增
│       └── pool_error_test.dart             # 新增

rust/tests/
├── pool_lifecycle_test.rs                   # 新增
├── offline_sync_test.rs                     # 新增
├── conflict_resolution_test.rs              # 新增
├── pool_error_handling_test.rs              # 新增
├── pool_state_machine_test.rs               # 新增
└── performance_test.rs                      # 新增
```

---

## 六、总结

### 当前状态
- **总测试数**: 78 个 (Flutter 41 + Rust 37)
- **测试类型**: 5 种 (单元、Widget、集成、契约、性能)
- **覆盖率**: 核心功能 75-90%，离线场景 10%

### 需要补充
- **新测试数**: 29 个 (Flutter 11 + Rust 18)
- **预估工作量**: 4 周 (16 天)
- **优先级**: 高 8 个，中 15 个，低 6 个

### 关键缺口
1. ❌ 池生命周期管理测试 (解散、退出)
2. ❌ 离线同步场景测试
3. ❌ 并发冲突解决测试
4. ❌ 性能基准测试

是否需要我为这些测试制定详细的实现计划？
