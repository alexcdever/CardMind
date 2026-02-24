# Card 规格

## 行为
GIVEN 用户创建/更新/删除卡片
WHEN Loro commit 完成
THEN SQLite 缓存更新且后续读取仅走 SQLite

GIVEN 用户按关键字搜索
WHEN 发起搜索请求
THEN SQLite 使用 LIKE 查询标题与正文并返回分页结果

GIVEN 已存在本地笔记
WHEN 用户更新标题或正文并保存
THEN Loro 写入并触发 SQLite 缓存更新
