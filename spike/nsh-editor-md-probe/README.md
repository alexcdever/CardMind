# NSH 0.3.0 Editor + TextView 探针（spike）

task-5 的本机探针：验证已发布的 **nsh 0.3.0**（`C:\Users\alexc\scoop\apps\nsh\0.3.0\bin\nsh.exe`，`nsh 0.3.0 (76fa8a7)`）的：

- `Editor`（`language="markdown"` 的语法高亮、`[[` 补全、`EditorRef` 方法、5 万字性能、撤销）；
- `TextView`（Markdown 预览、链接事件）；
- 真实 Windows 窗口渲染（scoop 安装自带 `runtime/windows`，无需 cargo 构建 host）。

结论与 API 细节见 `docs/research/nsh-editor/05-editor-doc-api.md`。

## 目录

| 路径 | 用途 |
|---|---|
| `App.tsx` | 主探针：Editor + TextView 双栏、`[[` 补全（`completionTriggerCharacters: ["[["]`）、Perf 50k、撤销、预览开关 |
| `App.test.tsx` | 8 个 headless 测试（`nsh test`），全部通过 |
| `Visual.tsx` | 截图用入口：TextView 预览 + Editor + 自动触发 `[[` 候选列表 |
| `logs/` | 每次命令的原始输出与窗口截图 |
| `logs/capture.ps1` | 枚举 `NshWindow`、调整窗口、PrintWindow 截图的小脚本 |
| `logs/window-initial.png` | 真实窗口：Markdown 语法高亮（标题/列表/表格/rust 代码着色） |
| `logs/window-visual2.png` | 真实窗口：TextView 预览 + Editor + `[[` 候选列表（会议记录 / 项目计划 / Weekly Buffer） |

## 实测结果（2026-11-02，全部 exit 0）

| 步骤 | 命令 | 结果 |
|---|---|---|
| 类型检查 | `nsh check .` | exit 0 |
| 打包 | `nsh build .` | exit 0：9.5 KB js + 31.2 KB bytecode，9 ms |
| headless 测试 | `nsh test . -v` | exit 0：**8 tests: 8 passed**（3.2 s）；App bundle 9762 B / 5.1 ms |
| 50k 字符 | 测试内 `editor.setValue(BIG)` + `await editor.value()` | `perf: set=0ms read=8ms len=50007 same=yes`（测试整体 309 ms） |
| 真实窗口 | `nsh run Visual.tsx --target windows` | 窗口标题 `nsh`（类 `NshWindow`），零 cargo 构建；截图见上 |
| 撤销 | 键盘输入 xyz → `mod+z` | 长度回到输入前（测试通过） |
| `[[` 补全 | 键盘输入 `[` `[` → 列表 → Enter | 触发 `trigger=character char="[[" q=""`；接受后文本含 `[[会议记录]]` |
| TextView | headless + 窗口截图 | 标题/列表/表格/代码块渲染正常；`onLinkPress` 报告 `https://nsh.dev` |

## 关键注意点（详见报告）

1. **补全答案要异步呈现**：在 `onCompletionRequest` 里同步调 `presentCompletions` 会被丢弃（0.3.0 内部检查 focused/版本），`setTimeout(…, 60)` 后正常；LSP 式异步回答天然满足。
2. **`autoClose` 默认会把行尾 `[` 补成 `[]`**：行尾连打两个 `[` 得到 `[[]]`（触发仍会报 `[[`，但接受后结构错误）。Markdown 源模式建议 `autoClose={false}`（本探针已设）。
3. **补全 query 不能含空格**：0.3.0 的 completion session 只允许 query 由 word 字符组成（`completion.rs` `holds`），标题带空格（如 `[[My Note`）会关闭列表 → 需要自绘弹层（`onSelectionChange` + `caretBounds` + `ref.insert`）。
4. **`nsh test` 的 `app.type` 覆盖不到补全的键盘路径**：`app.keyboard.press("[")` 可以；`app.type` 会发请求但列表不出现（真实窗口正常）。写测试时用 `keyboard.press`。
5. **headless 测不了真实 IME**：0.3.0 的 `nsh/test` 没有 composition step；只能验证 CJK 字符经平台输入写入（`app.type(...,"中文输入")` 通过）。真实输入法需 Windows 窗口人工验证。
6. nsh.dev 文档跟 `main`：0.3.0 类型里没有 `gutterDecorationsWidth` / `overviewRuler` 装饰（docs 有），不要照文档用。

## 运行

```powershell
$nsh = 'C:\Users\alexc\scoop\apps\nsh\0.3.0\bin\nsh.exe'
cd D:\Projects\CardMind\spike\nsh-editor-md-probe
& $nsh check .
& $nsh build .
& $nsh test . -v
# 真实窗口（可选，需桌面会话）
& $nsh run Visual.tsx --target windows
# 截图
powershell -File .\logs\capture.ps1 -Out .\logs\window.png
```
