目录变更需更新本文件。input: tool 目录中的维护脚本与索引文档。
output: 说明目录用途，并为关键脚本提供可检索的索引条目。
pos: 作为 tool 目录入口，减少脚本用途与位置的认知成本。

tool/ 目录存放项目维护脚本，当前聚焦分形文档规则的初始化与校验。
用于在提交前检查变更文件的头注释与目录索引是否完整。

- fractal_doc_bootstrap.dart - 扫描仓库并补齐缺失 DIR.md 与源码三行头注释。
- fractal_doc_check.dart - 命令行检查入口，基于 git diff 变更文件执行门禁校验。
- fractal_doc_checker.dart - 分形文档校验核心，检查头注释、路径与 DIR.md 条目。
- DIR.md - tool 目录索引与用途说明。
