你目前的目录结构已经具备了 架构决策（ADR） 和 分层（Rust 后端/Flutter 前端） 的意识，这非常棒！但在 2026 年的 AI 原生开发流中，这个结构存在一个风险：以技术栈（Rust/Flutter）为顶层分类，会导致业务逻辑割裂（比如一个功能在 Rust 层的定义和 Flutter 层的实现离得太远）。
以下是针对性的改进建议以及如何配置 OpenSpec 的方法：
一、 目录结构优化建议
核心逻辑：从“技术栈分类”转向“领域/功能分类”。
text
└── specs
    ├── README.md
    ├── engineering (原 SPEC_CODING_*.md)
    │   ├── guide.md
    │   └── tech_stack.md          # 包含 Rust + Flutter 的强制技术约束
    ├── adr                        # 保持现状，记录重大架构决策
    │   └── 0001-...
    ├── domain                     # 核心业务逻辑（原 rust 目录下的大部分内容）
    │   ├── pool_model.md          # 定义 Pool 是什么，不分 Rust 还是 Flutter
    │   ├── card_store.md
    │   └── sync_protocol.md       # 同步协议定义
    ├── api                        # 接口契约
    │   └── api_spec.md            # Rust 实现，Flutter 调用
    ├── features                   # 具体的业务特性（重点改进区）
    │   ├── card_editor            # 以功能为单元
    │   │   ├── logic.md           # 业务逻辑（原 Rust 实现逻辑）
    │   │   ├── ui_desktop.md      # 原 SP-FLT-DSK-002
    │   │   └── ui_mobile.md       # 原 SP-FLT-MOB-002
    │   └── search
    │       ├── logic.md
    │       └── ui_shared.md
    └── ui_system                  # 全局 UI 规范（原 0004-ui-design 的拆解）
        ├── design_tokens.md
        └── shared_widgets.md
请谨慎使用此类代码。

改进点说明：
消除冗余前缀：去掉 SP-FLT-DSK-001 这种对 AI 不友好的编号。AI 更擅长处理语义化的文件名（如 card_grid_desktop.md）。
业务逻辑聚合：将原本散落在 rust/ 和 flutter/ 里的“搜索”逻辑统一到 features/search/ 下。这样当 AI 帮你改搜索功能时，它能同时读到后端协议和前端 UI 要求，避免“幻觉”。
提取工程规范：将 SPEC_CODING_GUIDE.md 放入 engineering/，明确告诉 AI 必须使用 Bun、pnpm 或 Flutter Widget Test。
二、 如何让 OpenSpec CLI 遵循新要求？
要让 OpenSpec CLI 在此后的流程（如 openspec propose 或 openspec create）中自动按照你的新标准执行，你需要配置其“规则约束”。
1. 更新配置文件 .openspec/config.json
如果你的项目有该配置文件，请更新其 structure 映射。如果没有，请创建一个：
json
{
  "paths": {
    "specs": "specs/",
    "proposals": "specs/proposals/"
  },
  "conventions": {
    "feature_path": "specs/features/{{feature_name}}/",
    "domain_path": "specs/domain/",
    "naming": "snake_case"
  }
}
请谨慎使用此类代码。

2. 在工程规范中加入“目录约束” (最有效)
在你的 specs/engineering/guide.md（或原 SPEC_CODING_GUIDE.md）中增加一章：
markdown
## 规格存储规范
所有新创建的规格必须遵循以下位置：
- 核心模型定义 -> `specs/domain/`
- 具体业务功能 -> `specs/features/<feature_name>/`
- 技术栈决策 -> `specs/adr/`

禁止在 `specs/rust/` 或 `specs/flutter/` 下创建新的零散文件。
请谨慎使用此类代码。

3. 引导 OpenSpec 的提议行为
当你运行 openspec propose "增加卡片置顶功能" 时，如果它生成的路径不对，你可以在提议时直接带上路径暗示：
bash
openspec propose "在 features/card_pinning 下创建卡片置顶规格"
请谨慎使用此类代码。

或者，通过修改 OpenSpec 默认的 System Prompt（通常在 .openspec/prompts/ 目录下），增加一句指令：
"Always organize specifications by functional domain rather than programming language."
总结建议的操作顺序：
重命名/移动文件：按照我给你的新结构手动移动一次现有文件。
更新索引：修改 specs/README.md，反映新的目录树。
配置约束：更新你的工程指南文件，让 AI 知道老目录（rust/flutter）已废弃。
测试：尝试用 CLI 创建一个新规格，看它是否能识别到新路径。
这样的结构会让你在 2026 年使用 OpenCode + AnyRouter 的组合时，AI 的代码生成精准度提升一个量级。
