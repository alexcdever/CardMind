import { mount, signal, Text, View } from "nsh";
import { Button, Editor, TextView, type EditorCompletionRequest, type EditorRef } from "nsh/base";

const MARKDOWN = `# CardMind 可视化探针

这是 **TextView** 预览，下面是 **Editor** 源编辑（Markdown 高亮）。

- [[会议记录]] 与 [[项目计划|计划]]
- [NSH 文档](https://nsh.dev)
- \`inline code\`

| 列 A | 列 B |
| --- | --- |
| 1 | 2 |

\`\`\`rust
fn main() { println!("hi"); }
\`\`\`
`;

const CANDIDATES = ["会议记录", "项目计划", "Weekly Buffer"];

function App() {
  const source = signal(MARKDOWN);
  const status = signal("completion: none");
  let editor!: EditorRef;

  const onChange = (event: unknown) => {
    const value =
      event !== null && typeof event === "object" && "value" in (event as Record<string, unknown>)
        ? (event as Record<string, unknown>).value
        : event;
    if (typeof value === "string") source.set(value);
  };

  const request = (event: EditorCompletionRequest) => {
    status.set(`completion: trigger=${event.trigger} char=${event.character ?? "-"}`);
    setTimeout(() => {
      editor.presentCompletions(
        event.id,
        CANDIDATES.map((label, index) => ({
          label,
          kind: "reference" as const,
          sortText: String(index).padStart(4, "0"),
          insertText: `${label}]]`,
        })),
      );
    }, 80);
  };

  // 自动摆出：聚焦、插入 `[[`、请求补全，让窗口里直接看到候选列表。
  setTimeout(() => {
    editor.focus();
    editor.insert("\n\n[[");
    editor.showCompletions();
  }, 500);

  return (
    <View class="flex-1 flex-col bg-background">
      <Text class="px-3 py-1 text-xs text-muted-foreground">{`status: ${status()}`}</Text>
      <View class="flex-row gap-3 px-3 py-2" style={{ height: 140 }}>
        <View testID="preview" class="flex-1 overflow-hidden rounded border border-border" style={{ backgroundColor: "#eef3ff" }}>
          <TextView markdown={source()} selectable onLinkPress={(event) => status.set(`link: ${event.url}`)} />
        </View>
      </View>
      <View testID="source" class="flex-1 px-3 pb-2">
        <Editor
          ref={editor}
          value={source()}
          defaultValue={MARKDOWN}
          language="markdown"
          softWrap
          lineNumbers
          autoClose={false}
          accessibilityLabel="Markdown source"
          classes={{ content: "px-2" }}
          class="flex-1 rounded border border-border"
          onChange={onChange}
          completion
          completionTriggerCharacters={["[["]}
          onCompletionRequest={request}
          onCompletionAccept={(event) => status.set(`accepted: ${event.item.label}`)}
        />
      </View>
      <View class="flex-row gap-2 px-3 py-1">
        <Button onPress={() => editor.focus()} class="rounded border border-border px-2 py-1">
          <Text class="text-xs">Focus</Text>
        </Button>
        <Button
          onPress={() => {
            editor.focus();
            editor.insert("\n\n[[");
            editor.showCompletions();
          }}
          class="rounded border border-border px-2 py-1"
        >
          <Text class="text-xs">Probe [[</Text>
        </Button>
      </View>
    </View>
  );
}

mount(App);
