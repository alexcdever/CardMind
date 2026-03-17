# 测试目录重构与命名规范设计

**设计日期**: 2026-03-17  
**设计目标**: 按测试类型划分目录，统一命名规范，提高测试可维护性  
**涉及范围**: Flutter (test/) + Rust (rust/tests/)

---

## 1. 设计背景

### 1.1 当前问题

当前测试目录按功能域划分，存在以下问题：
- 测试类型混杂在同一目录中（单元测试、集成测试、Widget 测试混在一起）
- 命名不规范，无法从文件名识别测试类型
- 新增测试时没有明确的放置位置
- 难以按类型运行测试（如只运行集成测试）

### 1.2 设计目标

1. **目录即类型**: 通过目录结构即可识别测试类型
2. **命名即意图**: 文件名清晰表达测试内容和场景
3. **易于维护**: 新增测试有明确的放置位置
4. **便于筛选**: 支持按类型运行测试

---

## 2. 测试类型定义

### 2.1 测试金字塔

```
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

### 2.2 测试类型说明

| 类型 | 目录名 | 后缀 | 测试目标 | 依赖 |
|------|--------|------|---------|------|
| **单元测试** | `unit/` | `_test.dart` / `.rs` | 单个函数/类/Widget | 无外部依赖 |
| **Widget 测试** | `widget/` | `_test.dart` | UI 组件 | Flutter 测试环境 |
| **集成测试** | `integration/` | `_test.dart` / `.rs` | 模块间交互 | 数据库、文件系统 |
| **契约测试** | `contract/` | `_contract_test.dart` / `_contract.rs` | API/接口契约 | 接口定义 |
| **E2E 测试** | `e2e/` | `_e2e_test.dart` | 完整用户流程 | 完整应用 |
| **性能测试** | `performance/` | `_perf_test.dart` / `_perf.rs` | 性能指标 | 测试数据 |

---

## 3. 目录结构设计

### 3.1 Flutter 端目录结构

```
test/
├── unit/                          # 单元测试 (快速、独立)
│   ├── domain/                    # 领域层单元测试
│   ├── application/               # 应用层单元测试
│   ├── data/                      # 数据层单元测试
│   └── presentation/              # 表现层单元测试
│
├── widget/                        # Widget 测试 (UI 组件)
│   ├── components/                # 通用组件
│   └── pages/                     # 页面级 Widget
│
├── integration/                   # 集成测试 (模块交互)
│   ├── features/                  # 功能集成
│   └── infrastructure/            # 基础设施集成
│
├── contract/                      # 契约测试 (API 契约)
│   ├── api/
│   └── bridge/
│
├── e2e/                           # E2E 测试 (完整流程)
│   └── flows/
│
└── support/                       # 测试支持文件
    ├── fixtures/                  # 测试数据
    ├── helpers/                   # 测试辅助函数
    └── mocks/                     # Mock 对象
```

### 3.2 Rust 端目录结构

```
rust/tests/
├── unit/                          # 单元测试
│   ├── domain/                    # 领域层
│   ├── store/                     # 存储层
│   └── utils/                     # 工具函数
│
├── integration/                   # 集成测试
│   ├── api/                       # API 集成
│   ├── store/                     # 存储集成
│   └── sync/                      # 同步集成
│
├── contract/                      # 契约测试
│   ├── api/
│   └── store/
│
└── performance/                   # 性能测试
```

---

## 4. 命名规范设计

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
cards_create_success_test.dart           # 卡片创建成功
cards_delete_soft_test.dart              # 卡片软删除
pool_join_by_code_success_test.dart      # 通过邀请码加入池
pool_join_by_code_invalid_test.dart      # 邀请码无效
sync_offline_create_test.dart            # 离线创建
sync_retry_failure_test.dart             # 同步重试失败
```

#### Flutter Widget 测试
```
cards_page_test.dart                     # 卡片页面
pool_page_test.dart                      # 池页面
pool_member_list_test.dart               # 成员列表组件
sync_status_badge_test.dart              # 同步状态徽章
```

#### Flutter 集成测试
```
cards_crud_test.dart                     # 卡片增删改查流程
pool_lifecycle_test.dart                 # 池生命周期流程
pool_join_flow_test.dart                 # 加入池流程
offline_sync_test.dart                   # 离线同步流程
```

#### Flutter 契约测试
```
cards_api_contract_test.dart             # 卡片 API 契约
pool_api_contract_test.dart              # 池 API 契约
sync_api_contract_test.dart              # 同步 API 契约
```

#### Rust 单元测试
```
card_create_success_test.rs              # 卡片创建成功
pool_dissolve_success_test.rs            # 池解散成功
pool_leave_success_test.rs               # 退出池成功
member_approve_success_test.rs           # 审批成员成功
```

#### Rust 集成测试
```
pool_lifecycle_test.rs                   # 池生命周期
offline_sync_test.rs                     # 离线同步
conflict_resolution_test.rs              # 冲突解决
network_recovery_test.rs                 # 网络恢复
```

#### Rust 契约测试
```
backend_api_contract.rs                  # 后端 API 契约
sync_api_contract.rs                     # 同步 API 契约
pool_detail_contract.rs                  # 池详情契约
```

#### Rust 性能测试
```
large_pool_sync_perf.rs                  # 大数据池同步性能
many_cards_query_perf.rs                 # 大量卡片查询性能
concurrent_sync_perf.rs                  # 并发同步性能
```

---

## 5. 现有文件映射

### 5.1 Flutter 端映射

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

### 5.2 Rust 端映射

| 当前路径 | 新路径 | 类型 |
|---------|--------|------|
| `rust/tests/card_model_test.rs` | `rust/tests/unit/domain/card_model_test.rs` | 单元测试 |
| `rust/tests/card_store_test.rs` | `rust/tests/unit/store/loro_store_test.rs` | 单元测试 |
| `rust/tests/pool_join_by_code_test.rs` | `rust/tests/integration/api/pool_join_test.rs` | 集成测试 |
| `rust/tests/pool_collaboration_test.rs` | `rust/tests/integration/api/pool_lifecycle_test.rs` | 集成测试 |
| `rust/tests/pool_multi_member_sync_test.rs` | `rust/tests/integration/sync/multi_member_sync_test.rs` | 集成测试 |
| `rust/tests/backend_api_contract_test.rs` | `rust/tests/contract/api/backend_api_contract.rs` | 契约测试 |

---

## 6. 新增测试规划

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

## 7. 设计决策

### 7.1 为什么按测试类型划分而不是功能域

**按功能域划分的问题**:
- 同一功能域内测试类型混杂
- 难以按类型运行测试
- 新增测试时类型不清晰

**按测试类型划分的优势**:
- 目录结构即测试类型
- 便于按类型运行测试 (`flutter test test/unit/`)
- 新增测试类型明确
- 符合测试金字塔分层思想

### 7.2 为什么分离 Widget 测试和单元测试

- Widget 测试需要 Flutter 测试环境，运行较慢
- 单元测试纯 Dart，运行快速
- 分离后便于分别运行和优化

### 7.3 为什么 Rust 端不需要 Widget 测试目录

- Rust 端没有 UI 层
- 所有测试都是后端逻辑测试

---

## 8. 验收标准

重构完成后应满足：

1. ✅ 所有测试文件按类型放置在正确目录
2. ✅ 所有测试文件名符合命名规范
3. ✅ 所有测试导入路径更新正确
4. ✅ 运行 `flutter test` 全部通过
5. ✅ 运行 `cargo test` 全部通过
6. ✅ 可以按类型运行测试（如 `flutter test test/unit/`）
7. ✅ 旧目录结构已删除

---

## 9. 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 导入路径遗漏 | 测试无法编译 | 使用 IDE 全局搜索替换 |
| 测试文件遗漏 | 测试丢失 | 建立完整的文件映射表 |
| 测试运行失败 | 功能回归 | 重构后全量运行测试验证 |

---

**设计完成**: 2026-03-17  
**设计文档**: `docs/superpowers/specs/2026-03-17-test-directory-refactoring-design.md`
