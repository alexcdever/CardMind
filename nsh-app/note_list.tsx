// CardMind 笔记列表页（施工方案 2.2 + 2.7）：对照 lib/pages/note_list_page.dart。
//
// 布局：宽度 ≥ layout.desktopBreakpoint(960) → 桌面三栏（侧栏 240 | 列表 360 |
// 编辑器）；<960 → 移动布局（搜索 + 标签 + 列表，底部双 Tab「笔记/设备」）。
//
// 交互：CardMindSearchField 搜索（BackendNotes.searchNotes，300ms 去抖）+
// CardMindTag 标签行（BackendNotes.getAllTags / searchByTag）+ 行内删除按钮
// 软删除（BackendNotes.noteSoftDelete）+ 滑动手势删除（PanResponder 翻译，纯
// 视觉手势层）+ CardMindEmptyState 空态。
//
// 滑动删除的无障碍替代：每个列表项本身挂一个 48×48 删除按钮（不论桌面/移动、
// 不论是否支持滑动手势都在）——滑动手势只是触觉增强，删除的真实入口是按钮。
//
// 虚拟化：列表主体是 <List>（"nsh" 导出的 virtual_list）：只渲染视口附近的
// 行，单元格被回收。行 key 用稳定 note.id（keyExtractor）。
//
// 令牌纪律：所有颜色 / 间距 / 圆角 / 触摸目标全部来自 ./theme，禁止裸值。
//
// 结构（P2-2a 纯结构拆分）：本文件仅保留页面根 `NoteListPage`（组合组件）与
// 公共 API 的 re-export；类型/helper/状态/行/Tab/列表体/桌面/移动分别落在
// `./note_list/` 子模块。视觉、交互、导出行为均未改变。
import { cleanup, effect, keymap, View } from "nsh";
import type { JSX } from "nsh";
import { CardMindConfirmDialog } from "./components";
import { colors } from "./theme";
import { DesktopLayout } from "./note_list/desktop";
import { MobileLayout } from "./note_list/mobile";
import {
  cancelDelete,
  confirmDelete,
  deleteTarget,
  isDesktop,
  loadNotesWithRetry,
  notes,
  requestDelete,
  selectedNoteId,
} from "./note_list/state";

export { goBack } from "./navigation";
export { setNoteListSource } from "./note_list/state";
export type { NoteDto, NoteListSource } from "./note_list/types";

// ─── 页面根 ─────────────────────────────────────────────────────────────────

/**
 * 笔记列表页：双布局 + 搜索 + 标签过滤 + 软删除 + 空态 + 虚拟化。
 *
 * 桌面 ≥960：侧栏 | 列表 | 编辑器；移动 <960：搜索 + 标签 + 列表 + 双 Tab。
 *
 * `status` 可选插槽：当前无调用方（App.tsx 的 Phase 1 证据行已随演示脚手架
 * 删除），保留为后续状态面板的注入点——桌面渲染在编辑器占位栏、移动渲染在
 * 「设备」Tab。
 */
export function NoteListPage(props: { status?: JSX.Element }): JSX.Element {
  // 首次装载：读一次列表 + 标签（Dart _loadNotes + _initSyncStatus 合并）；
  // store 可能与 App 层 createNoteStore 并发未开，重试三次。
  effect(() => {
    void loadNotesWithRetry();
  });
  // 键盘删除入口（桌面）：选中态 + Delete 键 → 弹同一个确认对话框。
  // 移动端无物理键盘，这条绑定自然不触发（`nsh` 的 keymap 在非桌面只保留注册）。
  const unbindDelete = keymap.bind("delete", () => {
    const id = selectedNoteId();
    if (id === undefined) return;
    const target = notes().find((n) => n.id === id);
    if (target) requestDelete(target);
  });
  cleanup(unbindDelete);
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      <If when={isDesktop()} else={<MobileLayout status={props.status} />}>
        <DesktopLayout status={props.status} />
      </If>
      <CardMindConfirmDialog
        visible={deleteTarget() !== undefined}
        title="删除笔记"
        message={`「${deleteTarget()?.title ?? "无标题"}」会移入回收站，30 天内可恢复。`}
        confirmLabel="删除"
        onConfirm={confirmDelete}
        onCancel={cancelDelete}
        danger
      />
    </View>
  );
}

/** 兼容命名：App.tsx 三栏骨架里占位的名字。 */
export { NoteListPage as NoteList };
