# ADR 0001 — Note 数据容器 v1→v2 迁移

- **日期**：2026-08-12
- **状态**：提议中
- **决策者**：@alexc

---

## 背景

CardMind 当前存储格式（v1）中，每篇 Note 的 LoroDoc 容器结构为：

```
NoteCrdt {
    doc.get_text("content")       → Markdown 正文
    // 标签以 HTML 注释嵌入正文: <!--tags:tag1,tag2-->
    // 标题通过首行提取（去除 # 前缀）
}
```

快照文件 `cardmind.loro` 以 `LORO_VERSION=1` 标识。

二期产品定义升级为分布式个人知识库，核心变更：
1. 标签从正文提取变为独立元数据存储
2. 新增 created_at、updated_at 时间戳字段
3. 正文中不再嵌入标签注释

容器结构需升级为 v2：

```
NoteCrdt {
    doc.get_text("content")       → Markdown 正文（不再含 <!--tags:...-->）
    doc.get_map("meta")           → {
        tags: ["tag1", "tag2"],
        created_at: "2026-08-12T00:00:00+08:00",
        updated_at: "2026-08-12T00:00:00+08:00"
    }
}
```

## 决策

**升级 `LORO_VERSION` 从 1 → 2，并在打开 v1 文件时执行一次性自动迁移。**

## 迁移逻辑

打开 `cardmind.loro` 时读取 LORO_VERSION：
- **版本 = 1**：对每条 Note 执行迁移——
  1. 从正文中提取 `<!--tags:tag1,tag2-->`，写入 Map `meta.tags`
  2. 若正文无标签注释，tags 设为空数组
  3. 从正文中去除标签注释行
  4. 设置 `meta.created_at` = 当前时间（v1 数据无历史创建时间）
  5. 设置 `meta.updated_at` = 当前时间
  6. 以 v2 格式写回 `cardmind.loro`
- **版本 = 2**：直接加载，无需迁移

迁移后 Bump 版本号到 `LORO_VERSION=2`。

## 拒绝的方案

### 方案 B：不 bump 版本号，静默兼容

- 新字段不存在时使用默认空值
- 旧数据正文中标签注释不清理

**拒绝理由**：正文长期携带过期注释，后续解析需要双重逻辑（正文提取 + Map 读取），增加维护负担。一次迁移永久解决。

### 方案 C：完全重写存储格式

**拒绝理由**：没有充分理由放弃 LoroDoc 快照格式。现有 `CARDMIND` magic + 版本号的封包格式足够清晰。

## 后果

- **正向**：正文纯净，标签存储结构化为数组，后续链接解析不需要跳过标签注释
- **负向**：v1 数据的创建时间会丢失（设为迁移时间），但用户可接受——v1 数据量小且多是开发测试数据
- **风险**：迁移过程若中断，`cardmind.loro` 可能损坏。缓解：迁移前备份原文件为 `cardmind.loro.v1.bak`
