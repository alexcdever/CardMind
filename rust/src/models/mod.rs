// input: 编译期对子模块的组织声明（card/pool/error/api_error）。
// output: 对外导出统一数据模型与错误类型命名空间。
// pos: models 聚合模块，负责集中声明跨层共享类型入口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件维护 models 子模块导出清单。
/// 卡片模型
pub mod card;
/// 数据池模型
pub mod pool;
/// 统一错误类型
pub mod error;
/// API 错误
pub mod api_error;
