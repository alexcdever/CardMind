# CardMind NSH 编辑器 — Windows 真机验证清单（待 Windows 真机）

> 状态：**待 Windows 真机执行**。本清单为 AC4 交付物，提供可复现的
> PowerShell 脚本 + 手工核对项。本机（macOS）无法覆盖真实 Windows
> 窗口、微软拼音 IME、与 Win32 选区/光标行为。

## 历史证据与适用范围（重要）

- **WebView + Tiptap 时代（旧编辑器）**：Windows 中文 IME 已实测通过 ——
  `docs/migration-nsh-verification.md` **§V8（R10）**：用 WebView2 CDP
  `Input.imeSetComposition` 走 Chromium 真实输入管线，`compositionstart →
  update×7 → compositionend`，「你好」入文、光标 `from:3`、markdown 一致。
- **NSH 0.3.0 原生 `Editor`（当前编辑器，P2 起）**：输入栈已从「浏览器 IME」
  换成「平台 input sink（Windows TSF）」，V8 证据**不能直接迁移**。
  `docs/research/nsh-editor/05-editor-doc-api.md` 记录：`nsh test` 没有
  composition step，真实 IME 只能 Windows 窗口人工验证；sink 有
  `on_composition_change`（`view.rs:1260`）、`EditorClasses.composition`
  （`base.d.ts:658-659`），**机制具备但无真机证据**。
- 因此本清单针对的是**当前原生 Editor**：需要在 Windows 上按下面 A/B/C 重新
  走一遍，不能拿旧 WebView 的 V8 结论替代。

## 前置

- Windows 10/11 + 微软拼音输入法（默认中文 IME）。
- CardMind 已按 `nsh package --target windows` 产物或开发态
  `nsh run --target windows` 启动，进入「笔记」→ 任一笔记的 Markdown 编辑器。
- **打包必须在 Windows 上做**：macOS 上 `nsh package . --target windows` 会
  exit 0 并产出 `.nsh/out/cardmind/cardmind.exe`，但该文件实际是 macOS
  Mach-O arm64 可执行（运行时打印 `nsh-windows-app is the executable of
  packaged Windows apps; build it on Windows` 并 exit 1），**不是可装的
  Windows 程序**。不要拿 macOS 产物到 Windows 上用；在 Windows 上重新
  `nsh package . --target windows`。
- 剪贴板 capability 已在 `nsh-app/nsh.json` 声明 `"clipboard": true`。

## A. 中文 IME（微软拼音）

| # | 步骤 | 预期 |
|---|------|------|
| A1 | 编辑器内切到微软拼音，输入 `nihao` | 组合串（preedit）在光标处带下划线/高亮显示，不立即上屏 |
| A2 | 按空格/数字键选「你好」上屏 | 「你好」替换组合串落到文档，光标紧跟其后 |
| A3 | 连续输入一段中文（≥50 字），中间用退格改组合 | 组合与已上屏文本一致，无错位/丢字 |
| A4 | 组合中按 Esc | 取消本次组合，已上屏文本不变，编辑器不退出 |
| A5 | 输入中英混排 + 标点 `，` `。` `「」` | 标点按 IME 规则上屏，光标位置正确 |
| A6 | 输入一段中文后 `Ctrl+Z` 撤销 / `Ctrl+Y` 重做 | 撤销回到上一步；undo 不跨「已上屏 vs 组合中」边界错乱 |

## B. 5 万字文档

| # | 步骤 | 预期 |
|---|------|------|
| B1 | 打开一篇约 50,000 字 Markdown（含标题/列表/引用/代码块/wikilink/中文） | 编辑器可滚动、可编辑，无明显卡死 |
| B2 | 在文档中部连续输入中文 200 字 | 每次按键到上屏的延迟可接受（无明显逐字卡顿） |
| B3 | 点「预览」切到 TextView | 预览渲染完整（标题/列表/引用/代码/wikilink chip），首屏可见；记录打开耗时（见 D 节脚本） |
| B4 | 预览态滚动到底部再切回「编辑」 | 源码逐字节不变（对照 git diff / 文件长度），光标/选区位置合理 |

## C. 复制粘贴（clipboard capability）

| # | 步骤 | 预期 |
|---|------|------|
| C1 | 选中一段文本 `Ctrl+C` → 移动光标 `Ctrl+V` | 粘贴到光标处，内容一致 |
| C2 | 跨应用复制（从浏览器/记事本）粘贴进编辑器 | 纯文本正常进入，无乱码 |
| C3 | 编辑器内 `Ctrl+A` `Ctrl+C`，粘贴到外部应用 | 全文一致（5 万字文档注意确认无截断） |

## D. PowerShell 复现脚本

> 用途：**样本生成 + 手工清单辅助**——生成约 5 万字 Markdown 测试笔记到
> `%TEMP%\cardmind-big-note.md`，并可选跑一遍 headless `nsh test` 做对照；
> 不做应用启动/注入/自动计时（启动与预览计时按 B/D 清单手工执行，或用
> §E 的 `nsh test --filter "5 万字" --target windows` 复测）。
> 保存为 `nsh-p4-windows-probe.ps1`，**放在 `nsh-app/` 目录下**执行：
> `powershell -ExecutionPolicy Bypass -File nsh-p4-windows-probe.ps1`
> （脚本经 `$PSScriptRoot` 定位到 nsh-app/）。

```powershell
# nsh-p4-windows-probe.ps1  — CardMind NSH 编辑器 Windows 真机探针
$ErrorActionPreference = "Stop"
$AppDir = "$PSScriptRoot"          # 假定脚本放在 nsh-app/ 下
Set-Location $AppDir

# 0) 依赖检查
foreach ($c in @("nsh","cargo")) {
  if (-not (Get-Command $c -ErrorAction SilentlyContinue)) {
    Write-Error "缺少命令：$c（cargo 需在 %USERPROFILE%\.cargo\bin）"
  }
}

# 1) 生成 ~50,000 字 Markdown 测试笔记
$big = New-Object System.Text.StringBuilder
$i = 0
while ($big.Length -lt 50000) {
  $i++
  [void]$big.AppendLine("# 第 $i 节 标题")
  [void]$big.AppendLine("")
  [void]$big.AppendLine("正文段落，含 [[note-$i|别名$i]] 与普通文本，中文填充以达五万字量级。")
  [void]$big.AppendLine("- 列表项一")
  [void]$big.AppendLine("- 列表项二")
  [void]$big.AppendLine("> 引用一句话，来自第 $i 节。")
  [void]$big.AppendLine('```')
  [void]$big.AppendLine("const x$i = $i;")
  [void]$big.AppendLine('```')
  [void]$big.AppendLine("")
}
$bigText = $big.ToString()
$probe = Join-Path $env:TEMP "cardmind-big-note.md"
[IO.File]::WriteAllText($probe, $bigText, [Text.UTF8Encoding]::new($false))
Write-Host ("生成测试笔记：{0}，{1} 字" -f $probe, $bigText.Length)

# 2) 启动应用（开发态）。打包态：改为启动安装后的 CardMind.exe。
Write-Host "启动 CardMind（Ctrl+C 结束）……"
Write-Host "手工步骤：进任意笔记 → 按 B/D 清单做 IME/预览/粘贴核对。"
Write-Host "预览打开耗时请用秒表或本机 nsh test --target windows 复测。"

# 3) 可选：自动跑一遍 headless 行为测试对照（不含真 IME）。
nsh test --filter "editor"
```

## E. 真机复测建议（预览耗时）

- 首选：`cd nsh-app && nsh test --filter "5 万字" --target windows`（让同一
  测量跑在 Windows 开发宿主上，对比 headless 的 p50/p95）。
- 或手工秒表：B3 步骤计时「点预览 → 首屏渲染稳定」。

## 记录

执行后把结果填回 `docs/progress-nsh-editor-2026-11-03.md` 的 P4 小节：
实测机器（CPU/内存/Windows 版本）、A/B/C 各项 通过/不通过 + 备注、预览耗时。

## F. macOS 预验证（2026-11-05，**非 Windows/真机替代**）

在 macOS（Apple M2，macOS 27.0.1）用 `nsh test --target macos` 在真 AppKit 窗口跑了同一套测试，作为 Windows/真机的前置信号。它只证明**原生 Editor 在真窗口的输入/渲染/性能路径可用**，不能替代 Windows IME 与移动软键盘验收。

| 项 | macOS 真窗口结果 |
|---|---|
| 编辑器行为套件（28 条） | **23 passed / 5 failed**。5 条失败均为**真窗口测试 API 限制**，非产品缺陷：3 条 `app.back()` 在桌面宿主不导航（`id:notes-stub` 未出现）；1 条 `app.spanStyle` 明确 headless-only；1 条 TextView 自定义节点（wikilink chip）的 `testID` 在真窗口不可查（chip 已渲染为 `￼`）。 |
| CJK 文本输入 | ✅ `app.type("中文输入")` 入文 |
| 从系统剪贴板粘贴 | ✅ `mod+v` 后编辑器内容含 shell `pbcopy` 的文本 |
| 复制回系统剪贴板 | ⚠️ `mod+a` + `mod+c` 后 `pbpaste` 仍是旧内容 → 未生效/未验证（可能是真机快捷键输入路径限制，需人工复核） |
| 5 万字预览切换（真实窗口） | `[perf] 50148 chars, n=20: min=2527ms p50=2749ms p95=2765ms max=2972ms`；压力渲染时 `items≈8000+`、`mem≈250MB`、`frame≈500–700ms`、`over≈50–60%` → 5 万字真窗口渲染成本偏高，**需 Windows 对比后再决定是否调 `PREVIEW_DEBOUNCE_MS` 或分块渲染**。 |
| 真实 IME 组合 | ❌ 无法自动：`nsh test` 无 composition step；macOS 辅助功能未授权，无法用 System Events 驱动拼音。仍需人工用系统输入法验证（Windows TSF / macOS IMK 各一遍）。 |

> `--fps` 的稳态读数在窗口被遮挡时会被 macOS 节流（出现 `fps 0/60`、`items 2`），不作为结论；上表的 5 万字数字取自编辑器套件里的真实渲染用例。

复现（会开真窗口，属显式授权场景）：

```
cd nsh-app && CARGO_TARGET_DIR=<主树 target> nsh test --target macos --filter editor --fps -v
```
