import { If, mount, signal, Text, View, type YNode } from "nsh";
import { Screen, Stack } from "nsh/ui/mobile";
import { WebView } from "nsh/webview";
import {
  App,
  Backend,
  BackendNotes,
  BackendPairing,
  BackendStore,
  BackendSync,
  Bridge,
} from "app/native";
import {
  CardMindIconButton,
  CardMindListItem,
  CardMindSyncStatus,
  CardMindTag,
} from "./components";
import { DevicesPage } from "./devices_page";
import { NoteListPage } from "./note_list";
import { goBack, nav, routes, screenChrome, type Route } from "./navigation";
import { SettingsPage } from "./settings_page";
import { TrashPage } from "./trash_page";
import { colors, spacing } from "./theme";
import { linkPrefixFromContext, matchTags } from "./web/src/protocol";
// 构建产物：build:web 生成（gitignored；`npm run build` 先于 nsh build）。
import { EDITOR_BASE_URL, EDITOR_HTML } from "./web/dist/editor_html";

// 真后端数据源（施工方案 1.1–1.7 的验收证据）：这些 Backend* 调用不能删。
// 页面骨架把它们的结果渲染进新组件（同步指示条 / 列表项 / 空态），不再是
// 裸 Text 堆叠。
const device = signal("设备ID：(调用中…)");
const storeStatus = signal("Store：(初始化中…)");
const noteId = signal("笔记ID：(生成中…)");
const syncId = signal("同步ID：(创建中…)");
const listLine = signal("列表：(查询中…)");
const searchLine = signal("搜索：(查询中…)");
const noteLine = signal("笔记：(未创建)");
const trashLine = signal("回收站：(未删除)");
const syncLine = signal("同步开关：(未读取)");
const peerLine = signal("配对设备：(未查询)");
const last = signal("最近事件：(还没收到)");
(async () => {
  const id = await Backend.deviceId();
  device.set(`设备ID：${id}`);

  // 打开全局 store（单例；":memory:" = 演示不落盘）
  const opened = await BackendStore.createNoteStore(":memory:");
  storeStatus.set(`Store：${opened}`);

  // 纯 Rust 生成 UUID v7
  const fresh = await BackendStore.generateNoteId();
  noteId.set(`笔记ID：${fresh}`);

  // 真建 SyncService（iroh endpoint）；后续 notes/sync/pairing 全走它
  const sync = await BackendStore.syncDeviceId();
  syncId.set(`同步ID：${sync}`);

  // ── 1.1 Backend.Notes：创建 → 改 metadata → 软删 → 回收站 → 投影刷新 ──
  await BackendNotes.noteCreate(fresh, "# 测试笔记\n\n正文 markdown");
  await BackendNotes.noteUpdateMetadata(fresh, ["标签A", "标签B"]);
  await BackendNotes.noteSoftDelete(fresh);
  await BackendNotes.syncNotesToStore();

  const content = await BackendNotes.noteGet(fresh);
  noteLine.set(`笔记内容：${(content ?? "(null)").slice(0, 40)}`);

  const trash = await BackendNotes.storeTrashList();
  trashLine.set(`回收站：${trash.length} 条`);

  // 读模型直查（投影已刷新）
  const rows = await BackendStore.storeList();
  listLine.set(`列表：${rows.length} 条`);
  const hits = await BackendStore.storeSearch("测试");
  searchLine.set(`搜索「测试」：${hits.length} 条`);

  // ── 1.2 Backend.Sync：开关 + receiver 生命周期 ──
  const allowed = await BackendSync.getSyncAllowed();
  await BackendSync.setSyncAllowed(!allowed);
  const toggled = await BackendSync.getSyncAllowed();
  await BackendSync.startReceiver();
  const running = await BackendSync.receiverRunning();
  await BackendSync.stopReceiver();
  syncLine.set(`同步开关：${allowed}→${toggled}，receiver ${running ? "已启动" : "未启动"}`);

  // ── 1.3 Backend.Pairing：设备信息 + 发现 + 已配对列表 ──
  const deviceId = await BackendPairing.getDeviceId();
  const deviceName = await BackendPairing.getDeviceName();
  const addrs = await BackendPairing.localAddrs();
  const peers = await BackendPairing.syncDiscoverPeers();
  const paired = await BackendPairing.listPairedDevices();
  peerLine.set(
    `配对设备：${paired.length} 台；发现 ${peers.length} 个对端；` +
      `${deviceName} @ ${addrs.length} 个地址（id:${deviceId.slice(0, 8)}…）`,
  );

  // ── 1.6 退出钩子：演示末尾真调 BackendSync.close()（先 stop_receiver
  //    再 endpoint.close）。nsh trace 进程退出无生命周期钩子，这里显式调用
  //    避免 iroh「Endpoint dropped … Aborting ungracefully」。
  await BackendSync.close();
})();

/** Phase 1 后端证据行 + Bridge 事件监听（原「编辑器占位」状态区）。 */
function PhaseOneStatus() {
  return (
    <View style={{ gap: spacing.sm }}>
      <Text style={{ color: colors.mutedInk }}>Phase 1 后端真数据：</Text>
      <Text>{syncId()}</Text>
      <Text>{device()}</Text>
      <Text>{storeStatus()}</Text>
      <Text>{noteId()}</Text>
      <Text>{noteLine()}</Text>
      <Text>{trashLine()}</Text>
      <Text>{listLine()}</Text>
      <Text>{searchLine()}</Text>
      <Text>{syncLine()}</Text>
      <Text>{peerLine()}</Text>
      <Text>{last()}</Text>
      <CardMindSyncStatus label="本地已就绪" pendingCount={0} />
      <Bridge
        onSyncProgress={(n) => last.set(`最近事件：SyncProgress(${n})`)}
        onPeerFound={(name) => last.set(`最近事件：PeerFound(${name})`)}
      />
    </View>
  );
}

/** notes 根页面：新列表页（内部 ≥960 桌面三栏 / <960 移动堆叠 + 双 Tab）。 */
function NotesScreen() {
  return (
    <Screen {...screenChrome("笔记")}>
      <NoteListPage status={<PhaseOneStatus />} />
    </Screen>
  );
}

/** 回收站页：真列表 + 恢复/彻底删除/定期清理 + 返回键。 */
function TrashScreen() {
  return (
    <Screen
      {...screenChrome("回收站")}
      headerLeft={
        <CardMindIconButton icon="back" tooltip="返回" onPress={goBack} />
      }
    >
      <TrashPage status={<PhaseOneStatus />} />
    </Screen>
  );
}

/** 设备页：配对全流程 + 已配对设备管理 + 本机信息 + 返回键。 */
function DevicesScreen() {
  return (
    <Screen
      {...screenChrome("设备")}
      headerLeft={<CardMindIconButton icon="back" tooltip="返回" onPress={goBack} />}
    >
      <DevicesPage status={<PhaseOneStatus />} />
    </Screen>
  );
}

/** 设置页：真设备名/同步开关/日志目录/更新检查 + 返回键。 */
function SettingsScreen() {
  return (
    <Screen
      {...screenChrome("设置")}
      headerLeft={<CardMindIconButton icon="back" tooltip="返回" onPress={goBack} />}
    >
      <SettingsPage status={<PhaseOneStatus />} />
    </Screen>
  );
}

/** 编辑器页（push 路由）：WebView + JSON 消息协议（施工 3.2/3.3/3.4）。
 *  html 字符串 = index.html（含内联 bundle.js）；baseUrl 固定，供 WebView2
 *  WebResourceRequested 拦截解析相对 URL。原生↔页协议：
 *    原生→页 sendRequest({id,type,...}) 8s 超时等 {id,type:"res"}
 *    页→原生 {type:"editor-ready"|"dirty"|"markdown"|"res", ...}
 *  markdown 进：editor-ready → noteGet → sendRequest("load", {markdown})
 *  markdown 出：dirty/markdown 事件 → noteCreate + noteUpdateMetadata
 *  可安全退出：返回前若 dirty → get-markdown 存完 → goBack。 */
const PROTO_TIMEOUT_MS = 8000;

function EditorScreen(props: { noteId: string }) {
  const bridge = signal("编辑器桥：(等待 editor-ready)");
  const saveState = signal("已保存");
  // 3.5：标签行（当前笔记标签）+ 选区联动（页内 selection 事件 → 原生侧标签高亮）。
  const noteTags = signal<string[]>([]);
  const selText = signal(""); // 页内选区文本（空 = 无光标选区）
  const selTextBefore = signal(""); // 光标前一小段文本（页内带过来探测 [[ 补全）
  // 命中 selection（[[prefix 或选中文字）的标签集合——任一 selection 不再全高亮。
  const selHits = signal<string[]>([]);
  // [[ 前缀链补全：页内文本含 [[prefix 时拉 autoCompleteLinks 候选。
  const linkCandidates = signal<string[]>([]);
  let web!: YNode;
  let noteId = props.noteId;
  let reqSeq = 0;
  const pending = new Map<number, (res: any) => void>();
  let editorReady = false;
  let editorDirty = false;
  let tags: string[] = [];
  // 新笔记（空 id 或 "new"）尚无落盘内容：初始态是「尚未保存」，不是「已保存」。
  if (noteId === "" || noteId === "new") saveState.set("尚未保存");

  /** 原生 → 页：发 JSON；带 id 的请求挂 8s 超时。 */
  function postToPage(msg: Record<string, unknown>): void {
    web.postMessage(JSON.stringify(msg));
  }
  function sendRequest(type: string, payload: Record<string, unknown> = {}): Promise<any> {
    const id = ++reqSeq;
    return new Promise((resolve) => {
      const timer = setTimeout(() => {
        if (pending.delete(id)) resolve({ ok: false, error: "timeout" });
      }, PROTO_TIMEOUT_MS);
      pending.set(id, (res) => {
        clearTimeout(timer);
        resolve(res);
      });
      postToPage({ id, type, ...payload });
    });
  }

  /** 保存：空 noteId 先 generateNoteId，再 noteCreate + noteUpdateMetadata。 */
  async function saveMarkdown(markdown: string): Promise<void> {
    const md = markdown.trim();
    if (md === "") return;
    saveState.set("正在保存");
    try {
      if (noteId === "" || noteId === "new") {
        noteId = await BackendStore.generateNoteId();
      }
      await BackendNotes.noteCreate(noteId, markdown);
      await BackendNotes.noteUpdateMetadata(noteId, tags);
      await BackendNotes.syncNotesToStore();
      editorDirty = false;
      saveState.set("已保存");
    } catch (err) {
      saveState.set("尚未保存");
      console.error(`[editor] 保存失败：${err}`);
    }
  }

  /** 从页取最新 markdown 并存下（返回前兜底，对照 Dart `_close`）。 */
  async function flushMarkdown(): Promise<void> {
    const res = await sendRequest("get-markdown");
    if (res?.ok && typeof res.markdown === "string") {
      await saveMarkdown(res.markdown);
    }
  }

  /** 返回键：有 dirty 先 flushMarkdown，再 goBack。 */
  function closeEditor(): void {
    if (!editorReady || !editorDirty) {
      goBack();
      return;
    }
    void flushMarkdown().then(goBack).catch(goBack);
  }

  /** editor-ready：加载 noteGet → load；新笔记跳过加载。 */
  async function onEditorReady(): Promise<void> {
    editorReady = true;
    bridge.set("编辑器桥：editor-ready ✓");
    if (noteId !== "" && noteId !== "new") {
      try {
        const content = await BackendNotes.noteGet(noteId);
        if (content != null) {
          await sendRequest("load", { markdown: content });
          editorDirty = false;
          saveState.set("已保存");
        }
      } catch (err) {
        console.error(`[editor] 加载失败：${err}`);
      }
      // 3.5：把当前笔记标签读进标签行 + 经 set-tags 发给页内标签区。
      await loadNoteTags();
    }
  }

  /** 读当前笔记标签（读模型 searchByTag(\"\") 全量行 → 找 noteId → 拆 CSV）。 */
  async function loadNoteTags(): Promise<void> {
    try {
      const rows = await BackendNotes.searchByTag("");
      const row = rows.find((r: { id: string }) => r.id === noteId);
      const csv = (row?.tags ?? "") as string;
      tags = csv
        .split(",")
        .map((t) => t.trim())
        .filter((t) => t.length > 0);
    } catch {
      tags = [];
    }
    noteTags.set(tags);
    void sendRequest("set-tags", { tags });
  }

  /** [[prefix]] 前缀链补全：从 autoCompleteLinks 拉候选标题。 */
  async function refreshLinkCandidates(prefix: string): Promise<void> {
    try {
      const rows = await BackendNotes.autoCompleteLinks(prefix);
      linkCandidates.set(
        rows.map((r: { title?: string; id?: string }) => r.title ?? r.id ?? ""),
      );
    } catch {
      linkCandidates.set([]);
    }
  }

  /** 选区事件：更新原生侧选区文本 + 检测 [[prefix 触发补全。
   *  D5：折叠选区（正常打字）text 恒 ""，必须用 textBefore 探测 [[。 */
  function onSelection(sel: { text: string; textBefore: string }): void {
    selText.set(sel.text);
    selTextBefore.set(sel.textBefore);
    // 只高亮命中 [[prefix 或选中文字的标签（D7），不是任一 selection 全高亮。
    selHits.set(matchTags(noteTags(), { text: sel.text, textBefore: sel.textBefore }));
    // [[prefix 只看光标前文本（打字路径）；已闭合 [[x]] / 普通文字不触发。
    const prefix = linkPrefixFromContext(sel.textBefore);
    if (prefix !== null) {
      void refreshLinkCandidates(prefix);
    } else if (linkCandidates().length > 0) {
      linkCandidates.set([]);
    }
  }

  /** 页 → 原生事件/响应分发。 */
  function onBridgeMessage(raw: string): void {
    let msg: { type?: string; id?: number; ok?: boolean; markdown?: string; dirty?: boolean; error?: string; text?: string; textBefore?: string; from?: number; to?: number };
    try {
      msg = JSON.parse(raw);
    } catch {
      if (raw === "editor-ready") void onEditorReady();
      return;
    }
    if (msg.type === "res" && typeof msg.id === "number") {
      pending.get(msg.id)?.(msg);
      pending.delete(msg.id);
      return;
    }
    switch (msg.type) {
      case "editor-ready":
        void onEditorReady();
        break;
      case "dirty":
        editorDirty = !!msg.dirty;
        if (saveState() !== "正在保存") saveState.set("尚未保存");
        break;
      case "markdown":
        void saveMarkdown(msg.markdown ?? "");
        break;
      case "selection":
        // D5：折叠选区 text 恒 ""，必须带 textBefore 才能探测 [[。
        onSelection({ text: msg.text ?? "", textBefore: msg.textBefore ?? "" });
        break;
      default:
        break;
    }
  }

  return (
    <Screen
      {...screenChrome("编辑")}
      headerLeft={<CardMindIconButton icon="back" tooltip="返回" onPress={closeEditor} />}
    >
      <View style={{ flex: 1, backgroundColor: colors.paper }}>
        <View style={{ flexDirection: "row", gap: spacing.md, padding: spacing.sm }}>
          <Text numberOfLines={1} style={{ flex: 1, color: colors.mutedInk }}>
            {`noteId：${noteId}`}
          </Text>
          <Text style={{ color: colors.mutedInk }}>{saveState()}</Text>
          <Text style={{ color: colors.mutedInk }}>{bridge()}</Text>
        </View>
        {/* 3.5 最小标签行：当前笔记标签（selection 命中 [[prefix/选中文字才高亮）。 */}
        <If when={noteTags().length > 0}>
          <View
            style={{
              flexDirection: "row",
              flexWrap: "wrap",
              gap: spacing.sm,
              paddingHorizontal: spacing.sm,
              paddingBottom: spacing.sm,
            }}
          >
            {() =>
              noteTags().map((t) => (
                <CardMindTag
                  label={t}
                  selected={selHits().includes(t)}
                  comfortable
                  onTap={() => void sendRequest("insert-link", { title: t })}
                />
              ))
            }
          </View>
        </If>
        {/* [[ 前缀链补全：页内 selection 文本含 [[prefix → autoCompleteLinks 候选。 */}
        <If when={linkCandidates().length > 0}>
          <View
            style={{
              flexDirection: "row",
              flexWrap: "wrap",
              gap: spacing.sm,
              paddingHorizontal: spacing.sm,
              paddingBottom: spacing.sm,
            }}
          >
            {() =>
              linkCandidates().map((title) => (
                <CardMindTag
                  label={title}
                  comfortable
                  onTap={() => void sendRequest("insert-link", { title })}
                />
              ))
            }
          </View>
        </If>
        <WebView
          ref={web}
          source={{ html: EDITOR_HTML, baseUrl: EDITOR_BASE_URL }}
          style={{ flex: 1, backgroundColor: colors.paper }}
          onMessage={(e) => onBridgeMessage(e.data)}
        />
      </View>
    </Screen>
  );
}

/** 路由 → 页面。 */
function renderRoute(route: Route) {
  switch (route.name) {
    case "trash":
      return <TrashScreen />;
    case "devices":
      return <DevicesScreen />;
    case "settings":
      return <SettingsScreen />;
    case "editor":
      return <EditorScreen noteId={route.noteId} />;
    case "notes":
    default:
      return <NotesScreen />;
  }
}

function Root() {
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      <App />
      <Stack navigator={nav} style={{ flex: 1 }}>
        {(route: Route) => renderRoute(route)}
      </Stack>
    </View>
  );
}

mount(Root);
