# Flutter 自动化锚点规范

## 目标

- 统一 Flutter 交互控件的机器可读锚点，让 widget 测试、集成测试和桌面自动化使用同一套稳定标识。

## 适用范围

- 优先应用于新建或本次改动中触达的关键交互面。
- 不要求每次 UI 改动都顺手把仓库中无关页面全部补齐。

## 必要模式

- 当交互控件属于值得自动化覆盖的用户流程时，建议同时使用以下三层：
  - `Semantics(identifier: ...)`：提供机器可读的稳定标识
  - `ValueKey(...)`：提供 Flutter 原生测试定位点
  - 面向用户的 `Semantics(label: ...)`：提供无障碍可读文本

- 推荐形态（与 `lib/pages/editor_page.dart` 现有实现一致）：

```dart
Semantics(
  identifier: 'note-editor',
  label: '笔记编辑器',
  textField: true,
  child: AppFlowyEditor(
    key: const ValueKey('note-editor'),
  ),
)
```

## 命名规则

- machine id 使用 kebab-case 字符串，例如 `note-editor`、`note-search-field`。
- 动态生成的 id 用插值表达，例如 `note-${note.id}`、`action-${tooltip.replaceAll(' ', '-')}`。
- 同一控件上 `identifier` 与 `ValueKey` 应使用同一份稳定 id；若两者的语义确有差别（例如
  `identifier: 'note-search-field'` 对应 `ValueKey('note-search-input')`），必须在控件所在文件内保持一致。
- `label` 必须保持用户可读，不得直接替换成 machine id。
- machine id 目前内联声明在控件所在文件（如 `lib/pages/editor_page.dart`、
  `lib/pages/note_list_page.dart`、`lib/ui/design_system/cardmind_widgets.dart`），
  仓库中不存在共享常量文件；若未来引入共享常量文件，必须在本节登记其路径。

## 覆盖规则

- 以下控件必须优先应用该模式：
  - 主操作按钮
  - 导航入口
  - 对话框确认/取消动作
  - 自动化流程中会使用到的表单输入项
  - widget 或集成回归测试依赖的关键控件

- 纯装饰性控件不应添加自动化锚点。

## 测试规则

- Flutter 自动化测试应优先使用 `find.byKey(...)` 作为主要交互定位方式。
- 无障碍契约测试应验证用户可读的 `label` 仍然存在。
- 新增自动化流程时，至少补一条“锚点存在”的测试，以及一条“通过该锚点完成交互”的测试。

## 平台说明

- `Semantics.identifier` 是平台自动化桥接的首选机器可读通道；当前只在少数关键控件上落地，
  多数控件只提供 `label`、`liveRegion` 或 `button` 等语义，新增关键流程时应补 `identifier`。
- `ValueKey` 仍然是 Flutter widget 测试中的主要稳定选择器。
- 桌面系统自动化目前可能仍只能暴露部分无障碍树，但这不构成省略 `identifier`、`key` 与 `label` 的理由。
