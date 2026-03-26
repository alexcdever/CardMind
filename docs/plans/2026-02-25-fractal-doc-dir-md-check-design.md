# 分形文档 DIR.md 检查设计

**目标：** 对每个变更文件，校验同目录 `DIR.md` 是否包含该文件名条目；不存在或未包含则报错。

**范围：**
- 仅新增最小 `DIR.md` 条目校验，不做排除项或复杂解析。
- 保持现有文件头与绝对路径校验逻辑不变。

**行为：**
- 对每个 `relativePath`：
  - 计算 `dirPath` 与 `fileName`。
  - 若 `dirPath/DIR.md` 不存在或内容不包含 `fileName`，返回错误 `DIR.md missing entry: <relativePath>`。

**数据流：**
- `check()` 遍历 `changedFiles`，对每个文件追加校验结果。
- `_dirHasEntry()` 读取 `DIR.md` 全文并用 `contains` 判断。

**错误处理：**
- 不抛异常，仅聚合错误到 `FractalDocCheckResult.errors`。

**测试：**
- 新增用例：`DIR.md` 存在但不包含条目时应失败。
- 按计划先失败、再实现、再通过。
