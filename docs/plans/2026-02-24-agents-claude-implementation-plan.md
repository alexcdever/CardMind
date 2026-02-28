input: Agents/Claude 文档目标、结构与实施任务
output: 可执行的文档编写与验证步骤
pos: Agents/Claude 文档实施计划（修改需同步 DIR.md）
# Agents/Claude 文档 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 生成中文 `AGENTS.md` 贡献指南，并新增 `CLAUDE.md` 指向该指南。

**Architecture:** 仅新增/更新文本文档，不改动代码或配置；内容完全基于仓库现有结构与工具链。

**Tech Stack:** Markdown, Flutter, Rust, flutter_rust_bridge

## 强制执行规则（TDD 红-绿-蓝）

- 本计划每个任务必须按 **Red -> Green -> Blue -> Commit** 执行。
- Red：先编写或调整失败测试，并运行确认按预期失败。
- Green：以最小实现使测试通过，并运行确认通过。
- Blue：在不改变行为前提下重构，复跑同一批测试后再继续。
- 仅当 Blue 阶段验证通过后才允许提交。

---

### Task 1: 起草 AGENTS.md 内容

**Files:**
- Create: `AGENTS.md`

**Step 1: 写入初稿**
- 按设计结构填充中文内容，包含必需章节与示例命令。
- 控制在约 200-400 字/词的简洁范围。

**Step 2: 校验长度与章节**
Run: `python - <<'PY'\nimport re\np='AGENTS.md'\ntext=open(p,'r',encoding='utf-8').read()\n# 粗略统计：中文字符 + 英文单词\ncn=len(re.findall(r'[\u4e00-\u9fff]', text))\nwords=len(re.findall(r'[A-Za-z0-9_]+', text))\nprint('cn_chars=', cn, 'en_words=', words)\nPY`
Expected: `cn_chars` 在合理范围（约 200-400），章节齐全。

**Step 3: 提交前自查**
- 确认路径示例与命令来自现有仓库结构。
- 确认标题为 `Repository Guidelines`。

### Task 2: 新增 CLAUDE.md 指向

**Files:**
- Create: `CLAUDE.md`

**Step 1: 写入内容**
- 使用简短标题与一句说明，指向 `AGENTS.md`。

**Step 2: 校验链接**
Run: `rg -n "AGENTS.md" CLAUDE.md`
Expected: 匹配到指向 `AGENTS.md` 的链接。

### Task 3: 运行验证

**Files:**
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

**Step 1: 运行测试**
Run: `flutter test`
Expected: `All tests passed!`

### Task 4: 提交变更

**Files:**
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

**Step 1: 查看变更**
Run: `git status -sb`
Expected: 仅包含 `AGENTS.md` 与 `CLAUDE.md`

**Step 2: 提交**
Run:
```bash
git add AGENTS.md CLAUDE.md
git commit -m "docs: add repository guidelines and claude pointer"
```
Expected: commit 成功
