// input: 导航状态在业务中引用 AppSection 枚举值。
// output: 提供 cards、pool、settings 三个可切换分区标识。
// pos: 应用导航分区枚举定义，负责统一页面分区语义。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 应用壳层模块，负责导航与跨端布局。
enum AppSection { cards, pool, settings }
