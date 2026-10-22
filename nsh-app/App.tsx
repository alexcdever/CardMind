import { mount, signal, Text, View } from "nsh";
import { App, Backend, BackendStore, Bridge } from "app/native";

// 真后端演示（施工方案 1.4）：`BackendStore.*` 走 Rust 侧的全局 `NoteStore`
// 单例（`static STORE: OnceLock<NoteStore>`），结果直接渲染出来——不是占位文案。
function Root() {
  const device = signal("设备ID：(调用中…)");
  const storeStatus = signal("Store：(初始化中…)");
  const noteId = signal("笔记ID：(生成中…)");
  const syncId = signal("同步ID：(创建中…)");
  const listLine = signal("列表：(查询中…)");
  const searchLine = signal("搜索：(查询中…)");
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

    // SQLite 直查：列表 + 搜索（都是真表查询）
    const rows = await BackendStore.storeList();
    listLine.set(`列表：${rows.length} 条`);
    const hits = await BackendStore.storeSearch("笔记");
    searchLine.set(`搜索「笔记」：${hits.length} 条`);

    // 走全局 SYNC 单例：真建 SyncService（iroh endpoint），证明全局单例
    // 承载的是真后端，不是占位。ensure_sync() 内部惰性 new。
    const sync = await BackendStore.syncDeviceId();
    syncId.set(`同步ID：${sync}`);
  })();
  return (
    <View style={{ flex: 1, padding: 12, gap: 8 }}>
      <App />
      <Text>{syncId()}</Text>
      <Text>{device()}</Text>
      <Text>{storeStatus()}</Text>
      <Text>{noteId()}</Text>
      <Text>{listLine()}</Text>
      <Text>{searchLine()}</Text>
      <Bridge
        onSyncProgress={(n) => last.set(`最近事件：SyncProgress(${n})`)}
        onPeerFound={(name) => last.set(`最近事件：PeerFound(${name})`)}
      />
      <Text>{last()}</Text>
    </View>
  );
}

mount(Root);
