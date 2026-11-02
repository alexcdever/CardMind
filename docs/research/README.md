# 研究资料

本目录只保留仍服务于 CardMind 技术决策的研究资料，并按主题归档。

## 编辑器

- [`editor/appflowy-editor-compatibility.md`](editor/appflowy-editor-compatibility.md)：AppFlowy Editor 兼容性问题、固定提交和可复现依赖决策。当前项目实际依赖已固定到完整 Git SHA，不依赖本机 Pub Cache 手工补丁。
- [`editor/flutter-editor-alternatives.md`](editor/flutter-editor-alternatives.md)：Flutter 富文本编辑器替代方案评估。它是迁移决策的基线，不代表当前已决定迁移。

## NSH 编辑器与运行时

- [`nsh-editor/README.md`](nsh-editor/README.md)：用 NSH 0.3.0 的 `Editor` + `TextView` 替换 WebView + Tiptap 的调研总报告（方向已于第二轮改为“不需要富文本编辑器”）、施工阶段方案、风险与验收标准。
- [`nsh-editor/01-current-editor.md`](nsh-editor/01-current-editor.md)：当前编辑器实现与功能基线（WebView + Tiptap、桥协议、保存/加载时序、后端契约、测试基线、不能接受回归清单）。
- [`nsh-editor/02-nsh-rich-editor-api.md`](nsh-editor/02-nsh-rich-editor-api.md)：NSH RichEditor / TextView / Markdown 能力面、发布状态、Loro 协作方案对比（RichEditor 为 main-only 历史/备选）。
- [`nsh-editor/03-version-and-toolchain.md`](nsh-editor/03-version-and-toolchain.md)：NSH 版本事实、main 源码构建实录、RichEditor 探针结果（历史/备选）。
- [`nsh-editor/04-app-upgrade.md`](nsh-editor/04-app-upgrade.md)：nsh-app 从 NSH 0.2.0 升级到 0.3.0/main 的逐文件 API 迁移面（0.3.0 部分为当前施工依据）。
- [`nsh-editor/05-editor-doc-api.md`](nsh-editor/05-editor-doc-api.md)：0.3.0 `Editor`/`TextView` API 全量、`[[` 补全实测与坑、探针结果。
- [`nsh-editor/06-editor-md-migration.md`](nsh-editor/06-editor-md-migration.md)：基于 `Editor` + `TextView` 的编辑器替换施工方案（逐文件、测试、阶段、验收）。

版本号和发布时间会变化；涉及当前依赖选择时，以 `nsh-app/Cargo.toml`、`nsh-app/nsh.json` 和官方一手来源为准。
