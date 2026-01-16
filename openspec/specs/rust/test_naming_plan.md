# Spec Coding 测试重命名计划

## 📋 规格编号: SP-TEST-006
**版本**: 1.0.0  
**状态**: 待执行（等待数据模型层重构）  
**关联**: SP-DEV-002 (DeviceConfig 规格）

---

## 1. 概述

本文档记录了将现有测试重命名为 **Spec Coding 风格**（`it_should_xxx`）的计划。

**重要**: 重命名应在对应的数据模型重构**实施期间**进行，以避免编译错误。

---

## 2. 重命名规则

### 2.1 命名规范

| 风格 | 示例 | 优先级 |
|-----|------|--------|
| **推荐** | `it_should_allow_joining_first_pool_successfully()` | P0 |
| **推荐** | `it_rejects_joining_second_pool()` | P0 |
| **可接受** | `test_device_can_join_pool()` | P1 |
| **不推荐** | `check_device_join()` | P2 |

### 2.2 结构规范

```rust
/// Spec-XXX-A: 方法描述
/// 
/// it_should_describe_what_happens()
#[test]
fn it_should_describe_what_happens() {
    // Given: 初始条件
    let config = DeviceConfig::new();
    assert!(config.pool_id.is_none());
    
    // When: 执行操作
    config.join_pool("pool_A".to_string()).unwrap();
    
    // Then: 验证结果
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
    
    // And: 验证副作用（如有）
    assert!(config_file_exists());
}
```

---

## 3. DeviceConfig 测试重命名计划

### 3.1 当前测试（旧多池模型）

| 旧名称 | 状态 | 重命名为 | 备注 |
|-------|------|---------|------|
| `test_device_config_creation()` | 旧模型 | 等待实施 | 测试新模型后再重命名 |
| `test_join_pool()` | 旧模型 | 等待实施 | 需符合单池约束 |
| `test_leave_pool()` | 旧模型 | 等待实施 | 需符合单池模型 |
| `test_resident_pool()` | **已废弃** | 删除 | 单池模型不需要常驻池 |
| `test_save_and_load()` | 旧模型 | 等待实施 | 需适配新字段 |
| `test_get_or_create()` | 可用 | 等待实施 | 无需修改 |
| `test_default_path()` | 可用 | 等待实施 | 无需修改 |
| `test_serialization()` | 可用 | 等待实施 | 需适配新字段 |

### 3.2 新测试规格（SP-DEV-002）

根据规格文档，需要新增以下测试：

| 规格编号 | 测试名称 | 描述 |
|---------|---------|------|
| Spec-DEV-002-A | `it_accepts_first_pool_join_when_device_is_uninitialized()` | 未初始化设备可以加入第一个池 |
| Spec-DEV-002-B | `it_rejects_joining_second_pool_when_already_joined()` | 已加入设备拒绝加入第二个池 |
| Spec-DEV-002-C | `it_preserves_config_when_join_fails()` | 加入失败时配置不变 |
| Spec-DEV-002-D | `it_clears_pool_id_on_leave()` | 退出池时清空 pool_id |
| Spec-DEV-002-E | `it_clears_all_data_on_leave()` | 退出时清空所有本地数据 |
| Spec-DEV-002-F | `it_fails_to_leave_without_joined_pool()` | 未加入池时退出失败 |
| Spec-DEV-002-G | `it_creates_new_config_when_file_not_exists()` | 文件不存在时创建新配置 |
| Spec-DEV-002-H | `it_loads_existing_config_when_file_exists()` | 文件存在时加载配置 |

---

## 4. Pool 模型测试重命名计划

### 4.1 当前测试

| 旧名称 | 重命名为 | 备注 |
|-------|---------|------|
| `test_pool_creation()` | `it_creates_new_pool_with_empty_card_ids()` | 验证新池初始状态 |
| `test_add_member()` | `it_adds_new_member_to_pool()` | 添加成员设备 |
| `test_remove_member()` | `it_removes_member_from_pool()` | 移除成员设备 |
| `test_update_member_name()` | `it_updates_member_name_in_pool()` | 更新成员名称 |
| `test_validate_pool_name()` | `it_validates_pool_name()` | 池名称验证 |
| `test_validate_password()` | `it_validates_password_hash()` | 密码哈希验证 |
| `test_pool_serialization()` | `it_serializes_and_deserializes_pool()` | 序列化/反序列化 |

### 4.2 新增测试（SP-POOL-003）

| 规格编号 | 测试名称 | 描述 |
|---------|---------|------|
| Spec-POOL-002 | `it_adds_new_card_to_pool()` | 添加新卡片到池 |
| Spec-POOL-003 | `it_should_be_idempotent_when_adding_duplicate_card()` | 幂等性：重复添加跳过 |
| Spec-POOL-004 | `it_removes_card_from_pool()` | 从池移除卡片 |
| Spec-POOL-005 | `it_should_be_idempotent_when_removing_nonexistent_card()` | 幂等性：移除不存在卡片无操作 |
| Spec-POOL-006 | `it_should_update_timestamp_on_add()` | 添加卡片时更新时间戳 |
| Spec-POOL-007 | `it_should_update_timestamp_on_remove()` | 移除卡片时更新时间戳 |

---

## 5. Card 模型测试重命名计划

### 5.1 当前测试

| 旧名称 | 重命名为 | 备注 |
|-------|---------|------|
| `test_card_creation()` | `it_creates_card_with_uuid_v7_and_timestamps()` | 验证卡片创建 |
| `test_card_update()` | `it_updates_card_and_updates_timestamp()` | 验证卡片更新 |

---

## 6. 执行计划

### Week 2: 数据模型层重构（Day 1-2）

**顺序**: 按照依赖关系执行

1. **Day 1: DeviceConfig 重构**
   - [ ] 实施新模型（`pool_id: Option<String>`）
   - [ ] 删除旧测试（`test_resident_pool`, 多池相关）
   - [ ] 添加新测试（Spec-DEV-002 A-H）
   - [ ] 运行 `cargo test device_config::`

2. **Day 2: Pool 重构**
   - [ ] 添加 `card_ids: Vec<String>`
   - [ ] 实现 `add_card()` / `remove_card()`
   - [ ] 重命名现有测试（Spec-POOL-002-007）
   - [ ] 添加新测试
   - [ ] 运行 `cargo test pool::`

3. **Day 3: Card 模型调整**
   - [ ] 移除 Loro 层 `pool_ids` 字段
   - [ ] 重命名测试
   - [ ] 运行 `cargo test card::`

---

## 7. 验证清单

### 重命名后检查

- [ ] 所有测试名称使用 `it_should_xxx()` 或 `test_xxx()` 格式
- [ ] 测试遵循 Given-When-Then 结构
- [ ] 测试覆盖规格文档中定义的所有用例
- [ ] `cargo test` 全部通过
- [ ] 测试覆盖率 > 80%

### 命名风格一致性

```bash
# 检查是否有未使用 Spec Coding 风格的测试
grep -r "^#\[test\]" rust/src/ | grep -v "fn it_should_" | grep -v "fn test_"

# 统计 Spec Coding 风格测试数量
grep -r "fn it_should_" rust/src/ | wc -l
```

---

## 8. 参考

- **规格文档**:
  - SP-DEV-002: `specs/rust/device_config_spec.md`
  - SP-POOL-003: `specs/rust/pool_model_spec.md`
  - SP-CARD-004: `specs/rust/card_store_spec.md`
  
- **实施指南**: `specs/SPEC_CODING_GUIDE.md`
- **模板示例**: `rust/examples/single_pool_flow_spec.rs`

---

**规格编号**: SP-TEST-006  
**状态**: 待执行（等待数据模型层重构）  
**下一步**: 在 Week 2 数据模型层重构期间按此计划执行

