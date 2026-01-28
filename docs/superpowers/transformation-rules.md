# OpenSpec → Superpowers 转换规则

## 🎯 核心原则

**从"规格"到"行为指南"**：将技术规格转换为自然的行为描述文档

## 🔄 转换规则

### 1. 文档结构转换

#### OpenSpec 结构：
```
## 📋 规格编号: SP-XXX-XXX
**版本**: 1.0.0
**状态**: Active
**依赖**: [...]

## 1. 概述
[技术概述]

## Requirement: XXXXX
The system SHALL ...

### Scenario: XXXXX
- **GIVEN** ...
- **WHEN** ...  
- **THEN** ...
```

#### Superpowers 结构：
```
# [功能名称] 行为指南

## 🎯 核心行为
系统应该做什么，用自然语言描述

## 📋 典型场景
### 当[某种情况]时
用户做了[某个操作]，系统会[如何响应]

### 如果[错误情况]
系统会[如何处理]，确保[什么结果]
```

### 2. 语言风格转换

| OpenSpec 语言 | Superpowers 语言 |
|---------------|------------------|
| "The system SHALL" | "系统应该" |
| "GIVEN/WHEN/THEN" | "当...时"/"如果..." |
| "前置条件" | "前提情况" |
| "预期结果" | "系统行为" |
| "操作步骤" | "用户操作" |

### 3. 内容组织转换

#### 从：技术规格导向
```
## Requirement: Single Pool Constraint
The system SHALL enforce that a device can join at most one pool...

### Scenario: Device joins first pool successfully
- **GIVEN** a device with no joined pools
- **WHEN** the device joins a pool with a valid password
- **THEN** the pool SHALL be added to the device's joined pools
```

#### 到：行为指南导向
```
## 🎯 单池约束行为
每个设备只能加入一个笔记空间，这是为了确保个人笔记的私密性和一致性。

### 📋 加入第一个空间
当用户尝试加入第一个笔记空间时：
- 系统验证密码正确性
- 自动开始同步该空间的数据
- 所有后续创建的笔记都属于这个空间

### ⚠️ 拒绝加入多个空间
如果用户已经加入了一个空间，再尝试加入另一个时：
- 系统会友好地提示："您已经加入了一个笔记空间"
- 不会破坏现有数据
- 引导用户先退出当前空间
```

### 4. 实现指南嵌入

#### 原OpenSpec测试用例转换为实现提示：
```
## 💡 实现提示
### 数据模型建议
```rust
struct DeviceConfig {
    current_pool: Option<String>, // 当前空间ID
}
```

### 关键验证点
- 在 `join_pool()` 方法中检查 `current_pool` 是否为 `None`
- 使用友好的错误信息而非技术异常
- 考虑提供"切换空间"的选项
```

### 5. 中文本地化增强

#### 技术术语转换：
| 英文术语 | 中文表达 |
|----------|----------|
| Pool | 笔记空间 |
| Device | 设备 |
| Card | 笔记卡片 |
| Sync | 同步 |
| CRDT | 自动合并技术 |

#### 用户友好描述：
```
❌ 技术描述："基于CRDT的数据一致性保证"
✅ 用户描述："自动解决多设备编辑冲突，永不丢失数据"
```

## 📁 文件组织建议

### Superpowers 文档结构：
```
docs/superpowers/
├── core-behaviors/          # 核心行为指南
│   ├── single-pool.md      # 单池模型行为
│   ├── card-creation.md    # 卡片创建行为
│   └── sync-behavior.md    # 同步行为
├── user-experiences/        # 用户体验指南
│   ├── first-setup.md      # 首次设置
│   ├── multi-device.md     # 多设备使用
│   └── offline-usage.md    # 离线使用
├── developer-guide/         # 开发者实现指南
│   ├── data-models.md      # 数据模型建议
│   ├── api-design.md       # API设计模式
│   └── error-handling.md   # 错误处理
└── architecture/            # 架构行为解释
    ├── dual-layer.md       # 双层架构行为
    ├── p2p-sync.md         # P2P同步行为
    └── security.md         # 安全行为
```

## 🎯 转换示例

### 输入（OpenSpec）：
见 `openspec/specs/domain/pool/model.md`

### 输出（Superpowers）：
见后续生成的行为指南文档

## ✅ 质量检查清单

转换后的文档应该：
- [ ] 用自然中文描述行为
- [ ] 去除技术规格语言
- [ ] 提供具体的实现建议
- [ ] 包含用户视角的描述
- [ ] 保持信息的完整性
- [ ] 更易读和理解