# 更新日志

本文档记录 CardMind 的所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 规划中 (v2.0.0)
- P2P 多设备同步（libp2p）
- 设备发现（mDNS）
- 自动冲突解决
- 同步状态管理
- iOS/macOS 支持
- 全文搜索（SQLite FTS5）
- 数据导入/导出

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
**预计**: Phase 5-6 完成后

- [ ] libp2p 集成
- [ ] 设备发现
- [ ] P2P 同步
- [ ] 离线编辑
- [ ] 冲突自动解决

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
