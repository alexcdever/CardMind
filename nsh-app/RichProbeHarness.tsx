// P4-3a 探针（临时，验证 0.4.0 RichEditor 的 Markdown 往返与 headless 挂载）。
// 场景经 open(..., { storage }) 的 `probe.input` 注入（JSON 字符串数组，逐个
// 作为输入文档）；每个输入依次：parse → createRichEditor → serialize("markdown")
// → getMarkdown() → doc JSON，写回 storage `probe.out.<i>` / `probe.doc.<i>`。
// 同时把最后一个 session 挂成 <RichEditor> 验证 headless 渲染不崩，
// 并挂 keymap 探针：mod+shift+e dump 当前 session 的 markdown。
import { effect, keymap, mount, signal, Storage, Text, View, type JSX } from "nsh";
import {
  RichEditor,
  createRichEditor,
  link,
  markdown,
  starterKit,
  starterSchema,
  type RichEditorSession,
  type RichSchema,
} from "nsh/base";

const done = signal(false);

let schema: RichSchema;
let session: RichEditorSession | null = null;
let inputIdx = 0;

function makeSession(input: string): RichEditorSession {
  return createRichEditor({
    schema,
    content: input,
    format: "markdown",
    plugins: [
      starterKit(),
      markdown(),
      link({
        protocols: ["cardmind"],
        openOnClick: false,
        enableClickSelection: true,
      }),
    ],
  });
}

async function runProbes(): Promise<void> {
  schema = starterSchema();
  const raw = await Storage.getItem("probe.inputs");
  const inputs = raw === null || raw === undefined ? [""] : (JSON.parse(raw) as string[]);
  for (let i = 0; i < inputs.length; i += 1) {
    const input = inputs[i];
    const t0 = Date.now();
    const s = makeSession(input);
    const t1 = Date.now();
    const serialized = schema.serialize(s.doc, "markdown");
    const t2 = Date.now();
    const getMarkdown = s.getMarkdown();
    const t3 = Date.now();
    await Storage.setItem(`probe.out.${i}`, serialized);
    await Storage.setItem(`probe.getmd.${i}`, getMarkdown);
    await Storage.setItem(`probe.doc.${i}`, JSON.stringify(s.doc));
    await Storage.setItem(`probe.same.${i}`, String(serialized === getMarkdown));
    await Storage.setItem(
      `probe.ms.${i}`,
      `len=${input.length} create=${t1 - t0}ms ser=${t2 - t1}ms getmd=${t3 - t2}ms`,
    );
    s.dispose();
    inputIdx = i;
  }
  // 最后一个 session 留作视图挂载与 keymap 探针。
  session = makeSession(inputs[inputs.length - 1]);
  await Storage.setItem("probe.done", "1");
  done.set(true);
}

function Harness(): JSX.Element {
  effect(() => {
    void runProbes();
    const unbind = keymap.bind({
      "mod+shift+e": () => {
        if (session === null) return;
        void Storage.setItem("probe.live", session.getMarkdown());
      },
      "mod+shift+l": () => {
        if (session === null) return;
        // 探针：在末尾插入文本（等价 Editor.edit 末尾插入）。
        session.insertContent("\n\n探针插入", "markdown");
      },
    });
    return () => unbind();
  });
  return (
    <View style={{ flex: 1 }}>
      {() =>
        done() && session !== null ? (
          <RichEditor
            testID="rich-editor"
            editor={session}
            placeholder="写下第一行…"
            autoFocus
            accessibilityLabel="富文本编辑器"
          />
        ) : (
          <Text>probing {inputIdx}</Text>
        )
      }
    </View>
  );
}

mount(Harness);
