# CardMind 任务进度

**最后更新**: 2026-01-04

## 当前任务

- [ ] Phase 5: P2P 同步准备 - libp2p 原型验证
  - [x] Loro 同步能力验证（6 个测试通过）
  - [x] P2P 同步设计文档编写
  - [ ] libp2p 基础连接测试
  - [ ] mDNS 设备发现原型

## 待开始

### Phase 6: P2P 同步实现

#### 数据池基础设施
- [ ] 数据池数据结构实现
  - [ ] Loro 层数据池定义（pool_id, name, password_hash, members）
  - [ ] SQLite 层添加 pools 表
  - [ ] SQLite 层添加 card_pool_bindings 表（多对多关系）
  - [ ] 设备配置管理（config.json: device_id, joined_pools, resident_pools）
- [ ] 密码管理实现
  - [ ] 依赖集成
    - [ ] 添加 bcrypt crate (version 0.15)
    - [ ] 添加 zeroize crate (version 1.7)
    - [ ] 添加 keyring crate (跨平台 Keyring)
  - [ ] 传输层安全
    - [ ] libp2p 强制 TLS 配置
    - [ ] 禁用明文连接
    - [ ] 自签名证书生成（本地网络）
  - [ ] 密码验证流程
    - [ ] JoinRequest 结构定义（pool_id, password, timestamp）
    - [ ] 时间戳验证（5分钟有效期）
    - [ ] bcrypt 密码验证
    - [ ] 使用 Zeroizing<String> 包装密码
    - [ ] 验证后立即清零内存
  - [ ] 密码强度验证
    - [ ] 前端验证（最少8位）
    - [ ] 后端二次验证
    - [ ] 密码强度提示（可选复杂度建议）
  - [ ] 密码存储
    - [ ] Keyring 存储实现（cardmind.pool.<pool_id>.password）
    - [ ] 跨平台适配（iOS/Android/Windows/Linux）
  - [ ] 密码修改和同步
    - [ ] 修改 password_hash 字段
    - [ ] CRDT 同步到所有设备
    - [ ] 离线设备重连验证新密码
  - [ ] 日志安全
    - [ ] 密码不出现在日志中
    - [ ] Debug 输出脱敏处理
- [ ] 数据池同步逻辑
  - [ ] 同步过滤实现（card.pool_ids ∩ device.joined_pools）
  - [ ] 卡片绑定池管理（多对多关系）
  - [ ] 常驻池机制（新建卡片自动绑定）
  - [ ] 数据池隔离验证

#### P2P 网络实现
- [ ] mDNS 设备发现
  - [ ] mDNS 广播数据池信息（仅 pool_id，不暴露 pool_name）
  - [ ] 发现对等设备的数据池
  - [ ] 隐私保护（不广播敏感信息）
- [ ] libp2p 集成和测试
- [ ] 单对单同步协议实现
- [ ] 多点对多点同步实现

#### 前端界面
- [ ] 数据池管理界面
  - [ ] 数据池列表界面
  - [ ] 创建数据池界面（输入 name 和 password）
  - [ ] 加入数据池界面（mDNS 发现 + 密码验证）
  - [ ] 退出数据池功能
- [ ] 常驻池设置界面
  - [ ] 从已加入的池中选择常驻池（多选）
  - [ ] 常驻池标记显示
- [ ] 卡片绑定池管理
  - [ ] 卡片详情页显示绑定池
  - [ ] 卡片绑定池选择界面（多选）
- [ ] 前端同步状态显示

#### 测试和优化
- [ ] 数据池隔离测试（100% 有效）
- [ ] 密码验证测试（100% 成功率）
- [ ] 常驻池机制测试
- [ ] 错误处理和优化

### Phase 7: 搜索功能（未来版本）
- [ ] 后端 FTS5 全文搜索实现
- [ ] 前端搜索界面实现
- [ ] 搜索结果高亮和排序

### Phase 8: 标签系统（可选）
- [ ] 数据层标签支持
- [ ] 前端标签管理界面

### Phase 9: 数据导入导出
- [ ] 导出功能实现
- [ ] 导入功能实现
- [ ] 自动备份机制

## 已完成

### Phase 4: MVP 发布 (2025-12-31 完成)
- [x] 全面测试（80 个测试全部通过）
- [x] 性能测试（所有指标超出预期）
- [x] 文档完善（用户手册、CHANGELOG、API 文档）
- [x] 打包发布（Android APK、Windows 构建）
- [x] 发布准备（应用描述、图标指南、截图指南）

### Phase 3: UI/UX 优化 (2025-12-31 完成)
- [x] 主题系统（浅色/深色主题）
- [x] 设置页面
- [x] 响应式设计（手机/平板/桌面）
- [x] 交互优化（加载状态、错误提示、成功反馈）
- [x] 性能优化（列表虚拟化、GridView）

### Phase 2: 核心功能 - 卡片 CRUD (2025-12-31 完成)
- [x] Rust 后端实现（76 个测试通过）
- [x] API 层实现（11 个 API 函数）
- [x] Flutter 前端实现（HomeScreen、CardEditorScreen、CardDetailScreen）
- [x] Markdown 支持和预览

### Phase 1: 项目初始化 (2025-12-30 完成)
- [x] 环境配置
- [x] 项目搭建（Flutter + Rust + flutter_rust_bridge）
- [x] Loro 集成验证
- [x] SQLite 集成
- [x] 基础架构（CardStore、订阅机制、日志系统）
- [x] 68 个测试通过

### Phase 0: 准备阶段 (完成)
- [x] 需求分析和文档编写
- [x] PRD、架构文档、数据库设计文档

## 进度统计

| 阶段 | 状态 | 完成度 |
|------|------|--------|
| Phase 0 | ✅ 完成 | 100% |
| Phase 1 | ✅ 完成 | 100% |
| Phase 2 | ✅ 完成 | 100% |
| Phase 3 | ✅ 完成 | 100% |
| Phase 4 | ✅ 完成 | 100% |
| Phase 5 | 🔄 进行中 | 75% |
| Phase 6 | ⏳ 未开始 | 0% |

**总体进度**: MVP 完成（v1.0.0），P2P 同步准备中（v2.0.0）
