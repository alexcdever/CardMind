input: tool 目录中的维护脚本与索引文档
output: 说明目录用途，并为关键脚本提供可检索的索引条目
pos: tool/DIR.md - 工具目录入口，减少脚本用途与位置的认知成本，修改本文件需同步更新文件头
中文注释: tool 目录存放项目维护脚本与构建入口，用于承载可复用的工程自动化命令

tool/ 目录存放项目维护脚本与构建入口。
用于承载可复用的工程自动化命令。

- build.dart - 构建入口脚本，支持 app/lib 构建链路与参数化平台目标
- DIR.md - tool 目录索引与用途说明
- quality.dart - 质量检查脚本，运行 flutter analyze、flutter test、cargo test 等质量门禁
- test_boundary_scanner.dart - 测试边界扫描器，自动识别代码边界条件并生成覆盖报告
- test_boundary_config.yaml - 测试边界扫描器配置文件，定义扫描路径、边界类型权重和忽略模式

test/tool/ 目录：
- test_boundary_scanner_test.dart - 测试边界扫描器单元测试
