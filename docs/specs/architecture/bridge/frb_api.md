# FRB API 规格

## 行为
GIVEN Flutter 初始化 Store
WHEN 传入 base_path
THEN Rust 校验并创建 data 目录

GIVEN 任意 FRB API 出错
WHEN 返回错误
THEN code 与 message 必须非空
