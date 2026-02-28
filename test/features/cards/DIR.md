input: 目录结构变更与卡片域测试文件清单
output: 卡片域测试文件定位与断言职责索引
pos: 卡片域测试目录说明与维护入口
新增或删除本目录测试文件后请同步更新下方索引。
卡片域测试目录，覆盖列表、同步联动与桌面交互。

DIR.md - 本目录说明与文件职责索引
cards_page_test.dart - 卡片页基础渲染与 CRUD 可观察行为测试
cards_sync_navigation_test.dart - 同步异常下跳转处理与编辑不阻断测试
cards_desktop_interactions_test.dart - 桌面右键菜单交互测试
domain/ - 目录 - 卡片领域模型与投影语义测试
data/ - 目录 - 卡片数据层 SQLite 读仓行为测试
application/ - 目录 - 卡片写侧命令服务测试
