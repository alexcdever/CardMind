input: lib/DIR.md 目录结构与文件职责输入。
output: 目录索引与维护约束说明。
pos: 目录说明文件（修改本目录文件需同步更新本文件）。
目录变更需更新本文件。
UI 壳层与业务页面目录说明：

app/app.dart - 应用入口组件（MaterialApp 与首屏路由）
app/layout/adaptive_shell.dart - 跨端自适应壳层（移动底栏/桌面侧栏）
app/navigation/app_section.dart - 三主导航分区枚举
features/onboarding/ - 首次启动分流页面与状态控制
features/cards/ - 卡片列表页、桌面交互与列表视图模型
features/editor/ - 卡片编辑页、离开保护与快捷键保存
features/pool/ - 数据池三态页面、错误映射与池状态模型
features/settings/ - 设置页与池入口回流
features/sync/ - 同步状态模型与弱提示/异常高亮组件
features/shared/ - 跨域共享数据基础设施（读模型数据库等）
main.dart - 文件 - 见同目录实现
DIR.md - 本目录说明与文件职责索引
