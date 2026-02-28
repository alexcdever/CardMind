input: rust/src/ 目录结构与模块职责输入。
output: Rust 源码目录索引与维护约束说明。
pos: Rust 源码目录说明文件（修改本目录文件需同步更新本文件）。
目录变更需更新本文件。
Rust 核心逻辑入口，包含模型与存储实现。
变更接口需同步更新。

api.rs - 接口 - FRB 暴露 API
frb_generated.rs - 生成 - FRB 绑定代码
lib.rs - 入口 - Rust crate 入口
models/ - 目录 - 数据模型定义
net/ - 目录 - 组网与同步模块
store/ - 目录 - 本地存储实现
utils/ - 目录 - 工具函数
DIR.md - 目录说明与文件索引
utils/DIR.md - 工具子目录说明
