# Implementation Tasks

## 1. 规格文档创建

- [x] 将规格从 change 迁移到 `openspec/specs/flutter/card_creation_spec.md`
- [x] 更新 `openspec/specs/README.md` 添加 SP-FLUT-009 索引
- [x] 在 `docs/interaction/ui_flows.md` 中移除交互规格内容，添加到新规格的引用

## 2. 测试用例编写

- [x] 创建 `test/specs/card_creation_spec_test.dart` 测试文件
- [x] 编写 FAB 按钮相关测试（显示、点击、导航）
- [x] 编写输入字段相关测试（标题、内容、占位符）
- [x] 编写自动保存相关测试（debounce、触发、指示器）
- [x] 编写验证相关测试（空标题、长度限制）
- [x] 编写错误处理相关测试（网络错误、重试）
- [x] 编写导航相关测试（完成、取消、确认对话框）
- [x] 编写性能测试（30 秒约束）
- [x] 运行测试确保全部失败（TDD 红灯阶段）

## 3. 状态管理实现

- [x] 创建 `lib/providers/card_editor_state.dart`
- [x] 实现 `CardEditorState` 类（继承 ChangeNotifier）
- [x] 添加状态字段（title, content, isSaving, errorMessage, lastSaved）
- [x] 实现 `updateTitle()` 方法
- [x] 实现 `updateContent()` 方法
- [x] 实现 `autoSave()` 方法（带 debounce）
- [x] 实现 `manualSave()` 方法
- [x] 实现 `validate()` 方法
- [x] 实现错误处理逻辑

## 4. UI 组件实现

- [x] 创建 `lib/screens/card_editor_screen.dart`
- [x] 实现 AppBar（标题、返回按钮、完成按钮）
- [x] 实现标题输入框（TextField with controller）
- [x] 实现内容输入框（多行 TextField）
- [x] 实现自动保存指示器（"自动保存中..."、"已保存"）
- [x] 实现完成按钮状态（启用/禁用）
- [x] 实现返回确认对话框
- [x] 实现错误 SnackBar（带重试按钮）
- [x] 连接 Provider 到 UI

## 5. 主页集成

- [x] 在 `lib/screens/home_screen.dart` 添加 FAB 按钮
- [x] 实现 FAB 点击事件（导航到 `/create-card`）
- [x] 在 `lib/main.dart` 注册 `/create-card` 路由
- [x] 实现创建完成后返回主页逻辑
- [x] 实现主页列表刷新逻辑
- [x] 更新 `HomeScreenState` 处理新卡片

## 6. API 集成

- [x] 确认 `CardApi.createCard()` 方法存在
- [x] 在 `CardEditorState` 中调用 `CardApi.createCard()`
- [x] 处理 API 成功响应
- [x] 处理 API 错误响应
- [x] 实现重试逻辑

## 7. 性能优化

- [x] 实现 debounce 逻辑（500ms）
- [x] 优化导航过渡动画（< 300ms）
- [x] 添加性能监控日志
- [x] 运行性能测试（确保 < 30 秒）

## 8. 测试验证

- [x] 运行所有单元测试
- [x] 运行所有 widget 测试
- [x] 运行集成测试
- [x] 运行性能测试
- [x] 确保测试覆盖率 > 90%
- [x] 修复所有失败的测试

## 9. 代码质量检查

- [x] 运行 `dart tool/validate_constraints.dart`
- [x] 运行 `dart tool/fix_lint.dart`
- [x] 确保没有 `unwrap()` / `expect()` / `panic!()`
- [x] 确保所有方法返回 `Result<T, Error>`
- [x] 代码审查

## 10. 文档更新

- [x] 更新 `docs/interaction/ui_flows.md`
- [x] 更新 `openspec/specs/README.md`
- [ ] 更新 `docs/design/` 中的相关引用
- [x] 更新规格状态为"已完成"
- [ ] 生成 API 文档

## 11. 集成测试

- [ ] 在真实设备上测试完整流程
- [ ] 测试错误场景（网络断开、API 失败）
- [ ] 测试性能（确保 < 30 秒）
- [ ] 测试边界情况（空标题、超长标题）
- [ ] 测试用户体验（流畅度、反馈及时性）

## 12. 规格同步

- [ ] 使用 `openspec sync` 将 delta spec 同步到主规格
- [ ] 更新 SP-FLUT-008 规格（如有修改）
- [ ] 验证规格一致性

## 13. Change 归档

- [ ] 运行 `openspec verify` 验证实现
- [ ] 运行 `openspec archive` 归档 change
- [ ] 清理临时文件
