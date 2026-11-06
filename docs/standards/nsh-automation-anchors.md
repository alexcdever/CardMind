# NSH 自动化锚点规范

## 目标

- 统一 nsh-app（TSX）交互控件的机器可读锚点，让 `nsh test` 行为测试与真窗口自动化使用同一套稳定标识。
- 锚点同时承担无障碍职责：`accessibilityLabel` 是屏幕阅读器读到的文本，`role` / `accessibilityState` 是控件的语义与状态。

## 适用范围

- 优先应用于新建或本次改动中触达的关键交互面。
- 不要求每次 UI 改动都顺手把仓库中无关页面全部补齐。

## 必要模式

当交互控件属于值得自动化覆盖的用户流程时，建议同时使用以下三层：

- `testID`：`nsh test` 的定位点，选择器写作 `id:<testID>`。
- `accessibilityLabel`：选择器写作 `label:<label>`，同时是用户可读的无障碍文本。
- `role` + `accessibilityState`：声明控件是什么、当前处于什么状态，供无障碍树与自动化断言使用。

推荐形态（与 `nsh-app/editor_page.tsx` 的源码/排版切换一致）：

```tsx
<View
  testID="source-toggle"
  role="button"
  accessibilityLabel={sourceMode() ? COPY.richMode : COPY.sourceMode}
  accessibilityState={{ selected: sourceMode() }}
  onPress={toggleSourceMode}
>
  <Text>{sourceMode() ? COPY.richMode : COPY.sourceMode}</Text>
</View>
```

自绘开关的形态（与 `nsh-app/settings_page.tsx` 的同步开关一致）：

```tsx
<View
  role="switch"
  accessibilityLabel="同步"
  accessibilityState={{ checked: on() }}
  onPress={props.onToggle}
>
  {/* 轨道 + 滑块 */}
</View>
```

## 命名规则

- `testID` 使用 kebab-case 字符串，例如 `source-toggle`、`save-state`、`note-list`、`rich-editor`。
- 动态生成的 id 用模板串表达，例如 `note-${note().id}`、`link-${candidate.id}`、`tag-${index}`。
- 同一控件的 `testID` 与 `accessibilityLabel` 语义可以不同，但各自必须稳定：`testID` 面向自动化、不随文案改；`accessibilityLabel` 面向用户、随文案改。
- `accessibilityLabel` 必须保持用户可读，不得直接替换成 machine id。
- 锚点目前内联声明在控件所在文件（`nsh-app/components.tsx`、`editor_page.tsx`、`note_list.tsx`、
  `settings_page.tsx`、`devices_page.tsx`、`trash_page.tsx`），仓库中不存在共享常量文件；
  若未来引入共享常量文件，必须在本节登记其路径。

## 选择器（`nsh test`）

`nsh test` 的选择器按 Playwright 的方式书写：一个 matcher，其后可用 ` >> ` 串接更深的 matcher，
`nth=<n>` 从多个命中里取一个。

| 选择器 | 命中 |
|---|---|
| `id:<testID>` | `testID` 为该值的视图 |
| `label:<label>`、`label:/<regex>/<flags>` | 无障碍 label 为该值的视图 |
| `text:<text>`、`text:/<regex>/<flags>` | 读作该文本的文本节点、持有该值的输入框，或为空时占位符为该值的输入框 |
| `role:<role>`、`role:<role>[<name>]` | 该 `role` 的视图；带 `[<name>]` 时其名字（label，否则内部文本）需匹配 `<name>` |
| `view:<id>` | 节点 id 为该值的视图（`nsh test --trace` 打印的 id） |
| 其它裸串 | 先按 `testID`，再按 label，再按 text 匹配 |

正则按 JavaScript 的写法，支持 `i`、`m`、`s`、`u`。

## 覆盖规则

以下控件必须优先应用该模式：

- 主操作按钮
- 导航入口
- 对话框确认/取消动作
- 自动化流程中会使用到的表单输入项
- 行为测试依赖的关键控件

纯装饰性控件不应添加自动化锚点。

## 测试规则

- `nsh test` 优先用 `id:` 定位交互点：文案会改，`testID` 不该改。
- `label:` 用于需要同时验证无障碍契约的入口（断言用户可读文本仍在）。
- `text:` 用于断言渲染内容（含 `/正则/` 形式的局部匹配）。
- 状态断言读语义而不是读文案：`app.enabled("label:…")` 对应 `accessibilityState.disabled`。
  选中/勾选态目前**没有直接断言 API**（nsh 0.3.0 的 TSX `App` 只有 `enabled/shows/count/value/texts/spanStyle`；
  Rust 侧 `Screen::selected()` 未绑定到 JS）：用 `role:` 命名、渲染出的文案或截图间接断言。
- 新增自动化流程时，至少补一条「锚点存在」的测试（`app.shows("id:…")`），以及一条
  「通过该锚点完成交互」的测试（`app.press("id:…")` / `app.type("id:…", …)`）。
- 测试入口是 `nsh-app/*Harness.tsx`：`EditorHarness.tsx` 用假 `EditorRepository` 挂载真实
  `EditorScreen`，`NoteListHarness.tsx` 用假 `NoteListSource` 挂载真实 `NoteListPage`。
  harness 不 import `App.tsx`（那里有会碰真实数据目录/网络的顶层 IIFE），场景经
  `open("./…Harness.tsx", { storage })` 注入，断言经 `app.storage()` 读回。

## 平台说明

- headless（默认）与真窗口（`nsh test --target <platform>`）都从同一份视图属性解析选择器，
  `id:` / `label:` / `role:` 两者都可用；真窗口另有平台原生无障碍树参与。
- headless 下 `TextView` 内部的 `testID` 不可选（见 `nsh-app/editor_page.test.tsx` 的注释），
  需要按内容定位时用 `label:` 或 `text:`。
- `RichEditor`（0.4.0）headless 要点：**必须给非零尺寸 style（如 `flex:1`）才挂载**；
  `id:`/`label:`/`text:` 与 `app.type` 可用，`app.texts()` 出渲染后文本块；
  `app.press`/`mod+shift+*`/`mod+a` 不可用（编辑器吞键）——测试探针用 f 键 +
  `session.run({command:"selectAll"})` / `session.insertContent`。
- IME、选区、真窗口渲染只能靠 `nsh test --target <platform>` 或人工目视验证；headless 通过不构成
  真机验收。
