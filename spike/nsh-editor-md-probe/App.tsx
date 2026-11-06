import { mount, signal, Text, View } from "nsh";
import {
  Button,
  Editor,
  TextView,
  type EditorCompletionRequest,
  type EditorRef,
  type EditorSelection,
} from "nsh/base";

const SAMPLE = `# CardMind 探针

这是一段 **Markdown** 源文本，包含：

- 列表项
- [[会议记录]] 与 [[项目计划|计划]] 这样的 wiki 链接
- [NSH 文档](https://nsh.dev) 与 \`inline code\`

| 列 A | 列 B |
| --- | --- |
| 1 | 2 |

\`\`\`rust
fn main() { println!("hi"); }
\`\`\`
`;

const CANDIDATES = [
  { id: "meeting", title: "会议记录" },
  { id: "plan", title: "项目计划" },
  { id: "weekly", title: "Weekly Buffer" },
];

/** 50k 字符的 Markdown：用于测量 setValue / value() 的大文档成本。 */
const BIG = (() => {
  let out = "";
  let n = 0;
  while (out.length < 50_000) {
    n += 1;
    out += `## 第 ${n} 节\n\n这是第 ${n} 段正文，混入中文、English 与 \`code\`。\n\n- 条目 A${n}\n- 条目 B${n}\n\n`;
  }
  return out;
})();

function eventValue(event: unknown, key: string): unknown {
  if (event !== null && typeof event === "object" && key in (event as Record<string, unknown>)) {
    return (event as Record<string, unknown>)[key];
  }
  return event;
}

function App() {
  const source = signal(SAMPLE);
  const completionLog = signal("completion: none");
  const selectionLog = signal("selection: -");
  const focusLog = signal("focus: -");
  const perfLog = signal("perf: not run");
  const readLog = signal("read: not run");
  const preview = signal(true);
  let editor!: EditorRef;

  const stats = () => {
    const text = source();
    return `len=${text.length} link=${text.includes("[[会议记录]]") ? "yes" : "no"} paragraphs=${text.split("\n\n").length}`;
  };

  const onChange = (event: unknown) => {
    const value = eventValue(event, "value");
    if (typeof value === "string") source.set(value);
  };

  const onSelectionChange = (event: unknown) => {
    const list = eventValue(event, "selections");
    const selections = Array.isArray(list) ? (list as EditorSelection[]) : Array.isArray(event) ? (event as EditorSelection[]) : [];
    const primary = selections[selections.length - 1];
    if (primary === undefined) {
      selectionLog.set("selection: none");
      return;
    }
    selectionLog.set(`selection: ${primary.anchor.line}:${primary.anchor.column}..${primary.head.line}:${primary.head.column}`);
  };

  const onCompletionRequest = (event: EditorCompletionRequest) => {
    completionLog.set(
      `completion: trigger=${event.trigger} char=${event.character ?? "-"} q=${JSON.stringify(event.query)} offset=${event.offset} queryStart=${event.queryStart}`,
    );
    // 焦点与缓冲区版本在事件派发时可能还没稳定（headless 尤其明显），
    // 放到下一轮再回答：`presentCompletions` 会丢弃“不新鲜”的答案。
    setTimeout(() => {
      try {
        editor.presentCompletions(
          event.id,
          CANDIDATES.map((candidate, index) => ({
            label: candidate.title,
            kind: "reference" as const,
            detail: candidate.id,
            filterText: candidate.title,
            // 用序号作排序键，保住原生命中的候选顺序（默认按 label 排序）。
            sortText: String(index).padStart(4, "0"),
            insertText: `${candidate.title}]]`,
          })),
        );
        completionLog.update((log) => `${log} -> present id=${event.id}`);
      } catch (error) {
        completionLog.update((log) => `${log} -> threw ${String(error)}`);
      }
    }, 60);
  };

  const readValue = async () => {
    const value = await editor.value();
    const tail = value.slice(-48).replaceAll("\n", "\\n");
    readLog.set(`read: len=${value.length} tail=${tail}`);
  };

  const probeCompletions = () => {
    editor.focus();
    editor.insert("[[");
    editor.showCompletions();
  };

  const perf = async () => {
    const started = performance.now();
    editor.setValue(BIG);
    const setDone = performance.now();
    const value = await editor.value();
    const readDone = performance.now();
    perfLog.set(
      `perf: set=${Math.round(setDone - started)}ms read=${Math.round(readDone - setDone)}ms len=${value.length} same=${value === BIG ? "yes" : "no"}`,
    );
  };

  return (
    <View class="flex-1 bg-background">
      <View class="flex-row items-center gap-2 border-b border-border px-3 py-2">
        <Text class="text-sm font-semibold text-foreground">editor-md-probe</Text>
        <Button onPress={() => editor.focus()} class="rounded border border-border px-2 py-1">
          <Text class="text-xs text-foreground">Focus</Text>
        </Button>
        <Button onPress={probeCompletions} class="rounded border border-border px-2 py-1">
          <Text class="text-xs text-foreground">Probe [[</Text>
        </Button>
        <Button onPress={() => void readValue()} class="rounded border border-border px-2 py-1">
          <Text class="text-xs text-foreground">Read value</Text>
        </Button>
        <Button onPress={() => editor.run("undo")} class="rounded border border-border px-2 py-1">
          <Text class="text-xs text-foreground">Undo</Text>
        </Button>
        <Button onPress={() => void perf()} class="rounded border border-border px-2 py-1">
          <Text class="text-xs text-foreground">Perf 50k</Text>
        </Button>
        <Button onPress={() => preview.update((p) => !p)} class="rounded border border-border px-2 py-1">
          <Text class="text-xs text-foreground">Preview</Text>
        </Button>
        <Button
          onPress={() => {
            editor.setValue(SAMPLE);
            source.set(SAMPLE);
            readLog.set("read: not run");
            perfLog.set("perf: not run");
          }}
          class="rounded border border-border px-2 py-1"
        >
          <Text class="text-xs text-foreground">Reset</Text>
        </Button>
      </View>
      <View class="flex-row gap-2 px-3 py-1">
        <Text testID="stats" class="text-xs text-muted-foreground">{`stats: ${stats()}`}</Text>
        <Text testID="selection" class="text-xs text-muted-foreground">{selectionLog()}</Text>
        <Text testID="focus" class="text-xs text-muted-foreground">{focusLog()}</Text>
        <Text testID="completion" class="text-xs text-muted-foreground">{completionLog()}</Text>
        <Text testID="read" class="text-xs text-muted-foreground">{readLog()}</Text>
        <Text testID="perf" class="text-xs text-muted-foreground">{perfLog()}</Text>
      </View>
      <View class="flex-1 flex-row items-stretch gap-3 px-3 py-2">
        <View testID="source" class="flex-1 h-full">
          <Editor
            ref={editor}
            value={source()}
            defaultValue={SAMPLE}
            language="markdown"
            softWrap
            lineNumbers
            autoClose={false}
            accessibilityLabel="Markdown source"
            class="flex-1 rounded border border-border"
            onChange={onChange}
            onSelectionChange={onSelectionChange}
            completion
            completionTriggerCharacters={["[["]}
            onCompletionRequest={onCompletionRequest}
            onCompletionAccept={(event) => completionLog.set(`accepted: ${event.item.label}`)}
            onFocus={() => focusLog.set("focus: yes")}
            onBlur={() => focusLog.set("focus: no")}
          />
        </View>
        {preview() ? (
          <View testID="preview" class="flex-1 h-full overflow-hidden rounded border border-border" style={{ backgroundColor: "#eef3ff" }}>
            <TextView markdown={source()} selectable onLinkPress={(event) => selectionLog.set(`link: ${event.url}`)} />
          </View>
        ) : undefined}
      </View>
    </View>
  );
}

mount(App);
