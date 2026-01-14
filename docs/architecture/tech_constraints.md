# 技术选型理由 (Tech Constraints)

> **设计哲学**: 本文档定义"选择什么技术"，决策背景请查看 [ADR-0003：技术选型决策](../adr/0003-tech-constraints.md)。

---

## 1. 技术栈概览

| 层级 | 技术选型 | 用途 |
|------|---------|------|
| 数据同步 | Loro CRDT | 分布式编辑、自动冲突解决 |
| 缓存层 | SQLite | 快速查询、全文搜索 |
| ID 生成 | UUID v7 | 分布式唯一、时间有序 |
| 跨平台桥接 | flutter_rust_bridge | Dart/Rust 类型安全桥接 |
| 密码哈希 | bcrypt | 安全存储密码 |
| 设备发现 | mDNS | 本地网络自动发现 |
| 密码存储 | 系统 Keyring | 平台原生安全存储 |

---

## 2. 决策原则

1. **优先标准化技术**：UUID v7、mDNS、bcrypt 都是标准协议
2. **兼顾性能与安全**：Rust 实现高性能，bcrypt 保证安全
3. **平衡复杂度与收益**：双层架构略增复杂度，但收益显著
4. **跨平台一致性**：所有技术都支持主流平台

---

## 3. 详细决策 (链接)

### 3.1 数据层决策
- [ADR-0002: 双层架构决策](../adr/0002-dual-layer-architecture.md) - Loro + SQLite
- [ADR-0003: CRDT 选型](../adr/0003-tech-constraints.md#1-crt-选型-loro) - 为什么选择 Loro
- [ADR-0003: ID 生成选型](../adr/0003-tech-constraints.md#3-id-生成-uuid-v7) - 为什么选择 UUID v7

### 3.2 安全相关
- [ADR-0003: 密码哈希](../adr/0003-tech-constraints.md#5-密码哈希-bcrypt) - bcrypt 决策
- [ADR-0003: 设备发现](../adr/0003-tech-constraints.md#6-设备发现-mdns) - mDNS 决策
- [ADR-0003: 密码存储](../adr/0003-tech-constraints.md#7-密码存储-系统-keyring) - Keyring 决策

### 3.3 跨平台
- [ADR-0003: 跨平台桥接](../adr/0003-tech-constraints.md#4-跨平台桥接-flutter_rust_bridge) - flutter_rust_bridge 决策

---

## 4. 相关文档

### 架构文档
- [系统设计](./system_design.md) - 架构原则
- [数据契约](./data_contract.md) - 数据契约定义
- [同步机制](./sync_mechanism.md) - 同步机制设计

### 架构决策记录
- [ADR-0001: 单池所有权模型](../adr/0001-single-pool-ownership.md)
- [ADR-0002: 双层架构决策](../adr/0002-dual-layer-architecture.md)
- [ADR-0003: 技术选型决策](../adr/0003-tech-constraints.md)

### Spec文档
- 所有功能规格 → [规格中心](../specs/README.md)

---

## 更新日志

| 版本 | 变更 |
|------|------|
| 1.1.0 | 重构：移除决策详情，链接到 ADR-0003 |
| 1.0.0 | 初始版本 |

---

**设计哲学**: 本文档提供技术栈概览，详细的决策背景和权衡分析请查看 ADR 文档。
