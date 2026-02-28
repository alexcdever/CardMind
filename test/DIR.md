input: 测试目录结构变更与根级测试索引需求
output: 根级测试文件与子目录职责索引
pos: 测试目录说明与维护入口
新增或删除根级测试文件后请同步更新下方索引。
测试目录，包含根级守卫测试与各功能域测试子目录。

DIR.md - 本目录说明与文件职责索引
app/ - 应用壳层测试目录
features/ - 功能域测试目录
features/cards/data/ - 卡片读仓 SQLite 行为测试目录
features/cards/application/ - 卡片写侧命令服务测试目录
features/cards/projection/ - 卡片投影处理器测试目录
features/pool/data/ - 池读仓 SQLite 行为测试目录
features/pool/application/ - 池写侧命令服务测试目录
features/pool/projection/ - 池投影处理器测试目录
features/shared/projection/ - 共享投影事件分发测试目录
ui_interaction_governance_docs_test.dart - UI 交互治理文档守卫测试
interaction_guard_test.dart - 交互处理器空实现/禁用守卫测试
widget_test.dart - 应用启动与基础冒烟测试
fractal_doc_checker_test.dart - 文档规范检查工具测试
build_cli_test.dart - 构建 CLI 参数与行为测试
