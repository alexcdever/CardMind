# CardMind 测试目录重构与命名规范

**重构目标**: 按测试类型划分目录，统一命名规范  
**重构范围**: Flutter (test/) + Rust (rust/tests/)  
**重构原则**: 目录即类型，命名即意图

---

## 一、测试类型定义

### 1.1 测试类型层级

```
测试金字塔
┌─────────────────────────────────────┐
│  E2E 测试 (e2e/)                    │  5%
│  - 完整用户流程                      │
├─────────────────────────────────────┤
│  集成测试 (integration/)              │  20%
│  - 模块间交互                        │
│  - 数据库/API/存储集成               │
├─────────────────────────────────────┤
│  契约测试 (contract/)                 │  10%
│  - API/接口契约验证                  │
├─────────────────────────────────────┤
│  单元测试 (unit/)                     │  65%
│  - 单个函数/类/组件                  │
│  - Widget 测试                       │
└─────────────────────────────────────┘
```

### 1.2 测试类型说明

| 类型 | 目录名 | 后缀 | 测试目标 | 依赖 |
|------|--------|------|---------|------|
| **单元测试** | `unit/` | `_test.dart` / `.rs` | 单个函数/类/Widget | 无外部依赖 |
| **集成测试** | `integration/` | `_test.dart` / `.rs` | 模块间交互 | 数据库、文件系统 |
| **契约测试** | `contract/` | `_contract_test.dart` / `_contract.rs` | API/接口契约 | 接口定义 |
| **E2E 测试** | `e2e/` | `_e2e_test.dart` | 完整用户流程 | 完整应用 |
| **性能测试** | `performance/` | `_perf_test.dart` / `_perf.rs` | 性能指标 | 测试数据 |

---

## 二、Flutter 端目录重构

### 2.1 新目录结构

```
test/
├── unit/                          # 单元测试 (快速、独立)
│   ├── domain/                    # 领域层单元测试
│   │   ├── card_note_test.dart
│   │   ├── pool_entity_test.dart
│   │   └── pool_member_test.dart
│   │
│   ├── application/               # 应用层单元测试
│   │   ├── cards_command_service_test.dart
│   │   ├── pool_command_service_test.dart
│   │   └── sync_controller_test.dart
│   │
│   ├── data/                      # 数据层单元测试
│   │   ├── sqlite_cards_repository_test.dart
│   │   ├── sqlite_pool_repository_test.dart
│   │   └── loro_doc_store_test.dart
│   │
│   └── presentation/              # 表现层单元测试
│       ├── cards_controller_test.dart
│       ├── pool_controller_test.dart
│       └── sync_state_test.dart
│
├── widget/                        # Widget 测试 (UI 组件)
│   ├── components/                # 通用组件
│   │   ├── card_list_item_test.dart
│   │   ├── pool_member_list_test.dart
│   │   └── sync_status_badge_test.dart
│   │
│   └── pages/                     # 页面级 Widget
│       ├── cards_page_test.dart
│       ├── pool_page_test.dart
│       ├── settings_page_test.dart
│       └── editor_page_test.dart
│
├── integration/                   # 集成测试 (模块交互)
│   ├── features/                  # 功能集成
│   │   ├── cards_crud_test.dart
│   │   ├── pool_lifecycle_test.dart
│   │   ├── pool_join_flow_test.dart
│   │   └── offline_sync_test.dart
│   │
│   └── infrastructure/            # 基础设施集成
│       ├── database_persistence_test.dart
│       ├── rust_bridge_test.dart
│       └── sync_gateway_test.dart
│
├── contract/                      # 契约测试 (API 契约)
│   ├── api/
│   │   ├── cards_api_contract_test.dart
│   │   ├── pool_api_contract_test.dart
│   │   └── sync_api_contract_test.dart
│   │
│   └── bridge/
│       └── flutter_rust_bridge_contract_test.dart
│
├── e2e/                           # E2E 测试 (完整流程)
│   └── flows/
│       ├── create_card_and_share_e2e_test.dart
│       ├── join_pool_and_collaborate_e2e_test.dart
│       └── offline_create_and_sync_e2e_test.dart
│
└── support/                       # 测试支持文件
    ├── fixtures/                  # 测试数据
    ├── helpers/                   # 测试辅助函数
    └── mocks/                     # Mock 对象
```

### 2.2 文件重命名映射

#### 当前 → 新命名

| 当前路径 | 新路径 | 类型 |
|---------|--------|------|
| `test/features/cards/domain/card_note_projection_test.dart` | `test/unit/domain/card_note_test.dart` | 单元测试 |
| `test/features/cards/application/cards_command_service_test.dart` | `test/unit/application/cards_command_service_test.dart` | 单元测试 |
| `test/features/cards/data/sqlite_cards_read_repository_test.dart` | `test/unit/data/sqlite_cards_repository_test.dart` | 单元测试 |
| `test/features/cards/cards_page_test.dart` | `test/widget/pages/cards_page_test.dart` | Widget 测试 |
| `test/features/pool/pool_page_test.dart` | `test/widget/pages/pool_page_test.dart` | Widget 测试 |
| `test/features/pool/pool_api_client_test.dart` | `test/contract/api/pool_api_contract_test.dart` | 契约测试 |
| `test/features/pool/pool_sync_interaction_test.dart` | `test/integration/features/pool_sync_test.dart` | 集成测试 |
| `test/bridge/backend_api_smoke_test.dart` | `test/integration/infrastructure/rust_bridge_test.dart` | 集成测试 |

---

## 三、Rust 端目录重构

### 3.1 新目录结构

```
rust/tests/
├── unit/                          # 单元测试
│   ├── domain/                    # 领域层
│   │   ├── card_model_test.rs
│   │   ├── pool_model_test.rs
│   │   └── member_model_test.rs
│   │
│   ├── store/                     # 存储层
│   │   ├── sqlite_store_test.rs
│   │   ├── loro_store_test.rs
│   │   └── path_resolver_test.rs
│   │
│   └── utils/                     # 工具函数
│       ├── uuid_v7_test.rs
│       └── api_error_test.rs
│
├── integration/                   # 集成测试
│   ├── api/                       # API 集成
│   │   ├── cards_crud_test.rs
│   │   ├── pool_lifecycle_test.rs
│   │   ├── pool_join_test.rs
│   │   └── offline_sync_test.rs
│   │
│   ├── store/                     # 存储集成
│   │   ├── card_store_persist_test.rs
│   │   ├── pool_store_persist_test.rs
│   │   └── sqlite_pool_test.rs
│   │
│   └── sync/                      # 同步集成
│       ├── pool_sync_test.rs
│       ├── multi_member_sync_test.rs
│       └── network_recovery_test.rs
│
├── contract/                      # 契约测试
│   ├── api/
│   │   ├── backend_api_contract.rs
│   │   ├── sync_api_contract.rs
│   │   └── pool_detail_contract.rs
│   │
│   └── store/
│       └── store_architecture_contract.rs
│
└── performance/                   # 性能测试
    ├── large_pool_sync_perf.rs
    ├── many_cards_query_perf.rs
    └── concurrent_sync_perf.rs
```

### 3.2 文件重命名映射

#### 当前 → 新命名

| 当前路径 | 新路径 | 类型 |
|---------|--------|------|
| `rust/tests/card_model_test.rs` | `rust/tests/unit/domain/card_model_test.rs` | 单元测试 |
| `rust/tests/card_store_test.rs` | `rust/tests/unit/store/loro_store_test.rs` | 单元测试 |
| `rust/tests/pool_join_by_code_test.rs` | `rust/tests/integration/api/pool_join_test.rs` | 集成测试 |
| `rust/tests/pool_collaboration_test.rs` | `rust/tests/integration/api/pool_lifecycle_test.rs` | 集成测试 |
| `rust/tests/pool_multi_member_sync_test.rs` | `rust/tests/integration/sync/multi_member_sync_test.rs` | 集成测试 |
| `rust/tests/backend_api_contract_test.rs` | `rust/tests/contract/api/backend_api_contract.rs` | 契约测试 |

---

## 四、命名规范详解

### 4.1 命名格式

```
<测试类型>/
  └── <层级>/
      └── <功能域>_<动作>_<场景>_<后缀>
```

### 4.2 命名组件

| 组件 | 说明 | 示例 |
|------|------|------|
| **功能域** | 被测试的功能模块 | `cards`, `pool`, `sync` |
| **动作** | 测试的操作 | `create`, `update`, `delete`, `join`, `sync` |
| **场景** | 测试的具体场景 | `success`, `failure`, `offline`, `concurrent` |
| **后缀** | 测试类型标识 | `_test.dart`, `_contract.rs`, `_perf.rs` |

### 4.3 命名示例

#### Flutter 单元测试
```
# 格式: <功能域>_<动作>_<场景>_test.dart

cards_create_success_test.dart           # 卡片创建成功
cards_delete_soft_test.dart              # 卡片软删除
pool_join_by_code_success_test.dart      # 通过邀请码加入池
pool_join_by_code_invalid_test.dart      # 邀请码无效
sync_offline_create_test.dart            # 离线创建
sync_retry_failure_test.dart             # 同步重试失败
```

#### Flutter Widget 测试
```
# 格式: <组件名>_test.dart

cards_page_test.dart                     # 卡片页面
pool_page_test.dart                      # 池页面
pool_member_list_test.dart               # 成员列表组件
sync_status_badge_test.dart              # 同步状态徽章
```

#### Flutter 集成测试
```
# 格式: <功能域>_<流程>_test.dart

cards_crud_test.dart                     # 卡片增删改查流程
pool_lifecycle_test.dart                 # 池生命周期流程
pool_join_flow_test.dart                 # 加入池流程
offline_sync_test.dart                   # 离线同步流程
```

#### Flutter 契约测试
```
# 格式: <功能域>_api_contract_test.dart

cards_api_contract_test.dart             # 卡片 API 契约
pool_api_contract_test.dart              # 池 API 契约
sync_api_contract_test.dart              # 同步 API 契约
```

#### Rust 单元测试
```
# 格式: <功能域>_<动作>_<场景>_test.rs

card_create_success_test.rs              # 卡片创建成功
pool_dissolve_success_test.rs            # 池解散成功
pool_leave_success_test.rs               # 退出池成功
member_approve_success_test.rs           # 审批成员成功
```

#### Rust 集成测试
```
# 格式: <功能域>_<流程>_test.rs

pool_lifecycle_test.rs                   # 池生命周期
offline_sync_test.rs                     # 离线同步
conflict_resolution_test.rs              # 冲突解决
network_recovery_test.rs                 # 网络恢复
```

#### Rust 契约测试
```
# 格式: <功能域>_contract.rs

backend_api_contract.rs                  # 后端 API 契约
sync_api_contract.rs                     # 同步 API 契约
pool_detail_contract.rs                  # 池详情契约
```

#### Rust 性能测试
```
# 格式: <场景>_perf.rs

large_pool_sync_perf.rs                  # 大数据池同步性能
many_cards_query_perf.rs                 # 大量卡片查询性能
concurrent_sync_perf.rs                  # 并发同步性能
```

---

## 五、重构实施计划

### 5.1 实施步骤

#### 第 1 步: 创建新目录结构
```bash
# Flutter 端
mkdir -p test/unit/{domain,application,data,presentation}
mkdir -p test/widget/{components,pages}
mkdir -p test/integration/{features,infrastructure}
mkdir -p test/contract/{api,bridge}
mkdir -p test/e2e/flows

# Rust 端
mkdir -p rust/tests/unit/{domain,store,utils}
mkdir -p rust/tests/integration/{api,store,sync}
mkdir -p rust/tests/contract/{api,store}
mkdir -p rust/tests/performance
```

#### 第 2 步: 移动并重命名文件
```bash
# 示例: Flutter
mv test/features/cards/domain/card_note_projection_test.dart \
   test/unit/domain/card_note_test.dart

# 示例: Rust
mv rust/tests/pool_join_by_code_test.rs \
   rust/tests/integration/api/pool_join_test.rs
```

#### 第 3 步: 更新导入路径
- 修改所有测试文件中的相对导入路径
- 更新测试辅助函数的导入

#### 第 4 步: 验证测试运行
```bash
# Flutter
flutter test

# Rust
cargo test
```

### 5.2 迁移检查清单

- [ ] 创建新目录结构
- [ ] 移动所有测试文件
- [ ] 重命名文件符合规范
- [ ] 更新导入路径
- [ ] 运行全部测试验证
- [ ] 删除旧目录
- [ ] 更新文档

---

## 六、新增测试规划

### 6.1 按新结构规划的新增测试

#### Flutter 端 (11 个)

```
test/
├── integration/features/
│   ├── pool_lifecycle_test.dart           # 池生命周期
│   ├── pool_join_flow_test.dart           # 加入池流程
│   └── offline_sync_test.dart             # 离线同步
│
└── widget/components/
    ├── pool_dissolve_button_test.dart     # 解散按钮
    ├── pool_leave_dialog_test.dart        # 退出对话框
    ├── pool_edit_form_test.dart           # 编辑表单
    ├── sync_offline_indicator_test.dart   # 离线指示器
    ├── sync_retry_button_test.dart        # 重试按钮
    └── sync_reconnect_button_test.dart    # 重连按钮
```

#### Rust 端 (18 个)

```
rust/tests/
├── integration/api/
│   ├── pool_lifecycle_test.rs             # 池生命周期
│   ├── offline_sync_test.rs               # 离线同步
│   └── conflict_resolution_test.rs        # 冲突解决
│
├── integration/sync/
│   └── network_recovery_test.rs           # 网络恢复
│
├── contract/api/
│   └── pool_lifecycle_contract.rs         # 池生命周期契约
│
└── performance/
    ├── large_pool_sync_perf.rs            # 大数据池性能
    ├── many_cards_query_perf.rs           # 大量卡片查询
    └── concurrent_sync_perf.rs            # 并发同步性能
```

---

## 七、总结

### 重构收益

1. **清晰的类型划分**: 通过目录即可识别测试类型
2. **统一的命名规范**: 文件名即测试意图
3. **易于维护**: 新增测试有明确的放置位置
4. **便于筛选**: 可以按类型运行测试 (`flutter test test/unit/`)

### 关键变更

| 方面 | 变更前 | 变更后 |
|------|--------|--------|
| **目录结构** | 按功能域划分 | 按测试类型划分 |
| **命名规范** | 不一致 | 统一规范 |
| **测试类型** | 隐含在文件名中 | 显式在目录中 |
| **可发现性** | 差 | 好 |

### 实施成本

- **文件移动**: ~78 个文件
- **重命名**: ~78 个文件
- **导入更新**: ~200+ 处
- **预估时间**: 2-3 天

是否需要我开始实施这个重构计划？
