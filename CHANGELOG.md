# 更新日志

本文档记录 CardMind 的所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 新增 - 同步状态UI完整实现 (2026-01-29)

#### 核心功能
- **同步状态指示器** - 桌面端AppBar中的实时同步状态显示
  - 4种状态：未同步、同步中、已同步、失败
  - 旋转动画（同步中状态，360°/2秒）
  - 相对时间显示（10秒阈值）
  - Badge样式设计，符合Material Design规范

- **同步详情对话框** - 完整的同步信息展示
  - 当前同步状态和描述
  - 设备列表显示（在线/离线/同步中状态）
  - 统计信息（已同步卡片数、数据大小、成功/失败次数）
  - 同步历史记录（时间戳、状态、设备信息）
  - 实时更新（每5秒自动刷新）
  - 错误信息显示和重试功能

#### 后端API
- **设备管理API** (`rust/src/api/sync.rs`)
  - `get_device_list()` - 获取已发现的设备列表
  - `DeviceInfo` 数据结构（设备ID、名称、状态、最后可见时间）
  - `DeviceConnectionStatus` 枚举（Online/Offline/Syncing）

- **统计信息API**
  - `get_sync_statistics()` - 获取同步统计数据
  - `SyncStatistics` 数据结构（卡片数、数据大小、成功/失败次数）

- **同步历史API**
  - `get_sync_history()` - 获取同步历史记录
  - `SyncHistoryEvent` 数据结构（时间戳、状态、设备信息、错误消息）

#### 测试覆盖
- **单元测试** - 11个测试用例（`test/models/sync_status_test.dart`）
  - 工厂构造函数测试
  - 状态一致性验证
  - 相等性和哈希码测试

- **Widget测试** - 20个测试用例
  - SyncStatusIndicator测试（10个）
  - SyncDetailsDialog测试（10个）

- **性能测试** - 8个测试用例（`test/performance/sync_status_performance_test.dart`）
  - 渲染性能（< 16ms）
  - 动画性能（60 FPS）
  - 内存使用测试

- **无障碍测试** - 15个测试用例（`test/widgets/sync_details_dialog_accessibility_test.dart`）
  - 语义标签测试
  - 键盘导航测试
  - 屏幕阅读器支持

#### 文档
- **设计文档** (`openspec/changes/sync-status-ui-design/design.md`)
  - 完整的视觉规范和状态映射表
  - 动画参数和性能优化策略
  - 无障碍支持说明

- **测试规格** (`openspec/changes/sync-status-ui-design/specs/testing/spec.md`)
  - 详细的测试用例定义
  - 测试覆盖率要求

- **完成报告** (`openspec/changes/sync-status-ui-design/COMPLETION_REPORT.md`)
  - 100%任务完成度（33/33）
  - 54个测试全部通过

#### 技术改进
- **Stream-based架构** - 从ChangeNotifier迁移到Stream
  - Stream.distinct()去重
  - 300ms防抖机制
  - syncing→synced立即更新优化

- **资源管理** - 完善的生命周期管理
  - 定时器自动清理
  - 动画控制器释放
  - Stream订阅取消

### 新增 - 完整测试覆盖 (2026-01-19)

#### 测试基础设施
- **测试覆盖率大幅提升** - 从 80 个测试提升到 579 个通过测试
  - 规格测试（Spec Tests）：覆盖所有 19 个功能规格
  - Widget 测试：完整的组件单元测试
  - Screen 测试：响应式布局和导航测试
  - 集成测试：端到端用户旅程测试
  - 测试成功率：92.5% (579 通过 / 47 失败)

#### CI/CD 自动化
- **GitHub Actions 工作流** (`.github/workflows/flutter_tests.yml`)
  - 自动运行所有测试套件
  - 生成测试覆盖率报告
  - 集成 Codecov 覆盖率上传
  - 验证测试-规格映射
  - 验证项目约束

#### 测试工具和辅助
- **Mock 服务** (`test/helpers/mock_card_service.dart`)
  - 完整的 CardService Mock 实现
  - 支持延迟模拟、错误注入
  - 调用计数跟踪
- **测试辅助工具** (`test/helpers/test_helpers.dart`)
  - 屏幕尺寸设置
  - 平台模拟
  - 测试 Widget 创建

#### 代码质量改进
- **代码格式化** - 所有测试文件格式化（38 个文件）
- **代码质量修复** - 自动修复 69 个代码质量问题
  - Import 排序优化
  - Const 构造函数优化
  - Lambda 表达式简化
  - 未使用变量清理

#### 文档完善
- **测试指南** (`docs/testing/TESTING_GUIDE.md`)
  - 完整的测试编写指南
  - Spec Coding 方法论说明
  - 测试类型和最佳实践
  - 常见问题解答
- **README 更新** - 添加测试相关章节

### 修复
- **测试稳定性修复** - 修复 7 个关键测试问题
  - fullscreen_editor_test.dart - 多个 close 图标定位
  - adaptive_ui_system_spec_test.dart - 性能测试时间限制
  - responsive_layout_spec_test.dart - 卡片宽度断言
  - sync_status_indicator_component_spec_test.dart - pumpAndSettle 超时
  - home_screen_ui_spec_test.dart - Mock sync stream 和数据加载

### 规划中 (v2.0.0+)
- iOS/macOS 支持
- 全文搜索（SQLite FTS5）
- 数据导入/导出
- libp2p 消息传输协议完整实现

## [1.1.0] - 2026-01-05

### 新增 - Phase 6: P2P 同步实现完成 🎉

#### P2P 同步核心功能
- **P2P 同步服务** (`P2PSyncService`) - 完整的点对点同步服务
  - 整合网络层、发现层、同步管理器和多设备协调器
  - 支持服务启动、设备连接、同步请求和响应处理
  - 自动同步和状态跟踪
  - 2 个单元测试通过

- **同步 API 层** (`api/sync.rs`) - Flutter 桥接 API
  - Thread-local 存储模式，解决 SQLite 线程安全问题
  - 5 个公开 API 函数：初始化、手动同步、状态查询、Peer ID 获取、清理
  - 2 个单元测试通过

- **Flutter 同步状态管理** (`SyncProvider`)
  - 完整的同步状态管理（在线/同步中/离线设备数）
  - 支持初始化、状态刷新、手动同步
  - 完整的加载状态和错误处理
  - 0 个 Flutter 错误

- **P2P 同步界面** (`sync_screen.dart`)
  - 同步状态卡片（显示设备统计）
  - 设备信息卡片（Peer ID 显示和复制）
  - 手动同步功能（输入 Pool ID 触发同步）
  - RefreshIndicator 支持下拉刷新
  - 完整的错误处理和空状态
  - 300+ 行，0 个 Flutter 错误

#### 数据池和设备管理
- **数据池 Store 层** - Loro + SQLite 双层存储
  - 9 个测试通过
  - 支持 CRUD 操作、成员管理、密码验证

- **设备配置管理** (`DeviceConfig`)
  - 17 个测试通过
  - 支持加入/离开数据池、常驻池管理
  - config.json 文件持久化
  - UUID v7 自动生成

- **密码安全**
  - 19 个测试通过
  - bcrypt 密码哈希（工作因子 12）
  - Keyring 跨平台密码存储
  - Zeroizing 自动内存清零

- **卡片-数据池绑定机制**
  - 5 个绑定方法（添加、移除、查询、清除）
  - 常驻池自动绑定
  - 完整的 Loro + SQLite 双层同步

#### 同步协议和管理
- **同步协议** (`sync.rs`)
  - 4 种消息类型：SyncRequest、SyncResponse、SyncAck、SyncError
  - 数据池过滤器（基于 pool_ids 交集）
  - 4 个单元测试通过

- **同步管理器** (`SyncManager`)
  - Loro 增量同步导出/导入
  - 版本跟踪（pool_id -> peer_id -> version）
  - 授权验证（检查设备是否加入数据池）
  - 5 个单元测试通过

- **多设备协调器** (`MultiPeerSyncCoordinator`)
  - 设备状态跟踪（在线/离线/同步中）
  - 并行同步支持
  - 版本管理和冲突避免
  - 6 个单元测试通过

#### 集成测试
- **端到端集成测试** (`sync_integration_test.rs`)
  - 7 个测试场景全部通过：
    - 服务初始化测试
    - 两设备同步流程测试
    - 同步状态跟踪测试
    - 服务启动和监听测试
    - 并发设备连接测试
    - 同步请求处理测试
  - 200+ 行测试代码

#### 测试覆盖
- **总测试数**: 119 个单元测试 + 7 个集成测试
- **测试通过率**: 100%
- **新增测试**: 47 个（Phase 6）

#### 技术栈更新
- **新增 Rust 依赖**:
  - libp2p: 0.54 - P2P 网络协议栈
  - libp2p-noise: TLS 加密（Noise 协议）
  - libp2p-mdns: mDNS 设备发现
  - bcrypt: 0.16 - 密码哈希
  - keyring: 3.8 - 跨平台密码存储
  - zeroize: 1.9 - 敏感数据内存清零
  - tokio: 1.x - 异步运行时

### 已知限制
- libp2p 消息传输协议（request_response/gossipsub）尚未完整实现
- 当前版本主要验证了核心组件的集成和可行性
- 实际的端到端设备间同步需要完整的 libp2p 协议栈

## [1.0.0] - 2025-12-31

### 新增 - MVP 正式发布 🎉

#### 核心功能
- **卡片管理**: 完整的 CRUD 操作（创建、读取、更新、删除）
- **Markdown 支持**: 完整的 Markdown 语法支持和实时渲染
- **实时预览**: 编辑器中可切换编辑/预览模式
- **卡片详情**: 查看完整渲染的 Markdown 内容

#### 数据架构
- **Loro CRDT 引擎**: 每张卡片独立的 LoroDoc 文件，为未来 P2P 同步做好准备
- **SQLite 缓存层**: 高性能查询优化，通过 Loro 订阅自动同步
- **UUID v7**: 时间排序的唯一 ID 生成

#### UI/UX
- **主题系统**: 浅色/深色主题，自动保存偏好
- **响应式设计**: 手机/平板/桌面自适应布局（单列/双列/三列）
- **设置页面**: 主题切换、关于对话框、版本信息
- **用户反馈**: 加载指示器、操作提示、错误提示、确认对话框

#### 平台支持
- Windows 10/11 (x64)
- Android 5.0+ (ARM/ARM64)

#### 性能优化
- 1000 张卡片加载 < 350ms
- Loro 操作: 创建 ~2.7ms, 更新 ~4.6ms, 删除 ~2.2ms
- SQLite 查询: < 4ms（1000 张卡片）

#### 测试
- 80 个自动化测试（单元 + 集成 + 文档）
- 100% 测试通过率
- 测试覆盖率 >85%
- 专门的性能测试套件

#### 文档
- [用户使用手册](docs/USER_GUIDE.md)
- [技术架构文档](docs/ARCHITECTURE.md)
- [数据库设计文档](docs/DATABASE.md)
- [API 设计文档](docs/API_DESIGN.md)
- [测试指南](docs/TESTING_GUIDE.md)

### 技术栈

#### Rust 依赖
- loro: 1.3.1 - CRDT engine
- rusqlite: 0.33.0 - SQLite database
- flutter_rust_bridge: 2.7.0 - Dart-Rust bridging
- uuid: 1.11.0 - UUID v7 generation
- serde/serde_json: 1.0 - Serialization
- thiserror: 2.0, anyhow: 1.0 - Error handling
- chrono: 0.4 - Time handling
- tracing: 0.1 - Logging
- serial_test: 3.2 - Test serialization

#### Flutter 依赖
- flutter_rust_bridge: 2.11.0 - Dart-Rust bridging
- provider: 6.1.0 - State management
- flutter_markdown: 0.7.0 - Markdown rendering
- path_provider: 2.1.0 - Path utilities
- shared_preferences: 2.2.0 - Local storage
- package_info_plus: 8.0.0 - App info

### 已知限制
- 暂不支持多设备同步（计划在 v2.0.0）
- 暂不支持数据导入/导出
- 暂不支持全文搜索
- 删除操作不可撤销

## [0.1.0] - 2025-12-30

### 新增
- 项目初始化
- 完整的文档体系
  - 产品需求文档 (PRD)
  - 技术架构设计 (ARCHITECTURE)
  - 数据库设计 (DATABASE)
  - API 接口定义 (API)
  - TDD 测试指南 (TESTING_GUIDE)
  - 日志规范 (LOGGING)
  - 开发路线图 (ROADMAP)
  - 环境搭建指南 (SETUP)
  - 常见问题解答 (FAQ)
  - 贡献指南 (CONTRIBUTING)
- 跨平台桥接代码生成脚本 (tool/generate_bridge.dart)
- Git 工作流和提交规范
- 代码静态分析配置 (analysis_options.yaml)

### 技术栈确定
- 前端: Flutter 3.x
- 后端: Rust
- CRDT: Loro
- 数据库: SQLite (缓存层)
- 桥接: flutter_rust_bridge 2.0
- ID: UUID v7

---

## 版本说明

### 版本号格式: MAJOR.MINOR.PATCH

- **MAJOR**: 不兼容的 API 变更
- **MINOR**: 向后兼容的功能新增
- **PATCH**: 向后兼容的问题修正

### 变更类型

- `新增` - 新功能
- `变更` - 现有功能的变化
- `废弃` - 即将移除的功能
- `移除` - 已移除的功能
- `修复` - Bug 修复
- `安全` - 安全相关的修复

---

## 里程碑计划

### v1.0.0 - MVP 版本
**预计**: Phase 1-4 完成后

- [x] 项目初始化
- [ ] 卡片 CRUD
- [ ] Markdown 支持
- [ ] Loro CRDT 本地存储
- [ ] SQLite 缓存层
- [ ] 基础 UI/UX

### v2.0.0 - P2P 同步版本
**进展**: Phase 5-6 已完成 ✅

- [x] libp2p 集成 ✅
- [x] 设备发现（mDNS）✅
- [x] P2P 同步协议和管理器 ✅
- [x] 多设备协调 ✅
- [x] 数据池和设备配置 ✅
- [x] 同步 API 和 UI ✅
- [ ] libp2p 消息传输协议完整实现
- [ ] 端到端设备间实际同步测试
- [ ] 离线编辑场景测试
- [ ] 冲突自动解决验证

### v2.1.0 - 搜索和标签
**预计**: Phase 7-8 完成后

- [ ] 全文搜索
- [ ] 标签系统

### v2.2.0 - 完整版本
**预计**: Phase 9 完成后

- [ ] 数据导入导出
- [ ] 自动备份

---

## 维护说明

### 如何更新此文件

1. **每次提交重要变更时**，在 `[Unreleased]` 下添加条目
2. **发布新版本时**：
   - 将 `[Unreleased]` 内容移到新版本号下
   - 添加发布日期
   - 创建新的 `[Unreleased]` 部分

### 示例

```markdown
## [Unreleased]

### 新增
- 新功能 1
- 新功能 2

### 修复
- Bug 修复

## [1.0.1] - 2024-02-15

### 修复
- 修复卡片删除后 SQLite 未更新的问题

## [1.0.0] - 2024-02-01

### 新增
- 首次发布
- 卡片 CRUD 功能
```

---

[Unreleased]: https://github.com/YOUR_USERNAME/CardMind/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/YOUR_USERNAME/CardMind/releases/tag/v0.1.0
