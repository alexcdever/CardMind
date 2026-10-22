import { mount, signal, Text, View } from "nsh";
import {
  App,
  Backend,
  BackendNotes,
  BackendPairing,
  BackendStore,
  BackendSync,
  Bridge,
} from "app/native";

// 真后端演示（施工方案 1.1 + 1.2 + 1.3）：`BackendNotes.*` / `BackendSync.*` /
// `BackendPairing.*` 走 Rust 侧的全局 `SyncService` / `NoteStore` /
// `DiscoveryService` 单例，结果直接渲染出来——不是占位文案。
function Root() {
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
  })();
  return (
    <View style={{ flex: 1, padding: 12, gap: 8 }}>
      <App />
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
      <Bridge
        onSyncProgress={(n) => last.set(`最近事件：SyncProgress(${n})`)}
        onPeerFound={(name) => last.set(`最近事件：PeerFound(${name})`)}
      />
      <Text>{last()}</Text>
    </View>
  );
}

mount(Root);
