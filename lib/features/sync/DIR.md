input: lib/features/sync/DIR.md 目录结构与文件职责输入。
output: 目录索引与维护约束说明。
pos: 目录说明文件（修改本目录文件需同步更新本文件）。
新增或删除本目录文件后请同步更新下方索引。
同步反馈目录，定义同步状态与展示组件。

DIR.md - 本目录说明与文件职责索引
sync_status.dart - 同步状态与错误码模型
sync_banner.dart - 同步健康/异常反馈组件与查看动作
sync_controller.dart - 文件 - 见同目录实现
sync_service.dart - 文件 - 见同目录实现
