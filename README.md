# CardMind

一款简洁、高效的卡片笔记应用，支持离线优先和 P2P 多设备同步。

## 项目简介

CardMind 是一款专注于个人知识管理的卡片式笔记应用。通过卡片的形式组织和管理你的笔记、想法和知识片段。应用采用离线优先设计，基于 CRDT 技术实现可靠的多设备同步，支持完全离线编辑和自动冲突解决。

## 核心特性

- **卡片式笔记**: 用卡片组织你的想法和知识，每张卡片一个主题
- **Markdown 支持**: 支持完整的 Markdown 格式，方便编写结构化笔记
- **离线优先**: 基于 Loro CRDT，所有数据本地存储，无网络时也能正常使用
- **P2P 同步**: 去中心化的点对点同步，无需依赖服务器
- **自动冲突解决**: CRDT 算法自动处理编辑冲突，永不丢失数据
- **跨平台**: 基于 Flutter 开发，支持 iOS、Android、Windows、macOS、Linux

## 技术栈

### 核心技术
- **前端**: Flutter 3.x (Dart)
- **后端逻辑**: Rust
- **CRDT 引擎**: Loro（文件持久化）
- **查询缓存**: SQLite（读取层）
- **跨平台桥接**: flutter_rust_bridge

### 架构模式
- **双层架构**: Loro CRDT（写入层）+ SQLite（读取层）
- **单池模型**: 每个设备最多加入一个数据池
- **规格驱动**: OpenSpec 规范驱动开发
- **约束自动化**: Project Guardian 自动执行代码约束

详细技术决策请查看 [架构决策记录 (ADR)](docs/adr/)。

## 项目状态

**当前阶段**: 开发中
**最后更新**: 2026-01-23

✅ **已完成**:
- 双层架构（Loro + SQLite）
- 单池所有权模型
- 规格文档体系（53 个规格文档，100% 双语合规）
- OpenSpec 工作流
- Project Guardian 约束系统
- 完整的 ADR 文档（5 个架构决策记录）

🚧 **进行中**:
- 核心功能实现
- 测试覆盖
- UI 组件开发

🔜 **计划中**:
- P2P 多设备同步
- 全文搜索
- 数据导入/导出

## 快速开始

### 开发环境要求

- **Flutter**: 3.x
- **Rust**: 1.70+
- **Dart**: 3.x

### 环境搭建

详细步骤请查看 [环境搭建指南](docs/SETUP.md)。

### 快速命令

```bash
# 运行测试
cd rust && cargo test              # Rust 测试
flutter test                       # Flutter 测试

# 静态检查
cd rust && cargo clippy            # Rust 静态分析
flutter analyze                    # Flutter 静态分析

# 代码格式化
cd rust && cargo fmt               # Rust 格式化
dart format .                      # Dart 格式化

# 约束验证
dart tool/validate_constraints.dart        # 快速验证
dart tool/validate_constraints.dart --full # 完整验证

# 生成桥接代码
dart tool/generate_bridge.dart

# 运行应用
flutter run
```

## 开发者指南

### 📖 新手入门（推荐阅读顺序）

如果你是第一次接触这个项目，建议按以下顺序阅读：

1. **[README.md](README.md)** - 项目概览（你在这里）
2. **[CLAUDE.md](CLAUDE.md)** - 开发规范和文档导航（必读！）
3. **[docs/adr/](docs/adr/)** - 架构决策记录（了解"为什么"）
4. **[openspec/specs/](openspec/specs/)** - 规格文档（了解"是什么"）

### 🚀 开发工作流

本项目使用 **OpenSpec 规范驱动开发**：

#### 方式 1：OpenSpec 工作流（推荐用于新功能）

```bash
# 1. 开始新变更
/opsx:new

# 2. 快速创建所有 artifacts
/opsx:ff

# 3. 实施任务
/opsx:apply

# 4. 验证实现
/opsx:verify

# 5. 同步规格
/opsx:sync

# 6. 归档变更
/opsx:archive
```

#### 方式 2：传统工作流（用于小改动）

1. 查看相关规范: `openspec/specs/`
2. 查看相关 ADR: `docs/adr/`
3. 使用 `TodoWrite` 跟踪任务
4. 遵循约束: Project Guardian 自动检查
5. 运行测试: 确保所有测试通过

### 📚 文档体系

本项目采用分层文档系统，按优先级顺序：

| 优先级 | 位置 | 内容 | 特点 |
|--------|------|------|------|
| 1 | `openspec/specs/` | API 规范、行为定义 | 可执行、可测试 |
| 2 | `docs/adr/` | 架构决策记录 | 不可变、历史记录 |
| 3 | `project-guardian.toml` | 代码约束规则 | 自动执行 |
| 4 | `docs/requirements/` | 产品需求和愿景 | 指导方向 |

#### OpenSpec 规格文档（`openspec/specs/`）

按领域组织的规格文档：

```
openspec/specs/
├── engineering/       # 工程实践和架构模式
├── domain/            # 领域模型和业务逻辑
├── api/               # 公共 API 和 FFI 接口
├── features/          # 用户功能规格
└── ui_system/         # UI 设计系统
```

**关键文件**:
- `openspec/specs/README.md` - 规格索引
- `openspec/engineering/guide.md` - Spec Coding 方法论
- `openspec/engineering/directory_conventions.md` - 目录结构约定

#### 架构决策记录（`docs/adr/`）

记录重要架构决策的"为什么"：

- [ADR-0001: 单池所有权模型](docs/adr/0001-单池所有权模型.md)
- [ADR-0002: 双层架构](docs/adr/0002-双层架构.md)
- [ADR-0003: 技术约束](docs/adr/0003-技术约束.md)
- [ADR-0004: UI 设计系统](docs/adr/0004-UI设计系统.md)
- [ADR-0005: 日志系统](docs/adr/0005-日志系统.md)

#### Project Guardian 约束系统

自动执行的代码约束，防止 LLM 幻觉和架构违规：

- `project-guardian.toml` - 约束配置
- `.project-guardian/best-practices.md` - 11 个最佳实践
- `.project-guardian/anti-patterns.md` - 11 个反模式

### 🎯 核心架构原则

1. **双层架构**
   - 所有写操作 → Loro CRDT（真实数据源）
   - 所有读操作 → SQLite（查询缓存）
   - 订阅驱动：Loro 提交 → 回调 → SQLite 更新

2. **单池模型**
   - 每张卡片属于一个池
   - 每个设备最多加入一个池
   - 新卡片自动属于已加入的池

3. **规格驱动**
   - 规格 → 测试 → 代码
   - 使用 `it_should_xxx()` 测试命名
   - 所有 API 返回 `Result<T, Error>`

详细说明请查看 [CLAUDE.md](CLAUDE.md)。

## Git 工作流

### 分支策略
- `main` - 主分支，稳定版本
- `feature/xxx` - 功能分支
- `bugfix/xxx` - 修复分支
- `refactor/xxx` - 重构分支

### Commit 规范

采用 Conventional Commits 规范：

```
<type>(<scope>): <subject>

<body (optional)>
```

**Type 类型**:
- `feat`: 新功能
- `fix`: Bug 修复
- `refactor`: 代码重构
- `test`: 测试相关
- `docs`: 文档更新
- `chore`: 构建/工具/依赖变动

**示例**:
```bash
feat(pool): 实现单池所有权模型

- 添加设备池成员资格验证
- 拒绝加入第二个池的请求
- 测试覆盖率 95%

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

### PR 要求
- ✅ 测试通过（`cargo test` + `flutter test`）
- ✅ 静态检查通过（`cargo clippy` + `flutter analyze`）
- ✅ 约束验证通过（`dart tool/validate_constraints.dart`）
- ✅ 遵循 Commit 规范

## 文档索引

### 核心文档
- [CLAUDE.md](CLAUDE.md) - 开发规范和文档导航（必读）
- [AGENTS.md](AGENTS.md) - AI Agent 工作指南

### 规格和决策
- [OpenSpec 规格中心](openspec/specs/README.md) - 所有规格文档索引
- [架构决策记录 (ADR)](docs/adr/README.md) - 架构决策历史

### 开发指南
- [环境搭建](docs/SETUP.md) - 开发环境配置
- [测试指南](docs/testing/TESTING_GUIDE.md) - TDD 开发流程
- [API 设计](docs/API_DESIGN.md) - API 接口定义

### 产品文档
- [产品需求文档 (PRD)](docs/PRD.md) - 产品需求全貌
- [开发路线图](docs/ROADMAP.md) - 开发计划和进度
- [用户使用手册](docs/USER_GUIDE.md) - 用户指南

### 技术文档
- [技术架构设计](docs/ARCHITECTURE.md) - 架构设计详解
- [数据库设计](docs/DATABASE.md) - Loro + SQLite 双层设计
- [日志规范](docs/LOGGING.md) - 日志最佳实践

## 依赖版本

### Rust 核心依赖

```toml
loro = "1.0"                    # CRDT 引擎
rusqlite = "0.31"               # SQLite 数据库
uuid = "1.7"                    # UUID v7
flutter_rust_bridge = "2.0"    # Flutter 桥接
tracing = "0.1"                 # 日志系统
```

### Flutter 核心依赖

```yaml
provider: ^6.0.0                # 状态管理
flutter_markdown: ^0.6.0        # Markdown 渲染
flutter_rust_bridge: ^2.0.0    # Rust 桥接
logger: ^2.0.0                  # 日志系统
```

完整依赖列表请查看 `rust/Cargo.toml` 和 `pubspec.yaml`。

## 许可证

[待定]

## 贡献

欢迎贡献！请先阅读 [CLAUDE.md](CLAUDE.md) 了解开发规范。

---

**最后更新**: 2026-01-23
**维护者**: CardMind Team
