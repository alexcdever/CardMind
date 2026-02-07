# Feature Specs Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 `docs/specs/features/` 重构为纯业务功能层，按 `card/`、`pool/`、`settings/` 三模块组织，并把 UI 内容迁回 `docs/specs/ui/`。

**Architecture:** 功能规格仅依赖领域与架构层（`docs/specs/domain/`、`docs/specs/architecture/`），禁止引用 UI；UI 规格保留在 `docs/specs/ui/`，以现有 UI 文档为主进行合并补齐。

**Tech Stack:** Markdown（UTF-8 / LF）、rg、git

---

### Task 1: 建立新功能目录与 README 骨架

**Files:**
- Create: `docs/specs/features/card/README.md`
- Create: `docs/specs/features/pool/README.md`
- Create: `docs/specs/features/settings/README.md`

**Step 1: 写“结构校验”命令（预期失败）**

Run: `test -d docs/specs/features/card`
Expected: 退出码非 0（目录尚不存在）

**Step 2: 创建目录与 README 骨架**

README 结构示例（每个模块一致）：

```markdown
# Card 功能规格

**范围**: 卡片增删改查与搜索过滤
**依赖**: `docs/specs/domain/card.md`, `docs/specs/architecture/storage/card_store.md`, `docs/specs/architecture/storage/dual_layer.md`

---

- 本模块仅描述业务能力与约束
- 禁止引用 UI 规格
```

**Step 3: 重新验证结构（预期成功）**

Run: `test -d docs/specs/features/card && test -d docs/specs/features/pool && test -d docs/specs/features/settings`
Expected: 退出码 0

**Step 4: Commit**

```bash
git add docs/specs/features/*/README.md
git commit -m "docs: add feature module readmes"
```

---

### Task 2: 迁移并编写 Card 业务规格

**Files:**
- Create: `docs/specs/features/card/creation.md`
- Create: `docs/specs/features/card/viewing.md`
- Create: `docs/specs/features/card/editing.md`
- Create: `docs/specs/features/card/tags.md`
- Create: `docs/specs/features/card/deletion.md`
- Create: `docs/specs/features/card/list_search_filter.md`
- Source: `docs/specs/features/card_management/spec.md`
- Source: `docs/specs/features/search_and_filter/spec.md`

**Step 1: 写“UI 关键词”校验命令（预期失败）**

Run: `rg -n "Flutter|Widget|ListView|屏幕|移动端|桌面端|手势|FAB" docs/specs/features`
Expected: 有匹配（旧 features 仍包含 UI 术语）

**Step 2: 编写 Card 规格文件（仅业务）**

每个文件统一模板（示例）：

```markdown
# 卡片创建规格

**状态**: 活跃
**依赖**: [../../domain/card.md](../../domain/card.md), [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md)
**相关测试**: `test/feature/features/card_management_feature_test.dart`

---

## 概述
说明该业务能力的目的与范围。

## 需求：卡片创建
### 场景：创建成功
- 前置条件：已加入数据池
- 操作：提交标题与内容
- 预期结果：创建卡片（UUID v7）
- 并且：自动关联当前池
- 并且：记录创建时间戳

### 场景：标题为空拒绝
...
```

内容来源与覆盖要点：
- `creation.md`: 标题必填、内容必填且不可为空或仅空白、未入池拒绝。
- `viewing.md`: 标题/内容/时间戳/标签/最后编辑设备。
- `editing.md`: 更新标题/内容/时间戳/设备，变更需同步；拒绝空标题与空内容。
- `tags.md`: 新增/移除、去重、区分大小写、同步。
- `deletion.md`: 确认后软删除、可查询已删除、同步。
- `list_search_filter.md`:  
  - 条件为空 → 返回 `deleted=false` 全量  
  - 条件不为空 → 叠加过滤  
  - 默认按 `updated_at` 倒序  
  - 分页/加载交给 UI 规格

**Step 3: 重新运行 UI 关键词校验（预期仍有匹配）**

Run: `rg -n "Flutter|Widget|ListView|屏幕|移动端|桌面端|手势|FAB" docs/specs/features`
Expected: 仍有匹配（旧 features 仍未清理）

**Step 4: Commit**

```bash
git add docs/specs/features/card/*.md
git commit -m "docs: add card feature specs"
```

---

### Task 3: 迁移并编写 Pool 业务规格

**Files:**
- Create: `docs/specs/features/pool/creation.md`
- Create: `docs/specs/features/pool/joining.md`
- Create: `docs/specs/features/pool/single_pool_constraint.md`
- Create: `docs/specs/features/pool/info_view.md`
- Create: `docs/specs/features/pool/members.md`
- Create: `docs/specs/features/pool/settings.md`
- Create: `docs/specs/features/pool/leaving.md`
- Create: `docs/specs/features/pool/discovery.md`
- Create: `docs/specs/features/pool/auth_security.md`
- Create: `docs/specs/features/pool/sync.md`
- Source: `docs/specs/features/pool_management/spec.md`
- Source: `docs/specs/features/p2p_sync/spec.md`

**Step 1: 写“引用范围”校验命令（预期失败）**

Run: `rg -n "docs/specs/ui" docs/specs/features -g "*.md"`
Expected: 有匹配（旧 features 可能引用 UI）

**Step 2: 编写 Pool 规格文件（仅业务）**

要点清单：
- `creation.md`: 名称必填、密钥≥6、UUID v7、bcrypt 哈希、创建后自动加入并触发同步。
- `joining.md`: 池 ID + 密钥校验、池存在性校验、错误处理。
- `single_pool_constraint.md`: 单设备仅可加入一个池。
- `info_view.md`: 名称/ID/创建时间/设备数/卡片数。
- `members.md`: 设备列表、在线状态、当前设备标记、成员增删。
- `settings.md`: 更新名称、更新密钥（需验证旧密钥）、变更需同步。
- `leaving.md`: 仅清理本地属于该池的数据；本地独立数据保留；清除设备配置池 ID。
- `discovery.md`: 仅二维码组池；同局域网；加入后 mDNS 广播与发现。
- `auth_security.md`: 池 ID + 池密钥；libp2p 公私钥对白名单验证。
- `sync.md`: 加入池即启动；增量/全量；版本追踪；冲突自动合并；失败可重试。

模板同 Task 2（状态/依赖/相关测试/场景）。

**Step 3: 重新运行引用范围校验（预期仍有匹配）**

Run: `rg -n "docs/specs/ui" docs/specs/features -g "*.md"`
Expected: 仍有匹配（旧 features 仍未清理）

**Step 4: Commit**

```bash
git add docs/specs/features/pool/*.md
git commit -m "docs: add pool feature specs"
```

---

### Task 4: 迁移并编写 Settings 业务规格

**Files:**
- Create: `docs/specs/features/settings/device.md`
- Create: `docs/specs/features/settings/appearance.md`
- Create: `docs/specs/features/settings/data_management.md`
- Create: `docs/specs/features/settings/app_info.md`
- Source: `docs/specs/features/settings/spec.md`

**Step 1: 写“UI 关键词”校验命令（预期失败）**

Run: `rg -n "Widget|屏幕|组件|布局" docs/specs/features/settings -g "*.md"`
Expected: 有匹配（旧 spec 尚未迁移）

**Step 2: 编写 Settings 规格文件（仅业务）**

要点清单：
- `device.md`: 设备名称/ID/类型查看与修改；名称必填；变更需同步与持久化。
- `appearance.md`: 主题模式与文本大小；即时生效与持久化。
- `data_management.md`: 存储占用；清理缓存不清用户数据；导入/导出（JSON）。
- `app_info.md`: 版本/构建号/发布日期；开源库清单（Flutter 与 Rust 分列）。

**Step 3: 重新运行 UI 关键词校验（预期可能仍有匹配）**

Run: `rg -n "Widget|屏幕|组件|布局" docs/specs/features/settings -g "*.md"`
Expected: 仍可能有匹配（旧 features 仍未清理）

**Step 4: Commit**

```bash
git add docs/specs/features/settings/*.md
git commit -m "docs: add settings feature specs"
```

---

### Task 5: 合并 UI 规格（以 UI 版本为主）

**Files (示例映射):**
- `docs/specs/features/card_detail/card_detail_screen.md` → `docs/specs/ui/screens/mobile/card_detail_screen.md`
- `docs/specs/features/card_list/card_list_item.md` → `docs/specs/ui/components/mobile/card_list_item.md` + `docs/specs/ui/components/desktop/card_list_item.md`
- `docs/specs/features/card_list/note_card.md` + `docs/specs/features/card_editor/note_card.md` → `docs/specs/ui/components/shared/note_card.md`
- `docs/specs/features/card_list/note_editor_fullscreen.md` + `docs/specs/features/card_editor/fullscreen_editor.md` → `docs/specs/ui/components/shared/fullscreen_editor.md`
- `docs/specs/features/card_editor/*` → `docs/specs/ui/screens/*/card_editor_screen.md` 或 `docs/specs/ui/components/*`
- `docs/specs/features/settings/settings_screen.md` → `docs/specs/ui/screens/*/settings_screen.md`
- `docs/specs/features/settings/settings_panel.md` → `docs/specs/ui/components/shared/settings_panel.md`
- `docs/specs/features/settings/device_manager_panel.md` → `docs/specs/ui/components/shared/device_manager_panel.md`
- `docs/specs/features/home_screen/*` → `docs/specs/ui/screens/*/home_screen.md`
- `docs/specs/features/navigation/*` → `docs/specs/ui/components/mobile/mobile_nav.md` 或 `docs/specs/ui/components/desktop/desktop_nav.md`
- `docs/specs/features/context_menu/desktop.md` → `docs/specs/ui/components/desktop/context_menu.md`
- `docs/specs/features/toolbar/desktop.md` → `docs/specs/ui/components/desktop/toolbar.md`
- `docs/specs/features/fab/mobile.md` → `docs/specs/ui/components/mobile/fab.md`
- `docs/specs/features/gestures/mobile.md` → `docs/specs/ui/components/mobile/gestures.md`
- `docs/specs/features/sync_feedback/*` → `docs/specs/ui/components/shared/sync_status_indicator.md` 或 `docs/specs/ui/components/shared/sync_details_dialog.md`
- `docs/specs/features/sync/sync_screen.md` → `docs/specs/ui/screens/mobile/sync_screen.md`
- `docs/specs/features/onboarding/shared.md` → `docs/specs/ui/screens/shared/onboarding_screen.md`

**Step 1: 为每个映射项建立“合并清单”**

Run: `rg --files docs/specs/features`
Expected: 列出待合并文件，逐个对照 UI 现有文档

**Step 2: 逐个合并（UI 为主）**

合并规则：
- 保留 UI 文档结构与平台差异。
- 从 features 文档补充缺失的交互/状态描述。
- 不引入业务规则（业务已迁入 features）。
- 若无 UI 对应文档：暂停并与用户确认后再新建。

**Step 3: 删除已合并的旧 features UI 文档**

Run: `git rm <旧 features UI 文件>`

**Step 4: Commit**

```bash
git add docs/specs/ui
git add docs/specs/features
git commit -m "docs: merge ui specs and remove old feature ui docs"
```

---

### Task 6: 清理旧 features 目录

**Files:**
- Delete: `docs/specs/features/*`（旧目录全量）

**Step 1: 删除旧目录（不保留指向）**

Run: `git rm -r docs/specs/features`

**Step 2: 重新添加新 features 目录**

Run: `git add docs/specs/features/card docs/specs/features/pool docs/specs/features/settings`

**Step 3: Commit**

```bash
git commit -m "docs: replace legacy features with new modules"
```

---

### Task 7: 更新索引与全局说明

**Files:**
- Modify: `docs/specs/README.md`

**Step 1: 先运行索引检查（预期失败）**

Run: `rg -n "features/" docs/specs/README.md`
Expected: 仍指向旧结构

**Step 2: 更新功能索引**

更新为：
- `features/card/`、`features/pool/`、`features/settings/` 及其概要
- 重新统计数量（若需要）

**Step 3: 重新运行索引检查（预期成功）**

Run: `rg -n "features/card|features/pool|features/settings" docs/specs/README.md`
Expected: 匹配新结构

**Step 4: Commit**

```bash
git add docs/specs/README.md
git commit -m "docs: update specs index for new feature modules"
```

---

### Task 8: 终检（规格一致性）

**Files:**
- Check: `docs/specs/features/**`
- Check: `docs/specs/ui/**`

**Step 1: 禁止 UI 引用检查**

Run: `rg -n "docs/specs/ui" docs/specs/features -g "*.md"`
Expected: 无匹配

**Step 2: UI 关键词清理检查**

Run: `rg -n "Flutter|Widget|ListView|屏幕|移动端|桌面端|手势|FAB" docs/specs/features -g "*.md"`
Expected: 无匹配

**Step 3: 旧目录清理确认**

Run: `test ! -d docs/specs/features/card_list && test ! -d docs/specs/features/card_editor`
Expected: 退出码 0

**Step 4: 最终 Commit**

```bash
git add docs/specs/features docs/specs/ui docs/specs/README.md
git commit -m "docs: finalize feature specs refactor"
```
