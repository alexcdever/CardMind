// input: 编译期网络子模块装配声明（codec/endpoint/messages/pool_network/session/sync）。
// output: 对外导出网络与同步子模块命名空间供上层引用。
// pos: net 聚合模块，负责组织连接、消息与同步能力入口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件维护 net 子模块导出清单。
pub mod codec;
pub mod endpoint;
pub mod messages;
pub mod pool_network;
pub mod session;
pub mod sync;
