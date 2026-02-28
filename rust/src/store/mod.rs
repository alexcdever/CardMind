// input: 编译期存储子模块装配声明（card/pool/loro/sqlite/path_resolver）。
// output: 对外导出存储层统一命名空间供业务与网络层依赖。
// pos: store 聚合模块，负责组织本地持久化相关子模块入口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件维护 store 子模块导出清单。
/// 卡片存储
pub mod card_store;
/// loro 存储
pub mod loro_store;
/// 数据池存储
pub mod pool_store;
/// sqlite 存储
pub mod sqlite_store;
/// 路径解析
pub mod path_resolver;
