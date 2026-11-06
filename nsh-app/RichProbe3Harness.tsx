// P4-3a 探针 3：确认 <RichEditor> 是否真挂进 headless 视图树（而非只是不进 a11y 树）。
// 线索面：
//   - session.on("update") 经 Storage 报数（证明事务发生）
//   - onFocus/onBlur/onChange/onSelectionChange props 写 Storage（证明 view 活着）
//   - placeholder 是否被 text:/label: 解析（headless 输入框惯例）
//   - app.texts() 是否含文档文字
//   - keymap mod+shift+i 调 session.insertContent 验证双向
import { effect, keymap, mount, signal, Storage, Text, View, type JSX } from "nsh";
import {
  RichEditor,
  createRichEditor,
  link,
  markdown,
  starterKit,
  starterSchema,
  type RichEditorRef,
  type RichEditorSession,
} from "nsh/base";

let session: RichEditorSession | null = null;
let richRef: RichEditorRef | null = null;
let updates = 0;
const ready = signal(false);

function bump(key: string, value: string): void {
  void Storage.setItem(key, value);
}

/** 与 editor_page.test.tsx 的 bigMarkdown 同构（用于 perf 挂载探针）。 */
function bigMarkdown(targetChars: number): string {
  const parts: string[] = [];
  let n = 0;
  let block = 0;
  while (n < targetChars) {
    block += 1;
    const seg =
      `# 第 ${block} 节 标题\n\n` +
      `正文段落，含 [别名${block}](cardmind://note/note-${block}) 与普通文本，用来撑大解析成本。` +
      `中文内容若干，重复填充以达到五万字量级的真实文档。\n\n` +
      `- 列表项一\n- 列表项二\n- 列表项三\n\n` +
      `> 引用一句话，来自第 ${block} 节。\n\n` +
      "```\nconst x" + block + " = " + block + ";\n```\n\n";
    parts.push(seg);
    n += seg.length;
  }
  return parts.join("");
}

function Harness(): JSX.Element {
  effect(() => {
    void (async () => {
      const raw = await Storage.getItem("probe.chars");
      const chars = raw === null || raw === undefined ? 0 : Number(raw);
      const noLink = (await Storage.getItem("probe.nolink")) === "1";
      const noOn = (await Storage.getItem("probe.noon")) === "1";
      const content =
        chars > 0 ? bigMarkdown(chars) : "# 探针标题\n\n第一段 含 **粗体** 文本\n";
      const t0 = Date.now();
      session = createRichEditor({
        schema: starterSchema(),
        content,
        format: "markdown",
        plugins: noLink
          ? [starterKit(), markdown()]
          : [
              starterKit(),
              markdown(),
              link({
                protocols: ["cardmind"],
                openOnClick: false,
                enableClickSelection: true,
              }),
            ],
      });
      const t1 = Date.now();
      bump("probe3.createMs", String(t1 - t0));
      bump("probe3.len", String(content.length));
      const t2 = Date.now();
      bump("probe3.bumpMs", String(t2 - t1));
      if (!noOn) {
        session.on("update", () => {
          updates += 1;
          bump("probe3.updates", String(updates));
        });
      }
      const t3 = Date.now();
      bump("probe3.onMs", String(t3 - t2));
      bump("probe3.session", "made");
      const t4 = Date.now();
      bump("probe3.madeMs", String(t4 - t3));
      ready.set(true);
    })();
  });
  effect(() => {
    const unbind = keymap.bind({
      f6: () => {
        if (session !== null) bump("probe3.live", session.getMarkdown());
      },
      "mod+shift+e": () => {
        bump("probe3.e", "1");
        if (session !== null) bump("probe3.live", session.getMarkdown());
      },
      "mod+shift+l": () => {
        bump("probe3.l", "1");
      },
      f7: () => {
        // 「在文档末尾插入」探针：nodeSize 求文档尺寸 → 选区移尾 → 插 Markdown。
        if (session === null) return;
        const size = session.characters("nodeSize");
        bump("probe3.nodeSize", String(size));
        const ok1 = session.run({
          command: "setTextSelection",
          pos: size - 1,
        });
        const ok2 = session.run({
          command: "insertContent",
          content: "\n\n末尾-探针",
          format: "markdown",
        });
        bump("probe3.f7", `sel=${ok1} ins=${ok2}`);
      },
      f8: () => {
        // 备选：RichEditorRef.setSelection（声明会收敛到最近有效文本位）→ 插入。
        if (session === null || richRef === null) return;
        const size = session.characters("nodeSize");
        richRef.setSelection(size, size);
        void richRef.selection().then((sel) => {
          bump("probe3.sel", JSON.stringify(sel));
          if (session === null) return;
          const ok = session.run({
            command: "insertContent",
            content: "\n\n末尾2-探针",
            format: "markdown",
          });
          bump("probe3.f8", `pos=${size} ins=${ok}`);
        });
      },
    });
    return () => unbind();
  });
  return (
    <View testID="editor-box" style={{ flex: 1 }}>
      {() =>
        ready() && session !== null ? (
          <RichEditor
            testID="rich-editor"
            ref={(ref: RichEditorRef) => {
              richRef = ref;
            }}
            editor={session}
            placeholder="写下第一行…"
            autoFocus
            accessibilityLabel="富文本编辑器"
            style={{ flex: 1 }}
            onChange={() => bump("probe3.onChange", "1")}
            onSelectionChange={() => bump("probe3.onSelChange", "1")}
            onFocus={() => bump("probe3.onFocus", "1")}
            onBlur={() => bump("probe3.onBlur", "1")}
          />
        ) : (
          <Text>not ready</Text>
        )
      }
    </View>
  );
}

mount(Harness);
