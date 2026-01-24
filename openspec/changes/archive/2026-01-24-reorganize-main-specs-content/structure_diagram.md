# Documentation Structure Diagram
# 文档结构图

**Version**: 1.0.0
**版本**: 1.0.0

**Date**: 2026-01-24
**日期**: 2026-01-24

---

## Overview
## 概述

This document provides visual diagrams of the reorganized specification structure in the CardMind project.

本文档提供 CardMind 项目中重组后规格结构的可视化图表。

---

## Four-Layer Architecture
## 四层架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        CardMind Specs                            │
│                     openspec/specs/                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐      ┌──────────────┐     ┌──────────────┐
│   Domain     │      │   Features   │     │      UI      │
│   Layer      │      │    Layer     │     │    Layer     │
│              │      │              │     │              │
│ Business     │      │ User-facing  │     │ Components   │
│ Rules &      │      │ Features &   │     │ Screens &    │
│ Models       │      │ Workflows    │     │ Layouts      │
└──────────────┘      └──────────────┘     └──────────────┘
        │                     │                     │
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                              ▼
                      ┌──────────────┐
                      │Architecture  │
                      │    Layer     │
                      │              │
                      │ Technical    │
                      │Implementation│
                      └──────────────┘
```

---

## Complete Directory Tree
## 完整目录树

```
openspec/specs/
│
├── domain/                          # Business rules and domain models
│   │                                # 业务规则和领域模型
│   ├── README.md                    # Domain layer guide
│   │                                # 领域层指南
│   ├── types.md                     # Shared domain types (UUID, timestamps)
│   │                                # 共享领域类型（UUID、时间戳）
│   │
│   ├── card/                        # Card entity
│   │   │                            # 卡片实体
│   │   ├── model.md                 # Card entity definition
│   │   │                            # 卡片实体定义
│   │   └── rules.md                 # Card business rules
│   │                                # 卡片业务规则
│   │
│   ├── pool/                        # Pool entity
│   │   │                            # 池实体
│   │   └── model.md                 # Pool ownership model
│   │                                # 池所有权模型
│   │
│   └── sync/                        # Sync domain
│       │                            # 同步领域
│       └── model.md                 # Sync version & conflict model
│                                    # 同步版本和冲突模型
│
├── features/                        # User-facing features
│   │                                # 面向用户的功能
│   ├── README.md                    # Features layer guide
│   │                                # 功能层指南
│   │
│   ├── card_management/             # Card CRUD operations
│   │   │                            # 卡片 CRUD 操作
│   │   └── spec.md                  # Create, edit, delete cards
│   │                                # 创建、编辑、删除卡片
│   │
│   ├── pool_management/             # Pool operations
│   │   │                            # 池操作
│   │   └── spec.md                  # Create, join, leave pools
│   │                                # 创建、加入、离开池
│   │
│   ├── p2p_sync/                    # P2P synchronization
│   │   │                            # P2P 同步
│   │   └── spec.md                  # Peer discovery & sync
│   │                                # 对等发现和同步
│   │
│   ├── search_and_filter/           # Search functionality
│   │   │                            # 搜索功能
│   │   └── spec.md                  # Search & filter cards
│   │                                # 搜索和过滤卡片
│   │
│   └── settings/                    # Settings management
│       │                            # 设置管理
│       └── spec.md                  # App settings & preferences
│                                    # 应用设置和偏好
│
├── ui/                              # UI components and screens
│   │                                # UI 组件和屏幕
│   ├── README.md                    # UI layer guide
│   │                                # UI 层指南
│   │
│   ├── screens/                     # Screen specifications
│   │   │                            # 屏幕规格
│   │   ├── mobile/                  # Mobile screens
│   │   │   │                        # 移动端屏幕
│   │   │   ├── home_screen.md       # Mobile home (bottom nav)
│   │   │   │                        # 移动端主屏幕（底部导航）
│   │   │   ├── card_editor_screen.md # Mobile editor (full-screen)
│   │   │   │                        # 移动端编辑器（全屏）
│   │   │   ├── card_detail_screen.md # Card detail view
│   │   │   │                        # 卡片详情视图
│   │   │   ├── sync_screen.md       # Sync management
│   │   │   │                        # 同步管理
│   │   │   └── settings_screen.md   # Mobile settings
│   │   │                            # 移动端设置
│   │   │
│   │   ├── desktop/                 # Desktop screens
│   │   │   │                        # 桌面端屏幕
│   │   │   ├── home_screen.md       # Desktop home (3-column)
│   │   │   │                        # 桌面端主屏幕（三栏）
│   │   │   ├── card_editor_screen.md # Desktop editor (inline)
│   │   │   │                        # 桌面端编辑器（内联）
│   │   │   └── settings_screen.md   # Desktop settings
│   │   │                            # 桌面端设置
│   │   │
│   │   └── shared/                  # Platform-agnostic screens
│   │       │                        # 平台无关屏幕
│   │       └── onboarding_screen.md # Onboarding flow
│   │                                # 引导流程
│   │
│   ├── components/                  # Component specifications
│   │   │                            # 组件规格
│   │   ├── mobile/                  # Mobile components
│   │   │   │                        # 移动端组件
│   │   │   ├── card_list_item.md    # Mobile list item
│   │   │   │                        # 移动端列表项
│   │   │   ├── mobile_nav.md        # Bottom navigation
│   │   │   │                        # 底部导航
│   │   │   ├── fab.md               # Floating action button
│   │   │   │                        # 浮动操作按钮
│   │   │   └── gestures.md          # Touch gestures
│   │   │                            # 触摸手势
│   │   │
│   │   ├── desktop/                 # Desktop components
│   │   │   │                        # 桌面端组件
│   │   │   ├── card_list_item.md    # Desktop list item
│   │   │   │                        # 桌面端列表项
│   │   │   ├── desktop_nav.md       # Side navigation
│   │   │   │                        # 侧边导航
│   │   │   ├── toolbar.md           # Top toolbar
│   │   │   │                        # 顶部工具栏
│   │   │   └── context_menu.md      # Right-click menu
│   │   │                            # 右键菜单
│   │   │
│   │   └── shared/                  # Shared components
│   │       │                        # 共享组件
│   │       ├── note_card.md         # Note card component
│   │       │                        # 笔记卡片组件
│   │       ├── fullscreen_editor.md # Full-screen editor
│   │       │                        # 全屏编辑器
│   │       ├── sync_status_indicator.md # Sync status
│   │       │                        # 同步状态
│   │       ├── sync_details_dialog.md # Sync details
│   │       │                        # 同步详情
│   │       ├── device_manager_panel.md # Device manager
│   │       │                        # 设备管理器
│   │       └── settings_panel.md    # Settings panel
│   │                                # 设置面板
│   │
│   └── adaptive/                    # Adaptive layout system
│       │                            # 自适应布局系统
│       ├── layouts.md               # Responsive layouts
│       │                            # 响应式布局
│       ├── components.md            # Adaptive components
│       │                            # 自适应组件
│       └── platform_detection.md    # Platform detection
│                                    # 平台检测
│
└── architecture/                    # Technical implementation
    │                                # 技术实现
    ├── README.md                    # Architecture layer guide
    │                                # 架构层指南
    │
    ├── storage/                     # Storage layer
    │   │                            # 存储层
    │   ├── dual_layer.md            # Loro + SQLite architecture
    │   │                            # Loro + SQLite 架构
    │   ├── card_store.md            # CardStore implementation
    │   │                            # CardStore 实现
    │   ├── pool_store.md            # PoolStore implementation
    │   │                            # PoolStore 实现
    │   ├── device_config.md         # DeviceConfig storage
    │   │                            # DeviceConfig 存储
    │   ├── sqlite_cache.md          # SQLite caching layer
    │   │                            # SQLite 缓存层
    │   └── loro_integration.md      # Loro CRDT integration
    │                                # Loro CRDT 集成
    │
    ├── sync/                        # Sync service
    │   │                            # 同步服务
    │   ├── service.md               # Sync service architecture
    │   │                            # 同步服务架构
    │   ├── peer_discovery.md        # mDNS peer discovery
    │   │                            # mDNS 对等发现
    │   ├── conflict_resolution.md   # CRDT conflict resolution
    │   │                            # CRDT 冲突解决
    │   └── subscription.md          # Loro subscription mechanism
    │                                # Loro 订阅机制
    │
    ├── security/                    # Security implementations
    │   │                            # 安全实现
    │   ├── password.md              # bcrypt password hashing
    │   │                            # bcrypt 密码哈希
    │   ├── keyring.md               # Keyring storage
    │   │                            # Keyring 存储
    │   └── privacy.md               # mDNS privacy protection
    │                                # mDNS 隐私保护
    │
    └── bridge/                      # Platform bridges
        │                            # 平台桥接
        └── flutter_rust_bridge.md   # Flutter-Rust integration
                                     # Flutter-Rust 集成
```

---

## Layer Relationships
## 层次关系

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Perspective                         │
│                           用户视角                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │    Features      │ ◄─── User workflows
                    │    功能层         │      用户工作流
                    └──────────────────┘
                         │         │
                         │         │
            ┌────────────┘         └────────────┐
            ▼                                   ▼
    ┌──────────────┐                   ┌──────────────┐
    │   Domain     │                   │      UI      │
    │   领域层      │                   │    UI 层     │
    └──────────────┘                   └──────────────┘
            │                                   │
            │  Business rules                   │  Visual design
            │  业务规则                          │  视觉设计
            │                                   │
            └────────────┐         ┌────────────┘
                         │         │
                         ▼         ▼
                    ┌──────────────────┐
                    │  Architecture    │ ◄─── Technical impl
                    │    架构层         │      技术实现
                    └──────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      System Implementation                       │
│                          系统实现                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Information Flow
## 信息流

```
User Story / Requirement
用户故事 / 需求
         │
         ▼
┌─────────────────┐
│   Features      │  What users can do
│   功能层         │  用户能做什么
└─────────────────┘
         │
         ├──────────────────┐
         │                  │
         ▼                  ▼
┌─────────────┐    ┌─────────────┐
│   Domain    │    │     UI      │
│   领域层     │    │   UI 层     │
│             │    │             │
│ Business    │    │ How it      │
│ rules       │    │ looks       │
│ 业务规则     │    │ 外观        │
└─────────────┘    └─────────────┘
         │                  │
         └──────┬───────────┘
                │
                ▼
        ┌─────────────┐
        │Architecture │
        │  架构层      │
        │             │
        │ How it's    │
        │ built       │
        │ 如何构建     │
        └─────────────┘
                │
                ▼
        Implementation
        实现
```

---

## Platform Separation (UI Layer)
## 平台分离（UI 层）

```
                    ┌──────────────┐
                    │  UI Layer    │
                    │  UI 层       │
                    └──────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Mobile     │  │   Desktop    │  │   Shared     │
│   移动端      │  │   桌面端      │  │   共享       │
└──────────────┘  └──────────────┘  └──────────────┘
        │                 │                 │
        │                 │                 │
        ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Bottom nav   │  │ Side nav     │  │ Platform-    │
│ Full-screen  │  │ 3-column     │  │ agnostic     │
│ Gestures     │  │ Inline edit  │  │ components   │
│ FAB          │  │ Context menu │  │              │
│              │  │              │  │              │
│ 底部导航      │  │ 侧边导航      │  │ 平台无关      │
│ 全屏         │  │ 三栏         │  │ 组件         │
│ 手势         │  │ 内联编辑      │  │              │
│ 浮动按钮      │  │ 右键菜单      │  │              │
└──────────────┘  └──────────────┘  └──────────────┘
```

---

## Document Type Distribution
## 文档类型分布

```
Layer          │ Document Types              │ Count
层次           │ 文档类型                     │ 数量
───────────────┼─────────────────────────────┼──────
Domain         │ Entity models               │   3
领域层          │ Business rules              │   4
               │ Domain types                │   1
               │                             │ Total: 8
───────────────┼─────────────────────────────┼──────
Features       │ Feature specifications      │   5
功能层          │ User workflows              │
               │                             │ Total: 5
───────────────┼─────────────────────────────┼──────
UI             │ Screen specs                │   9
UI 层          │ Component specs             │  14
               │ Adaptive system             │   3
               │                             │ Total: 26
───────────────┼─────────────────────────────┼──────
Architecture   │ Storage implementations     │   6
架构层          │ Sync service                │   4
               │ Security                    │   3
               │ Bridge                      │   1
               │                             │ Total: 14
───────────────┴─────────────────────────────┴──────
                                      Grand Total: 53
```

---

## Migration Summary
## 迁移摘要

```
Before Reorganization          After Reorganization
重组前                          重组后

specs/                         specs/
├── domain/                    ├── domain/        (8 docs)
│   ├── pool_model.md          │   ├── card/
│   ├── card_store.md          │   ├── pool/
│   ├── sync_protocol.md       │   └── sync/
│   ├── device_config.md       │
│   └── common_types.md        ├── features/      (5 docs)
│                              │   ├── card_management/
├── features/                  │   ├── pool_management/
│   ├── card_editor/           │   ├── p2p_sync/
│   ├── card_detail/           │   ├── search_and_filter/
│   ├── card_list/             │   └── settings/
│   ├── home_screen/           │
│   ├── settings/              ├── ui/            (26 docs)
│   ├── sync/                  │   ├── screens/
│   └── sync_feedback/         │   │   ├── mobile/
│                              │   │   ├── desktop/
└── api/                       │   │   └── shared/
                               │   ├── components/
                               │   │   ├── mobile/
                               │   │   ├── desktop/
                               │   │   └── shared/
                               │   └── adaptive/
                               │
                               ├── architecture/  (14 docs)
                               │   ├── storage/
                               │   ├── sync/
                               │   ├── security/
                               │   └── bridge/
                               │
                               └── api/           (unchanged)

Flat structure                 Layered structure
扁平结构                        分层结构

Mixed concerns                 Separated concerns
混合关注点                      分离关注点

~30 documents                  53 documents
约 30 个文档                    53 个文档
```

---

## Key Benefits
## 关键优势

```
┌─────────────────────────────────────────────────────────────────┐
│                         Benefits                                 │
│                         优势                                      │
└─────────────────────────────────────────────────────────────────┘

1. Clear Separation of Concerns
   清晰的关注点分离

   Business rules ≠ Technical implementation ≠ UI design
   业务规则 ≠ 技术实现 ≠ UI 设计

2. Easier Navigation
   更容易导航

   Know which layer to look in based on your question
   根据问题知道查看哪一层

3. Independent Evolution
   独立演进

   Change UI without affecting business rules
   改变 UI 而不影响业务规则

   Refactor architecture without changing requirements
   重构架构而不改变需求

4. Platform-Specific Clarity
   平台特定清晰度

   Mobile vs Desktop UI patterns clearly separated
   移动端与桌面端 UI 模式清晰分离

5. Better Maintainability
   更好的可维护性

   Find and update related documents easily
   轻松查找和更新相关文档
```

---

## Related Documents
## 相关文档

**Migration guides**:
**迁移指南**：
- [migration_guide.md](migration_guide.md) - Complete migration guide
- [migration_guide.md](migration_guide.md) - 完整迁移指南
- [migration_map.md](migration_map.md) - File mapping table
- [migration_map.md](migration_map.md) - 文件映射表

**Layer guides**:
**层次指南**：
- [../../specs/domain/README.md](../../specs/domain/README.md) - Domain layer
- [../../specs/features/README.md](../../specs/features/README.md) - Features layer
- [../../specs/ui/README.md](../../specs/ui/README.md) - UI layer
- [../../specs/architecture/README.md](../../specs/architecture/README.md) - Architecture layer

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Maintainers**: CardMind Team
**维护者**: CardMind Team
