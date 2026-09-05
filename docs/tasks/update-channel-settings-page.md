# 任务：设置页与更新检测

## 任务
为 CardMind 增加最小设置页，并完成正式版/测试版渠道选择、持久化和更新清单检测。此次不实现下载、哈希校验后的安装、Windows 安装器启动或 Android APK 安装。

## 主仓库与 worktree
主仓库路径: D:/Projects/CardMind
实现由 OpenCode 在主仓库内部 `.worktrees/update-channel-settings-page` 执行。

## 改动范围
允许修改：
- `lib/pages/settings_page.dart`（新增）
- `lib/models/update_channel.dart`（新增）
- `lib/models/update_manifest.dart`（新增）
- `lib/services/app_settings_service.dart`（新增）
- `lib/services/update_service.dart`（新增）
- `lib/main.dart`
- `lib/pages/note_list_page.dart`
- `pubspec.yaml` / `pubspec.lock`（仅新增当前功能所需的正式依赖）
- `test/` 中对应单元和 Widget 测试

禁止修改：
- Rust 后端与 `lib/src/rust/`
- `prototype/`
- `.github/workflows/`
- `tool/release/`
- `.gitignore`
- 用户数据、`.env`、已有无关格式改动

## 验收模式
测试模式: 单元 + Widget
浏览器验收模式: 不适用
选择理由与证据边界: 这是 Flutter 原生页面，不是 Web 页面；本轮验证 Flutter Widget 路径和真实清单解析，不宣称真实平台安装完成。
环境前置: `PUB_HOSTED_URL=https://pub.flutter-io.cn`；所有测试命令外层不超过 180 秒。

## 设计契约

### 渠道
- `UpdateChannel.stable` 序列化为 `stable`，展示为“正式版”。
- `UpdateChannel.beta` 序列化为 `beta`，展示为“测试版”。
- 缺失、损坏或非法配置一律回退 `stable`。

### 固定清单地址
- stable: `https://github.com/alexcdever/CardMind/releases/download/channel-stable/stable.json`
- beta: `https://github.com/alexcdever/CardMind/releases/download/channel-beta/beta.json`
- UpdateService 必须根据渠道选择地址；不能请求 GitHub Release 列表并在客户端重建渠道筛选。

### 清单字段
UpdateManifest 至少解析并暴露：`schemaVersion`、`appId`、`channel`、`version`、`build`、`publishedAt`、`minimumSupportedVersion`、`mandatory`、`releaseNotes`、`releasePage` 和当前平台资产。
- `appId` 必须是 `com.cardmind.v2`。
- 请求渠道和清单 `channel` 必须一致。
- `schemaVersion` 只接受 1。
- 下载地址和发布页必须是 HTTPS；本轮不下载。
- 当前平台资产缺失或字段非法时，清单无效。
- `build` 是正整数。

### 设置持久化
- 使用 `path_provider` 的应用支持目录存放配置；不能写安装目录和 Documents。
- 文件名为 `settings.json`。
- 配置结构为 `{ "updateChannel": "stable" }`。
- AppSettingsService 读写渠道，不让页面直接访问文件系统。

### 版本比较
- 以 `build` 作为更新判定主键：目标 build 大于当前 build 才是更新。
- 当前版本从 Flutter 包版本提供；允许注入当前版本和 HTTP 客户端以便测试。
- 不允许把版本字符串按字典序比较。

### 页面
- 新增 `/settings` 路由。
- 从笔记列表页提供设置入口，入口必须有稳定 `ValueKey('open-settings')`。
- 设置页必须有 `ValueKey('settings-page')`、`ValueKey('update-channel-stable')`、`ValueKey('update-channel-beta')`、`ValueKey('check-for-updates')`。
- 默认展示正式版，测试版切换需要确认；取消确认不改变配置。
- 页面展示当前版本、渠道、检查状态、最新版本和更新说明。
- 检测错误只展示错误状态，不阻塞应用启动。
- 本轮“发现更新”只展示，不下载。

## 验收标准（每条 = 一个测试用例）

1. `test/services/app_settings_service_test.dart` — 不存在配置文件时读取 `stable`，并验证写入 JSON 结构。
2. `test/services/app_settings_service_test.dart` — 非法 JSON、非法渠道值读取后回退 `stable`。
3. `test/models/update_manifest_test.dart` — 合法 stable/beta 清单解析成功，三平台资产字段可访问。
4. `test/models/update_manifest_test.dart` — appId、schemaVersion、channel、HTTPS、build、当前平台资产任一非法时拒绝清单。
5. `test/services/update_service_test.dart` — stable 请求固定 stable 地址，beta 请求固定 beta 地址，不请求 Release 列表。
6. `test/services/update_service_test.dart` — 目标 build 大于当前 build 返回 available，目标 build 不大于当前 build 返回 up-to-date。
7. `test/services/update_service_test.dart` — 网络错误和清单错误转换为可展示错误，不抛出到应用启动层。
8. `test/settings_page_test.dart` — 设置页显示当前版本、正式版默认选中和检查更新控件。
9. `test/settings_page_test.dart` — 用户取消测试版确认后渠道不变，确认后持久化 beta 并回显。
10. `test/settings_page_test.dart` — 检查中、已是最新、发现更新、检查失败四种状态均有对应文本/控件。
11. `test/settings_page_test.dart` — NoteListPage 的 `open-settings` 入口可以导航到 `settings-page`，且已有笔记列表行为不回归。
12. `test/release_workflow_test.dart` — 更新现有 workflow 断言以匹配已经提交的 metadata job、stable/beta tag 和 manifest 资产；不得把测试改回旧的开发发布契约。

## 需决策点
- 如果现有页面布局无法提供入口而需要改变既有导航结构，停下报告，不扩大到全局导航重构。
- 如果 Flutter 的版本字符串无法通过当前依赖可靠取得，停下报告，不硬编码一个会随发布漂移的版本。
- 不得用 mock 清单替代 UpdateService 的真实 JSON 解析；HTTP 传输可注入窄适配器。
