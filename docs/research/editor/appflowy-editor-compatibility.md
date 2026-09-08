# AppFlowy Editor 兼容性与依赖决策

## 当前结论

CardMind 当前使用 AppFlowy Editor 官方 Git 仓库的固定提交，而不是浮动分支或本机 Pub Cache 手工补丁：

```yaml
appflowy_editor:
  git:
    url: https://github.com/AppFlowy-IO/appflowy-editor.git
    ref: 01eccc6ee36bd07698bd80915289fe7070478cd2
```

当前项目配置和锁文件优先于本文。本文用于记录为什么采用固定提交，以及未来复核依赖时需要检查什么。

## 兼容性问题

AppFlowy Editor 的正式 pub.dev 版本目前仍为 `6.2.0`。其官方包环境约束为 Dart `>=3.6.0 <4.0.0`、Flutter `>=3.32.0`。CardMind 使用 Flutter 3.44 系列和 Dart 3.12 系列。

CardMind 曾遇到 `DeltaTextInputService` 缺少 `TextInputClient.onFocusReceived` 导致 Android/Windows 构建失败的问题。官方固定提交 `01eccc6ee36bd07698bd80915289fe7070478cd2` 包含该兼容实现，并且还包含后续编辑器修复；使用完整 SHA 可避免依赖上游未来变化。

不要把本机 Pub Cache 中的手工修改视为依赖来源。干净环境必须能够通过同一 Git 提交恢复源码并完成构建。

## 复核规则

1. 先读 `pubspec.yaml` 和 `pubspec.lock`，确认 Git URL、完整 SHA 和锁定 resolved-ref 一致。
2. 用官方 GitHub 提交页核对该 SHA 是否仍可访问。
3. 检查实际 checkout 中的 `delta_input_service.dart` 是否包含 `onFocusReceived` 实现。
4. 在干净依赖缓存中运行 Flutter analyze、Flutter 测试、Windows release 构建和 Android release 构建。
5. 若未来切换回正式 pub.dev 包，必须重新验证中文输入、Markdown 往返、链接补全、selection/transaction、自动保存及 Android/Windows 构建，不能只依据版本号判断兼容。

## 关联任务

- `docs/task-u4-appflowy-main-local-validation.md`：固定提交的验证任务记录。
- `pubspec.yaml`：当前依赖声明。
- `pubspec.lock`：当前依赖锁定结果。

## 一手来源

- pub.dev API：<https://pub.dev/api/packages/appflowy_editor>
- 官方仓库：<https://github.com/AppFlowy-IO/appflowy-editor>
- 当前固定提交：<https://github.com/AppFlowy-IO/appflowy-editor/commit/01eccc6ee36bd07698bd80915289fe7070478cd2>
- 官方提交 API：<https://api.github.com/repos/AppFlowy-IO/appflowy-editor/commits/01eccc6ee36bd07698bd80915289fe7070478cd2>
