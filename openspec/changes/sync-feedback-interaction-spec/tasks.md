# Implementation Tasks

## 1. 规格文档创建

- [ ] 1.1 将规格从 change 迁移到 `openspec/specs/flutter/sync_feedback_spec.md`
- [ ] 1.2 更新 `openspec/specs/README.md` 添加 SP-FLUT-010 索引
- [ ] 1.3 在 `docs/interaction/feedback_design.md` 中移除交互规格内容，添加到新规格的引用

## 2. 测试用例编写

- [ ] 2.1 创建 `test/specs/sync_feedback_spec_test.dart` 测试文件
- [ ] 2.2 编写状态机测试（disconnected → syncing → synced/failed）
- [ ] 2.3 编写状态转换测试（所有可能的转换）
- [ ] 2.4 编写 UI 渲染测试（图标、文字、颜色）
- [ ] 2.5 编写动画测试（旋转动画）
- [ ] 2.6 编写 Stream 订阅测试（订阅、取消订阅）
- [ ] 2.7 编写去重和 debounce 测试
- [ ] 2.8 编写点击交互测试（显示详情对话框）
- [ ] 2.9 编写无障碍测试（semantic labels）
- [ ] 2.10 运行测试确保全部失败（TDD 红灯阶段）

## 3. 状态模型实现

- [ ] 3.1 创建 `lib/models/sync_status.dart`
- [ ] 3.2 定义 `SyncState` 枚举（disconnected, syncing, synced, failed）
- [ ] 3.3 实现 `SyncStatus` 类（state, syncingPeers, lastSyncTime, errorMessage）
- [ ] 3.4 实现 `SyncStatus.disconnected()` 工厂方法
- [ ] 3.5 实现 `SyncStatus.syncing()` 工厂方法
- [ ] 3.6 实现 `SyncStatus.synced()` 工厂方法
- [ ] 3.7 实现 `SyncStatus.failed()` 工厂方法
- [ ] 3.8 实现 `isActive` getter
- [ ] 3.9 实现 `==` 和 `hashCode`（用于去重）

## 4. 同步状态指示器组件

- [ ] 4.1 创建 `lib/widgets/sync_status_indicator.dart`
- [ ] 4.2 实现 `SyncStatusIndicator` StatefulWidget
- [ ] 4.3 实现图标选择逻辑（根据状态）
- [ ] 4.4 实现颜色选择逻辑（根据状态）
- [ ] 4.5 实现文字显示逻辑（根据状态）
- [ ] 4.6 实现旋转动画（syncing 状态）
- [ ] 4.7 实现点击事件处理（显示详情对话框）
- [ ] 4.8 实现无障碍标签（Semantics）
- [ ] 4.9 实现相对时间显示（"刚刚"、"5分钟前"）

## 5. 同步详情对话框

- [ ] 5.1 创建 `lib/widgets/sync_details_dialog.dart`
- [ ] 5.2 实现对话框布局（标题、状态、对等设备列表）
- [ ] 5.3 实现状态描述显示
- [ ] 5.4 实现对等设备列表显示
- [ ] 5.5 实现错误信息显示（failed 状态）
- [ ] 5.6 实现重试按钮（failed 状态）
- [ ] 5.7 实现关闭按钮
- [ ] 5.8 连接重试逻辑到 SyncApi

## 6. Stream 集成

- [ ] 6.1 在 `SyncStatusIndicator` 中使用 StreamBuilder
- [ ] 6.2 订阅 `SyncApi.statusStream`
- [ ] 6.3 实现 `distinct()` 过滤重复状态
- [ ] 6.4 实现 debounce 逻辑（500ms）
- [ ] 6.5 确保 dispose 时取消订阅
- [ ] 6.6 处理 Stream 错误

## 7. 主页集成

- [ ] 7.1 在 `lib/screens/home_screen.dart` AppBar 添加 `SyncStatusIndicator`
- [ ] 7.2 确保指示器位置正确（AppBar 右侧）
- [ ] 7.3 确保指示器始终可见（不随滚动隐藏）
- [ ] 7.4 更新 `HomeScreenState`（如需要）

## 8. API 集成验证

- [ ] 8.1 确认 `SyncApi.statusStream` 存在并返回正确类型
- [ ] 8.2 确认 `SyncApi.getSyncStatus()` 存在
- [ ] 8.3 确认 `SyncApi.retrySync()` 存在（或实现）
- [ ] 8.4 测试 API 集成（手动触发状态变化）

## 9. 性能优化

- [ ] 9.1 实现 `distinct()` 避免重复更新
- [ ] 9.2 实现 debounce 避免闪烁
- [ ] 9.3 优化动画性能（使用 AnimationController）
- [ ] 9.4 添加性能监控日志
- [ ] 9.5 测试内存泄漏（确保 Stream 正确 dispose）

## 10. 测试验证

- [ ] 10.1 运行所有单元测试（`flutter test test/specs/sync_feedback_spec_test.dart`）
- [ ] 10.2 运行所有 widget 测试
- [ ] 10.3 运行集成测试
- [ ] 10.4 确保测试覆盖率 > 90%
- [ ] 10.5 修复所有失败的测试

## 11. 代码质量检查

- [ ] 11.1 运行 `dart tool/validate_constraints.dart`
- [ ] 11.2 运行 `dart tool/fix_lint.dart`
- [ ] 11.3 确保没有 `unwrap()` / `expect()` / `panic!()`
- [ ] 11.4 确保所有方法返回 `Result<T, Error>`（Rust 侧）
- [ ] 11.5 代码审查

## 12. 文档更新

- [ ] 12.1 更新 `docs/interaction/feedback_design.md`（移除交互规格，添加引用）
- [ ] 12.2 更新 `openspec/specs/README.md`（添加 SP-FLUT-010）
- [ ] 12.3 更新 `docs/design/` 中的相关引用
- [ ] 12.4 更新规格状态为"已完成"
- [ ] 12.5 生成 API 文档

## 13. 集成测试

- [ ] 13.1 在真实设备上测试完整流程
- [ ] 13.2 测试所有状态转换（手动触发）
- [ ] 13.3 测试 Stream 实时更新
- [ ] 13.4 测试错误场景（网络断开、同步失败）
- [ ] 13.5 测试性能（无内存泄漏、无卡顿）
- [ ] 13.6 测试无障碍功能

## 14. 规格同步

- [ ] 14.1 使用 `openspec sync` 将 delta spec 同步到主规格
- [ ] 14.2 更新 SP-FLUT-008 规格（如有修改）
- [ ] 14.3 验证规格一致性

## 15. Change 归档

- [ ] 15.1 运行 `openspec verify` 验证实现
- [ ] 15.2 运行 `openspec archive` 归档 change
- [ ] 15.3 清理临时文件

---

## 依赖关系

```
1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12 → 13 → 14 → 15
    ↓       ↓   ↓
    └───────┴───┘ (并行)
```

**关键路径**:
1. 规格文档 → 测试用例 → 状态模型 → UI 组件 → Stream 集成 → 主页集成 → 测试验证

**可并行任务**:
- 状态模型实现 和 测试用例编写 可以部分并行
- 同步状态指示器 和 同步详情对话框 可以并行开发

---

## 验证标准

每个任务完成后，确保：
- [ ] 代码编译通过
- [ ] 相关测试通过
- [ ] 符合 Project Guardian 约束
- [ ] 代码审查通过

---

**预计工作量**: 6-10 小时
**优先级**: 高
**风险**: 低（依赖 Rust API，但 API 已存在）
