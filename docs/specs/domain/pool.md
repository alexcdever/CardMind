# Pool 规格

## 行为
GIVEN 数据池元数据保存在 Loro 文档
WHEN 本地写入/更新元数据
THEN SQLite 缓存同步更新

GIVEN 本地已有笔记且未加入池
WHEN 加入池并确认加入
THEN 所有本地笔记 id 写入池元数据 card_ids
