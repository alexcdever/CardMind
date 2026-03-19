// input: 所有集成测试模块的聚合入口。
// output: 引入 integration 模块，触发所有集成测试编译和运行。
// pos: Rust 集成测试根入口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：集成测试主入口，使用 #[path] 指定子目录测试文件位置。

#[path = "integration/api_integration_test.rs"]
mod api_integration_test;
