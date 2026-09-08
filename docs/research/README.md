# 研究资料

本目录只保留仍服务于 CardMind 技术决策的研究资料，并按主题归档。

## 编辑器

- [`editor/appflowy-editor-compatibility.md`](editor/appflowy-editor-compatibility.md)：AppFlowy Editor 兼容性问题、固定提交和可复现依赖决策。当前项目实际依赖已固定到完整 Git SHA，不依赖本机 Pub Cache 手工补丁。
- [`editor/flutter-editor-alternatives.md`](editor/flutter-editor-alternatives.md)：Flutter 富文本编辑器替代方案评估。它是迁移决策的基线，不代表当前已决定迁移。

版本号和发布时间会变化；涉及当前依赖选择时，以 `pubspec.yaml`、`pubspec.lock` 和官方一手来源为准。
