# Testing Standard

- Flutter 测试放在 `test/`，与功能对齐。

- Rust 集成测试放在 `rust/tests/`，覆盖 FFI 入口与边界条件。

- 新增功能需补充对应测试，覆盖成功与失败路径。

- 常用验证命令：`flutter test`、`cargo test`、`flutter analyze`。
