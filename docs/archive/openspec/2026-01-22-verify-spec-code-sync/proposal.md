## Why

在完成两次重大重构后（规格结构从技术栈驱动迁移到领域驱动，以及 UI 从传统导航迁移到 React 风格设计），需要全面验证代码实现与规格文档的同步性。当前存在以下问题：(1) 新的领域驱动规格结构刚刚建立，需要验证是否准确反映实际实现；(2) UI 重构带来大量新组件，但使用旧的规格结构归档，可能存在规格遗漏；(3) 缺乏系统化的规格-代码同步验证机制，难以及时发现不一致。

## What Changes

本变更将建立规格与代码的同步验证体系：

- 创建自动化的规格覆盖率检查工具
- 验证新领域驱动规格结构（`engineering/`, `domain/`, `api/`, `features/`, `ui_system/`）与实际代码的一致性
- 识别缺失、过期或不准确的规格文档
- 更新发现的不同步规格
- 建立持续同步验证机制，防止未来规格与代码脱节
- 生成规格覆盖率报告，显示哪些代码有规格、哪些缺失

## Capabilities

### New Capabilities

- `spec-coverage-checker`: 检查代码与规格的覆盖率，识别有代码但无规格、有规格但无代码的情况
- `spec-sync-validator`: 验证规格内容与实际代码实现的一致性，检查方法签名、数据结构、行为是否匹配
- `spec-migration-validator`: 专门验证从旧结构迁移到新领域驱动结构后的规格完整性

### Modified Capabilities

- `engineering/directory_conventions`: 添加规格验证规则和持续同步机制说明
- `domain/*`: 验证并更新领域模型规格，确保与 Rust 实现一致
- `features/*`: 验证并补充 UI 功能规格，覆盖新的 React 风格组件

## Impact

**受影响的系统**:
- OpenSpec 规格文档系统（所有目录：`engineering/`, `domain/`, `api/`, `features/`, `ui_system/`）
- Rust 后端代码（`rust/src/`）
- Flutter 前端代码（`lib/`）
- 测试文件（`test/specs/`, `test/widgets/`, `test/integration/`）

**工具和流程**:
- 新增规格验证工具（可能是 Dart 或 Rust 实现）
- 集成到 CI/CD 流程（可选）
- 更新开发工作流文档（CLAUDE.md）

**预期成果**:
- 规格覆盖率报告（哪些模块有完整规格，哪些缺失）
- 同步问题清单（规格与代码不一致的地方）
- 更新后的规格文档（修复所有不一致）
- 持续验证机制（防止未来脱节）
