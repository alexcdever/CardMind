input: test/features/pool/DIR.md 目录结构与文件职责输入。
output: 目录索引与维护约束说明。
pos: 目录说明文件（修改本目录文件需同步更新本文件）。
新增或删除本目录测试文件后请同步更新下方索引。
数据池域测试目录，覆盖加入、审批、错误与恢复流程。

DIR.md - 本目录说明与文件职责索引
pool_page_test.dart - 池页面主流程与恢复态行为测试
join_error_mapper_test.dart - 加入错误码文案与动作映射测试
pool_sync_interaction_test.dart - 文件 - 见同目录实现
domain/ - 目录 - 池领域实体与生命周期建模测试
data/ - 目录 - 池数据层 SQLite 读仓行为测试
