# 类型定义

## 行为

GIVEN 领域模型需要共享类型
WHEN 新增或调整领域类型
THEN 所有模块统一引用本文件的类型约定

GIVEN API 对外暴露错误
WHEN Rust 返回错误
THEN 错误必须包含 code 与 message
