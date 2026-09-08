# Flutter 富文本编辑器替代方案

## 文档定位

这是一份迁移决策基线，不表示 CardMind 当前要替换 AppFlowy Editor。当前优先保持现有编辑器和固定 Git 依赖稳定运行；只有出现明确的维护、兼容性或产品能力问题，才启动 spike。

版本号、发布时间和平台支持会变化。再次评估时必须重新查询候选项目的官方仓库、pub.dev API、变更记录，并以实机测试结果为准。

## 当前耦合范围

CardMind 的编辑器不是可直接替换的单个 Widget。现有代码依赖：

- `EditorState` 创建、监听和释放；
- Markdown 加载与导出；
- transaction stream 驱动 dirty/autosave；
- `Selection`、当前位置、节点 delta 和光标 offset；
- selection 几何信息用于补全面板锚点；
- transaction 删除/插入文本，实现 `[[笔记链接]]` 补全；
- 移动端和桌面端样式；
- Widget 测试直接操作文档、selection 和 transaction。

因此迁移需要编辑器适配层、Markdown codec、selection/transaction 映射和相关测试，不应只替换依赖名。

## 候选方向

### flutter_quill

优点：维护和发布治理较成熟，跨平台覆盖完整，controller 暴露 selection、changes 和 replaceText，适合实现链接补全和编辑变更监听。

风险：核心存储模型是 Quill Delta；Markdown 需要额外 codec 或适配层。若采用，必须先建立 Markdown 往返黄金测试，并验证 `[[id|title]]`、列表、引用、代码块、链接、空行、中文输入和光标行为。

### Fleather

优点：Parchment 文档模型和 Markdown codec 更贴近当前 Markdown 真源，跨平台覆盖完整。

风险：社区和维护规模较小，Markdown 标准化、未支持属性和中文输入法行为需要实测。不能仅因内置 Markdown codec 就假定无数据丢失。

### super_editor

优点：节点式文档模型、selection stream、命令式编辑和可扩展布局能力强。

风险：稳定版发布治理和迁移成本不如前两者。若稳定线长期落后而主要开发集中在 dev 版本，不应作为降低发布风险的首选。

## 迁移前置条件

先把 AppFlowy 类型从页面和 Widget 测试中收敛到编辑器 seam，至少包含：

- 加载和导出 Markdown；
- 当前纯文本与 selection；
- 文档变化 stream；
- 替换当前文本范围；
- 获取 caret 矩形；
- 构建编辑器 Widget。

之后分别建立候选 adapter，使用同一验收矩阵验证：

1. Windows 中文拼音输入、候选切换、光标移动、复制粘贴；
2. Android 中文输入、候选词、软键盘、选择手柄；
3. Markdown 标题、粗体、斜体、列表、引用、代码块、链接、空行双向往返；
4. `[[id|title]]` 不转义、不拆分、不丢失；
5. 根据 selection 检测 `[[前缀`；
6. 获取 caret 屏幕位置并显示补全面板；
7. 用 controller/transaction 替换当前前缀；
8. transaction/change stream 驱动自动保存；
9. 复刻现有 Windows/Android 布局和工具栏；
10. 连续输入、长文档和大段粘贴性能。

只有真实 spike 通过后才决定迁移。默认先验证维护治理较稳的候选，再用 Markdown 贴合度较高的候选作对照。

## 当前参考来源

- flutter_quill：<https://pub.dev/packages/flutter_quill> · <https://github.com/singerdmx/flutter-quill>
- Fleather：<https://pub.dev/packages/fleather> · <https://github.com/fleather-editor/fleather>
- super_editor：<https://pub.dev/packages/super_editor> · <https://github.com/superlistapp/super_editor>
- CardMind 当前编辑器依赖：`pubspec.yaml`、`pubspec.lock`
