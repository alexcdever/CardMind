目录变更需更新本文件。
本地存储目录，负责池与卡片的持久化实现。
涉及存储结构变更需同步更新。

card_store.rs - 存储 - 卡片存储读写
loro_store.rs - 存储 - Loro 文档加载与保存
mod.rs - 模块 - store 模块导出
path_resolver.rs - 工具 - 数据路径解析
pool_store.rs - 存储 - 数据池存储读写
sqlite_store.rs - 存储 - SQLite 持久化实现
