# 双层存储规格

## 行为
GIVEN 任何写操作
WHEN Loro commit 并导出 Snapshot
THEN 写入 Loro 文件并更新 SQLite 缓存
