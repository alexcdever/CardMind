# Documentation Migration Mapping Table

本文档记录主规格文档重组过程中的所有文件迁移映射关系。

## 迁移映射

| 旧路径 | 新路径 | 迁移类型 | 平台 | 状态 | 备注 |
|--------|--------|----------|------|------|------|
| specs/bilingual-compliance/spec.md | engineering/bilingual_compliance_spec.md | 移动 | N/A | ✅ 已完成 | 工程指南，不应在主规格目录 |
| specs/domain/pool_model.md | specs/domain/pool/model.md | 移动+重构 | N/A | ⏳ 待处理 | 保留领域模型内容 |
| specs/domain/common_types.md | specs/domain/types.md | 移动 | N/A | ⏳ 待处理 | 共享类型定义 |
| specs/domain/card_store.md | specs/domain/card/rules.md | 拆分 | N/A | ⏳ 待处理 | 提取业务规则部分 |
| specs/domain/card_store.md | specs/architecture/storage/card_store.md | 拆分 | N/A | ⏳ 待处理 | 提取技术实现部分 |
| specs/domain/sync_protocol.md | specs/architecture/sync/protocol.md | 移动 | N/A | ⏳ 待处理 | 技术协议文档 |
| specs/domain/device_config.md | specs/architecture/storage/device_config.md | 移动 | N/A | ⏳ 待处理 | 技术实现文档 |
| specs/features/home_screen/home_screen.md | specs/ui/screens/mobile/home_screen.md | 拆分 | mobile | ⏳ 待处理 | 移动端主屏幕 |
| specs/features/home_screen/home_screen.md | specs/ui/screens/desktop/home_screen.md | 拆分 | desktop | ⏳ 待处理 | 桌面端主屏幕 |
| specs/features/card_editor/card_editor_screen.md | specs/ui/screens/mobile/card_editor_screen.md | 拆分 | mobile | ⏳ 待处理 | 移动端编辑器 |
| specs/features/card_editor/card_editor_screen.md | specs/ui/screens/desktop/card_editor_screen.md | 拆分 | desktop | ⏳ 待处理 | 桌面端编辑器 |
| specs/features/card_detail/card_detail_screen.md | specs/ui/screens/mobile/card_detail_screen.md | 移动 | mobile | ⏳ 待处理 | 卡片详情屏幕 |
| specs/features/sync/sync_screen.md | specs/ui/screens/mobile/sync_screen.md | 移动 | mobile | ⏳ 待处理 | 同步屏幕 |
| specs/features/settings/settings_screen.md | specs/ui/screens/mobile/settings_screen.md | 拆分 | mobile | ⏳ 待处理 | 移动端设置 |
| specs/features/settings/settings_screen.md | specs/ui/screens/desktop/settings_screen.md | 拆分 | desktop | ⏳ 待处理 | 桌面端设置 |
| specs/features/onboarding/shared.md | specs/ui/screens/shared/onboarding_screen.md | 移动 | shared | ⏳ 待处理 | 共享引导屏幕 |
| specs/features/card_list/card_list_item.md | specs/ui/components/mobile/card_list_item.md | 拆分 | mobile | ⏳ 待处理 | 移动端卡片列表项 |
| specs/features/card_list/card_list_item.md | specs/ui/components/desktop/card_list_item.md | 拆分 | desktop | ⏳ 待处理 | 桌面端卡片列表项 |
| specs/features/navigation/mobile_nav.md | specs/ui/components/mobile/mobile_nav.md | 移动 | mobile | ⏳ 待处理 | 移动端导航 |
| specs/features/fab/mobile.md | specs/ui/components/mobile/fab.md | 移动 | mobile | ⏳ 待处理 | 移动端浮动按钮 |
| specs/features/gestures/mobile.md | specs/ui/components/mobile/gestures.md | 移动 | mobile | ⏳ 待处理 | 移动端手势 |
| specs/features/toolbar/desktop.md | specs/ui/components/desktop/toolbar.md | 移动 | desktop | ⏳ 待处理 | 桌面端工具栏 |
| specs/features/context_menu/desktop.md | specs/ui/components/desktop/context_menu.md | 移动 | desktop | ⏳ 待处理 | 桌面端右键菜单 |
| specs/features/card_editor/note_card.md | specs/ui/components/shared/note_card.md | 移动 | shared | ⏳ 待处理 | 共享笔记卡片组件 |
| specs/features/card_editor/fullscreen_editor.md | specs/ui/components/shared/fullscreen_editor.md | 移动 | shared | ⏳ 待处理 | 共享全屏编辑器 |
| specs/features/sync_feedback/sync_status_indicator.md | specs/ui/components/shared/sync_status_indicator.md | 移动 | shared | ⏳ 待处理 | 同步状态指示器 |
| specs/features/sync_feedback/sync_details_dialog.md | specs/ui/components/shared/sync_details_dialog.md | 移动 | shared | ⏳ 待处理 | 同步详情对话框 |
| specs/features/settings/device_manager_panel.md | specs/ui/components/shared/device_manager_panel.md | 移动 | shared | ⏳ 待处理 | 设备管理面板 |
| specs/features/settings/settings_panel.md | specs/ui/components/shared/settings_panel.md | 移动 | shared | ⏳ 待处理 | 设置面板 |

## 新建文档

| 新路径 | 类型 | 状态 | 备注 |
|--------|------|------|------|
| specs/domain/sync/model.md | 新建 | ⏳ 待处理 | 同步版本和冲突解决模型 |
| specs/features/card_management/spec.md | 新建 | ⏳ 待处理 | 卡片管理功能规格 |
| specs/features/pool_management/spec.md | 新建 | ⏳ 待处理 | 数据池管理功能规格 |
| specs/features/p2p_sync/spec.md | 新建 | ⏳ 待处理 | P2P 同步功能规格 |
| specs/features/search_and_filter/spec.md | 新建 | ⏳ 待处理 | 搜索和过滤功能规格 |
| specs/features/settings/spec.md | 新建 | ⏳ 待处理 | 设置功能规格 |
| specs/architecture/storage/dual_layer.md | 新建 | ⏳ 待处理 | 双层架构文档 |
| specs/architecture/storage/pool_store.md | 新建 | ⏳ 待处理 | PoolStore 实现 |
| specs/architecture/storage/sqlite_cache.md | 新建 | ⏳ 待处理 | SQLite 缓存实现 |
| specs/architecture/sync/mdns_discovery.md | 新建 | ⏳ 待处理 | mDNS 设备发现 |
| specs/architecture/sync/conflict_resolution.md | 新建 | ⏳ 待处理 | CRDT 冲突解决 |
| specs/architecture/security/password.md | 新建 | ✅ 已完成 | bcrypt 密码管理 |
| specs/architecture/security/keyring.md | 新建 | ✅ 已完成 | Keyring 存储 |
| specs/architecture/security/privacy.md | 新建 | ✅ 已完成 | mDNS 隐私保护 |
| specs/architecture/bridge/flutter_rust_bridge.md | 新建 | ✅ 已完成 | Flutter-Rust 桥接 |
| specs/ui/components/desktop/desktop_nav.md | 新建 | ⏳ 待处理 | 桌面端导航 |
| specs/ui/adaptive/layouts.md | 新建 | ⏳ 待处理 | 自适应布局系统 |
| specs/ui/adaptive/components.md | 新建 | ⏳ 待处理 | 自适应组件 |
| specs/ui/adaptive/platform_detection.md | 新建 | ⏳ 待处理 | 平台检测逻辑 |

## 特殊问题记录

### bilingual-compliance 位置问题

**问题描述**：
- `specs/bilingual-compliance/spec.md` 是工程指南性质的文档，不应该出现在主规格目录
- 该文档由 OpenSpec 变更 `bilingual-spec-compliance` 归档时错误地同步到主规格目录（提交 38d86a4）

**根本原因**：
- OpenSpec 的 `archive` 流程会将变更中的 `specs/` 目录内容同步到主规格目录
- 变更中创建了工程指南类文档，但放在了 `specs/` 目录下

**解决方案**：
- 将文档迁移到 `engineering/bilingual_compliance_spec.md`
- 删除 `specs/bilingual-compliance/` 目录
- 更新 OpenSpec 工作流文档，明确变更的 `specs/` 目录仅用于业务规格

**预防措施**：
- 在 OpenSpec 工作流文档中添加指导原则
- 开发验证脚本，检查归档的文档是否符合业务规格特征

## 迁移统计

- **总文档数**: 39 个现有文档
- **需要迁移**: 29 个
- **需要拆分**: 10 个
- **需要新建**: 19 个
- **需要删除**: 0 个（保留重定向）

## 状态说明

- ⏳ 待处理
- 🔄 进行中
- ✅ 已完成
- ❌ 失败
- ⚠️ 需要注意

---

**最后更新**: 2026-01-23
**维护者**: CardMind Team
