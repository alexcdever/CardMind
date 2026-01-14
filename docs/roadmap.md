# CardMind 产品路线图

**最后更新**: 2026-01-14

---

## 📍 战略目标

CardMind 致力于打造一款**离线优先、可靠同步、灵活组织**的卡片式笔记应用。通过 CRDT 技术和 P2P 同步，为用户提供去中心化的知识管理解决方案。

---

## 🎯 里程碑规划

### v1.0.0 - MVP 基础版本 ✅

**目标**: 验证核心价值，实现本地卡片管理

**完成时间**: 2025-12-31

**核心功能**:
- ✅ 卡片 CRUD（创建、读取、更新、删除）
- ✅ Markdown 编辑和预览
- ✅ Loro CRDT 本地存储
- ✅ SQLite 缓存层（订阅驱动同步）
- ✅ 深色/浅色主题
- ✅ 响应式设计（手机/平板/桌面）
- ✅ 多平台支持（Android、Windows）

**性能指标**:
- ✅ 1000 张卡片加载 < 1 秒（实际 329ms）
- ✅ Loro 操作 < 50ms（实际 < 5ms）
- ✅ SQLite 查询 < 10ms（实际 < 4ms）
- ✅ 测试覆盖率 > 80%（实际 >85%）

**交付成果**:
- ✅ Android APK (48.6MB)
- ✅ Windows 可执行文件
- ✅ 完整的用户手册和开发文档
- ✅ 80 个自动化测试

---

### v2.0.0 - P2P 同步版本 🔄

**目标**: 实现去中心化的多设备同步（单数据池架构）

**预计完成**: 2026-01 ~ 2026-02

**核心功能**:
- [x] libp2p P2P 网络集成
- [x] 本地网络设备发现（mDNS）
- [x] **数据池密码验证机制（bcrypt 哈希）**
- [x] **密码安全存储（系统 Keyring）**
- [ ] **单数据池模型实施 + Spec Coding 方法论**（每用户一个笔记空间）
  - [ ] Pool 持有 card_ids（解决移除操作传播问题）
  - [ ] DeviceConfig 单池约束
  - [ ] 自动加入池逻辑
  - [ ] 规格文档完整覆盖
- [ ] **初始化流程重构**（首次启动 vs 设备配对）
- [ ] **数据池隔离和同步过滤**（简化版）
- [x] 多点对多点同步（支持 3+ 设备）
- [x] 离线编辑和自动冲突解决
- [x] 同步状态可视化
- [ ] NAT 穿透支持（AutoNAT + Relay + DCUtR）

**技术里程碑**:
- Phase 5: P2P 同步准备（技术调研和原型验证）✅
  - [x] Loro 同步能力验证（6 个测试通过）
  - [x] P2P 同步设计文档
  - [x] libp2p 原型验证
- Phase 6: P2P 同步实现（Phase 6 已完成，需重构到单池模型）✅
  - [x] 密码管理（bcrypt 哈希 + Keyring 存储）
  - [x] mDNS 广播数据池信息
  - [x] libp2p 集成和测试
  - [x] 单对单同步协议
  - [x] 多点对多点同步
  - [x] 前端同步状态显示
- Phase 6R: 单池模型重构 + Spec Coding 转型 🔄
  - [ ] **Spec Coding 方法论实施**
    - [ ] 建立 specs/ 目录结构
    - [ ] 编写核心规格文档（Pool, DeviceConfig, CardStore, UI）
    - [ ] 创建可运行的业务示例
    - [ ] 重命名测试为 spec 风格（it_should_xxx）
  - [ ] **单池模型重构**
    - [ ] Pool.card_ids 替代 Card.pool_ids（真理源）
    - [ ] DeviceConfig 单池约束（pool_id: Option）
    - [ ] 自动加入池逻辑
    - [ ] 初始化流程实现（首次启动 vs 设备配对）
    - [ ] Flutter UI 术语统一（数据池→笔记空间）
    - [ ] 数据迁移脚本（处理多池用户数据）

**性能目标**:
- 设备发现 < 5 秒
- 同步启动 < 2 秒
- 增量同步 < 1 秒（1000 张卡片）
- 并发同步支持 10+ 设备

**验收标准**:
- **数据池隔离 100% 有效**（局域网内不同用户数据不互串）
- **密码验证成功率 100%**（未授权设备无法访问）
- **单池模型正常工作**（每设备只能加入一个笔记空间）
- **移除操作可靠传播**（所有设备同步移除事件）
- 能在多设备间可靠同步（3+ 设备）
- 支持离线编辑和自动合并
- 冲突自动解决（Loro CRDT 保证）
- 数据不丢失（100% 保证）
- **数据迁移成功率 100%**（处理多池用户数据）
- 测试覆盖率 > 80%

---

### v2.1.0 - 搜索增强版本

**目标**: 提升知识检索能力

**预计完成**: v2.0.0 之后 2-3 周

**核心功能**:
- [ ] 全文搜索（SQLite FTS5）
- [ ] 实时搜索（输入时即时显示结果）
- [ ] 搜索结果高亮
- [ ] 搜索历史（可选）
- [ ] 高级搜索（按日期、内容类型筛选）

**性能目标**:
- 搜索响应 < 100ms
- 支持中英文搜索
- 支持 10000+ 卡片搜索

**技术里程碑**:
- Phase 7: 搜索功能实现
  - [ ] SQLite FTS5 索引
  - [ ] 自动索引更新（触发器）
  - [ ] 前端搜索界面
  - [ ] 搜索性能优化

---

### v2.2.0 - 标签系统版本（可选）

**目标**: 支持多维度组织

**预计完成**: v2.1.0 之后 1-2 周

**核心功能**:
- [ ] 标签创建和管理
- [ ] 卡片标签关联（多对多）
- [ ] 按标签筛选卡片
- [ ] 标签可视化（颜色标记）
- [ ] 标签统计（每个标签的卡片数量）

**数据模型**:
- Loro 层支持标签存储
- SQLite 层支持标签查询和关联
- 订阅机制自动同步标签数据

**技术里程碑**:
- Phase 8: 标签系统实现
  - [ ] 标签数据层实现
  - [ ] 标签管理界面
  - [ ] 卡片标签关联
  - [ ] 标签筛选和可视化

---

### v2.3.0 - 完整版本

**目标**: 数据安全和迁移能力

**预计完成**: v2.2.0 之后 1 周

**核心功能**:
- [ ] 数据导出（ZIP 格式）
- [ ] 数据导入（从 ZIP 恢复）
- [ ] 自动备份（定期备份到本地）
- [ ] 备份管理（保留最新 N 个备份）
- [ ] 数据迁移工具

**技术里程碑**:
- Phase 9: 数据导入导出实现
  - [ ] Loro 文档导出
  - [ ] ZIP 打包和解压
  - [ ] 导入数据验证
  - [ ] 自动备份调度

---

## 🗺️ 版本时间线

```
2025-12 ────────── v1.0.0 MVP ✅
             │
2026-01 ────┼──── Phase 5: P2P 准备 ✅
             │
2026-01 ────┼──── Phase 6: P2P 实现 ✅
             │
2026-01 ────┼──── Phase 6R: 单池模型重构 + Spec Coding 🔄
             │             ├─ 建立规格文档
             │             ├─ 单池架构实施
             │             └─ UI 重构
             │
2026-02 ────────── v2.0.0 P2P 同步（单池架构 + Spec Coding）
             │
2026-02 ────┼──── Phase 7: 搜索功能
             │
2026-03 ────────── v2.1.0 搜索增强
             │
2026-03 ────┼──── Phase 8: 标签系统 (可选)
             │
2026-04 ────────── v2.2.0 标签系统
             │
2026-04 ────┼──── Phase 9: 导入导出
             │
2026-05 ────────── v2.3.0 完整版本
```

---

## 🎯 优先级说明

### P0 - 必须实现（MVP 核心）
- ✅ 卡片 CRUD
- ✅ Markdown 支持
- ✅ 本地存储（Loro + SQLite）
- ✅ 基础 UI/UX

### P1 - 高优先级（差异化价值）
- [ ] P2P 同步（v2.0.0）
- [ ] 离线编辑和冲突解决
- [ ] 多设备支持

### P2 - 中优先级（用户体验提升）
- [ ] 全文搜索（v2.1.0）
- [ ] 数据导入导出（v2.3.0）

### P3 - 低优先级（可选功能）
- [ ] 标签系统（v2.2.0）
- [ ] 国际化
- [ ] iOS/macOS 支持

---

## 📊 成功指标

### MVP 阶段（v1.0.0）✅
- ✅ 稳定运行（0 崩溃）
- ✅ 核心功能可用（100% 实现）
- ✅ 测试覆盖率 > 80%（实际 >85%）
- ✅ 真实用户试用（5+ 用户）
- ✅ 无严重 bug

### P2P 阶段（v2.0.0）
- [ ] 同步功能稳定（< 1% 失败率）
- [ ] 支持 3+ 设备同步
- [ ] **数据池隔离 100% 有效**（不同数据池数据不互串）
- [ ] **密码验证成功率 100%**（未授权设备无法访问）
- [ ] 冲突解决正确率 100%
- [ ] 无数据丢失（100% 保证）
- [ ] 用户满意度 > 4.0/5.0

### 成熟阶段（v2.3.0）
- [ ] 所有功能完整可用
- [ ] 性能指标达标（所有 < 预期目标）
- [ ] 日活用户 > 50
- [ ] 用户留存率 > 60%（30 天）

---

## 🔧 技术演进

### 当前技术栈
- **前端**: Flutter 3.x
- **后端**: Rust
- **CRDT**: Loro 1.3.1
- **缓存**: SQLite (rusqlite 0.33.0)
- **桥接**: flutter_rust_bridge 2.x
- **状态管理**: Provider
- **测试**: 80 个自动化测试

### 未来技术栈（v2.0.0）
- **P2P 网络**: libp2p
- **设备发现**: mDNS
- **密码哈希**: bcrypt
- **安全存储**: keyring crate (系统 Keyring)
- **NAT 穿透**: AutoNAT + Relay + DCUtR
- **协议**: 自定义同步协议（基于 Loro 增量更新）

### 未来技术栈（v2.1.0+）
- **搜索**: SQLite FTS5
- **备份**: ZIP 压缩

---

## 🚀 下一步行动
 
### 当前重点（2026-01-14）- Phase 6R: 单池模型重构 + Spec Coding 🔄

#### Week 1: Spec Coding 基础设施建立 ✅
- [x] 创建 specs/ 目录结构（rust/flutter/examples）
- [x] 编写核心规格文档
  - [x] SP-SPM-001: 单池模型核心规格
  - [x] SP-DEV-002: DeviceConfig 改造规格
  - [x] SP-POOL-003: Pool 模型 CRUD 规格
  - [x] SP-CARD-004: CardStore 改造规格
  - [x] SP-FLUT-003: Flutter UI 交互规格
- [x] 创建可运行的业务示例（single_pool_flow_spec.rs）
- [x] 创建规格中心索引和实施指南

#### Week 2: 按照规格实施数据模型层（进行中）
1. **Rust 模型层**
    - [ ] `rust/src/models/pool.rs`
      - [ ] 添加 `card_ids: Vec<String>` 字段（按 SP-POOL-003）
      - [ ] 实现 `add_card()` / `remove_card()` 方法
      - [ ] 运行测试 `cargo test pool::`
    - [ ] `rust/src/models/device_config.rs`
      - [ ] 重构：`joined_pools` → `pool_id: Option<String>`（按 SP-DEV-002）
      - [ ] 移除 `resident_pools` / `last_selected_pool` 字段
      - [ ] 修改 `join_pool()` - 检查单池约束
      - [ ] 简化 `leave_pool()` 逻辑
      - [ ] 重命名测试为 spec 风格（it_should_xxx）
      - [ ] 运行测试 `cargo test device_config::`
    - [ ] `rust/src/models/card.rs`
      - [ ] 移除 Loro 层的 `pool_ids` 字段
      - [ ] 保留 API 层的 `pool_id`（从 SQLite 填充）

2. **Store 层**
    - [ ] `rust/src/store/card_store.rs`
      - [ ] 修改 `create_card()` - 自动加入当前池（按 SP-CARD-004）
      - [ ] 修改 `add_card_to_pool()` - 修改 Pool Loro
      - [ ] 修改 `remove_card_from_pool()` - 修改 Pool Loro
      - [ ] 新增 `leave_pool()` - 清空所有本地数据
    - [ ] `rust/src/store/pool_store.rs`
      - [ ] 实现 Pool Loro 文档管理
      - [ ] 新增 `on_pool_updated()` 订阅回调
      - [ ] 持久化路径：`data/loro/pools/<pool_id>/`

#### Week 3: API 层和 Flutter UI 重构
3. **API 层**
    - [ ] `rust/src/api/pool.rs`
      - [ ] 移除 `create_pool()` API（自动创建）
      - [ ] 新增 `check_initialization_status()` API
      - [ ] 新增 `initialize_first_time(password)` API
      - [ ] 新增 `join_existing_pool(pool_id, password)` API
      - [ ] 新增 `leave_pool()` API
    - [ ] `rust/src/api/card.rs`
      - [ ] 修改 `create_card()` - 移除 pool_id 参数
      - [ ] 更新池操作方法
    - [ ] `rust/src/api/device_config.rs`
      - [ ] 移除所有多池相关 API
      - [ ] 更新 `get_device_config()` 返回结构

4. **Flutter UI**
    - [ ] `lib/main.dart`
      - [ ] 实现启动时状态检查逻辑（按 SP-FLUT-003）
    - [ ] 新增屏幕
      - [ ] `screens/onboarding_decision_screen.dart`
      - [ ] `screens/create_space_screen.dart`
      - [ ] `screens/pair_device_screen.dart`
    - [ ] `screens/home_screen.dart`
      - [ ] 移除"选择数据池"对话框
      - [ ] FAB 直接进入编辑器
    - [ ] `screens/card_editor_screen.dart`
      - [ ] 移除 pool_id 参数传递
      - [ ] 保存时自动关联到当前池
    - [ ] `screens/settings_screen.dart`
      - [ ] 修改术语："数据池" → "笔记空间"
      - [ ] 移除"数据池管理"
      - [ ] 新增"退出笔记空间"

#### Week 4: 集成测试和数据迁移
5. **集成测试**
    - [ ] 首次启动完整流程（初始化 → 创建空间）
    - [ ] 设备配对完整流程（发现 → 密码验证 → 加入）
    - [ ] 移除操作跨设备传播测试
    - [ ] 退出笔记空间完整流程

6. **数据迁移**
    - [ ] `rust/src/migration/single_pool_migration.rs`
      - [ ] 检查设备当前加入的池
      - [ ] 多池用户：选择第一个并警告
      - [ ] 可选：导出其他池的数据
      - [ ] 更新 DeviceConfig（单 pool_id）
      - [ ] 为 Pool 创建 card_ids（从 bindings 表迁移）
    - [ ] 测试迁移脚本
      - [ ] 未加入任何池（首次使用）
      - [ ] 加入单个池（直接迁移）
      - [ ] 加入多个池（警告 + 导出）

### 近期里程碑
- **本周（Jan 14-20）**: Spec Coding 基础设施 + 数据模型层重构
- **下周（Jan 21-27）**: 存储层和 API 层重构
- **下下周（Jan 28 - Feb 3）**: Flutter UI 重构
- **下月（Feb 4-10）**: 集成测试 + 数据迁移
- **发布目标**: v2.0.0 单池架构 + Spec Coding（Feb 中旬）
 

---

## 📝 备注

- 路线图会根据实际开发进度和用户反馈动态调整
- 可选功能（如标签系统）可能根据用户需求推迟或提前
- 性能指标会根据实际测试结果持续优化
- 详细的任务进度请查看 [TODO.md](../TODO.md)
