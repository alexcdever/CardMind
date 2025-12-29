# 更新日志

本文档记录 CardMind 的所有重要变更。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 规划中
- MVP 核心功能开发
- 卡片 CRUD 操作
- Loro CRDT 集成
- SQLite 缓存层
- 基础 UI

## [0.1.0] - 2024-XX-XX

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
