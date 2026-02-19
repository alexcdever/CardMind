# 双层存储规格

## 行为
GIVEN 任何写操作
WHEN Loro commit 完成
THEN 订阅回调更新 SQLite 缓存
