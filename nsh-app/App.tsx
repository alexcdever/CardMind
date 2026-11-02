import { mount, signal, Text, View } from "nsh";
import { NavPage, NavStack } from "nsh/base";
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
  CardMindSyncStatus,
} from "./components";
import { DevicesPage } from "./devices_page";
import { EditorScreen } from "./editor_page";
import { NoteListPage } from "./note_list";
import { goBack, nav, routes, screenChrome, type Route } from "./navigation";
import { SettingsPage } from "./settings_page";
import { TrashPage } from "./trash_page";
import { colors, spacing } from "./theme";

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

  // 打开全局 store：优先旧版数据目录（数据共存 4.4），否则 NSH 自有目录。
  // dataDir() 返回 "{dir}|{exists}"；旧 db 存在 = 找到旧数据，否则首次运行。
  const info = await BackendStore.dataDir();
  const [dataDir, foundLegacy] = info.split("|");
  const opened = await BackendStore.createNoteStore(`${dataDir}/cardmind.db`);
  storeStatus.set(
    foundLegacy === "true" ? `Store：找到旧数据 ${opened}` : `Store：首次运行 ${opened}`,
  );

  // 纯 Rust 生成 UUID v7
  const fresh = await BackendStore.generateNoteId();
  noteId.set(`笔记ID：${fresh}`);

  // 真建 SyncService（iroh endpoint）；后续 notes/sync/pairing 全走它
  const sync = await BackendStore.syncDeviceId();
  syncId.set(`同步ID：${sync}`);

  // ── 1.1 Backend.Notes ──
  // 安全：旧数据目录是**用户真实数据**，绝不写入演示笔记。演示写只在 NSH 自有
  // 目录（首次运行）里跑，用来保留 1.1 的验收证据；找到旧数据时改为只读展示。
  if (foundLegacy !== "true") {
    await BackendNotes.noteCreate(fresh, "# 测试笔记\n\n正文 markdown");
    await BackendNotes.noteUpdateMetadata(fresh, ["标签A", "标签B"]);
    await BackendNotes.noteSoftDelete(fresh);
    await BackendNotes.syncNotesToStore();
  }

  // 读回一条真实笔记内容（旧数据时读用户第一条；演示态读刚建的那条）。
  const listIds = await BackendNotes.searchByTag("");
  const probeId = foundLegacy === "true" ? (listIds[0]?.id ?? "") : fresh;
  const content = probeId === "" ? null : await BackendNotes.noteGet(probeId);
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
    <NavPage {...screenChrome("笔记")}>
      <NoteListPage status={<PhaseOneStatus />} />
    </NavPage>
  );
}

/** 回收站页：真列表 + 恢复/彻底删除/定期清理 + 返回键。 */
function TrashScreen() {
  return (
    <NavPage
      {...screenChrome("回收站")}
      headerLeft={
        <CardMindIconButton icon="back" tooltip="返回" onPress={goBack} />
      }
    >
      <TrashPage status={<PhaseOneStatus />} />
    </NavPage>
  );
}

/** 设备页：配对全流程 + 已配对设备管理 + 本机信息 + 返回键。 */
function DevicesScreen() {
  return (
    <NavPage
      {...screenChrome("设备")}
      headerLeft={<CardMindIconButton icon="back" tooltip="返回" onPress={goBack} />}
    >
      <DevicesPage status={<PhaseOneStatus />} />
    </NavPage>
  );
}

/** 设置页：真设备名/同步开关/日志目录/更新检查 + 返回键。 */
function SettingsScreen() {
  return (
    <NavPage
      {...screenChrome("设置")}
      headerLeft={<CardMindIconButton icon="back" tooltip="返回" onPress={goBack} />}
    >
      <SettingsPage status={<PhaseOneStatus />} />
    </NavPage>
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
      <NavStack state={nav} style={{ flex: 1 }}>
        {(route: Route) => renderRoute(route)}
      </NavStack>
    </View>
  );
}

mount(Root);
