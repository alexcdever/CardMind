import { mount, signal, Text, View } from "nsh";
import { NavPage, NavStack } from "nsh/base";
import { BackendStore, BackendSync } from "app/native";
import { CardMindIconButton } from "./components";
import { DevicesPage } from "./devices_page";
import { EditorScreen } from "./editor_page";
import { NoteListPage } from "./note_list";
import { goBack, nav, screenChrome, type Route } from "./navigation";
import { SettingsPage } from "./settings_page";
import { TrashPage } from "./trash_page";
import { colors, spacing } from "./theme";

/** 启动失败原因（正常路径下恒为 undefined，不渲染）。 */
const startupError = signal<string | undefined>(undefined);

// 启动顺序是硬依赖，不能调换：
//   1. `dataDir()` 返回 `"{dir}|{exists}"`——旧版数据目录优先（数据共存 4.4），
//      否则 NSH 自有目录；只取 `dir` 段。
//   2. `createNoteStore()` 必须在任何页面读列表之前打开全局 store（单例语义：
//      已打开则复用，忽略新 path）。
//   3. `syncDeviceId()` 惰性创建真 `SyncService`（iroh endpoint，持久化到同一
//      dataDir，复用旧 `cardmind.loro` / `device.key`）。
//   4. `startReceiver()` 启动被动接收任务（依赖 store 已打开）；**不再 close()**：
//      进程存活期间接收器要一直跑。
// 启动失败不阻塞 UI：页面各自有加载/错误态，这里只把原因显示在顶栏。
void (async () => {
  try {
    const info = await BackendStore.dataDir();
    const [dataDir] = info.split("|");
    await BackendStore.createNoteStore(`${dataDir}/cardmind.db`);
    await BackendStore.syncDeviceId();
    await BackendSync.startReceiver();
  } catch (error) {
    startupError.set(`启动失败：${String(error)}`);
  }
})();

/** notes 根页面：新列表页（内部 ≥960 桌面三栏 / <960 移动堆叠 + 双 Tab）。 */
function NotesScreen() {
  return (
    <NavPage {...screenChrome("笔记")}>
      <NoteListPage />
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
      <TrashPage />
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
      <DevicesPage />
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
      <SettingsPage />
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
      <If when={startupError() !== undefined}>
        <Text style={{ color: colors.danger, padding: spacing.lg }}>
          {startupError() ?? ""}
        </Text>
      </If>
      <NavStack state={nav} style={{ flex: 1 }}>
        {(route: Route) => renderRoute(route)}
      </NavStack>
    </View>
  );
}

mount(Root);
