

**范围：**
- 保持现有文件头与绝对路径校验逻辑不变。

**行为：**
- 对每个 `relativePath`：
  - 计算 `dirPath` 与 `fileName`。

**数据流：**
- `check()` 遍历 `changedFiles`，对每个文件追加校验结果。

**错误处理：**
- 不抛异常，仅聚合错误到 `FractalDocCheckResult.errors`。

**测试：**
- 按计划先失败、再实现、再通过。
