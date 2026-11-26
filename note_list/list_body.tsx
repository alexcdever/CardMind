// 列表主体（虚拟化 + 空态分支）。自 note_list.tsx 纯结构拆出，JSX 与样式逐字保留。
import { List, Text, View } from "nsh";
import type { JSX } from "nsh";
import { CardMindEmptyState } from "../components";
import { colors } from "../theme";
import { estimatedRowHeight } from "./helpers";
import { NoteRow } from "./note_row";
import {
  displayedNotes,
  isSearching,
  loading,
  notes,
  searchError,
} from "./state";

export function ListBody(props: { desktop: boolean }): JSX.Element {
  // 整体放进响应式 thunk：loading/notes/displayedNotes 变化时整段重估。
  return (
    <View style={{ flex: 1 }}>
      {() => {
        if (loading()) {
          return (
            <View
              style={{
                flex: 1,
                alignItems: "center",
                justifyContent: "center",
              }}
            >
              <Text style={{ color: colors.mutedInk }}>加载中…</Text>
            </View>
          );
        }
        if (notes().length === 0 && !isSearching()) {
          return (
            <CardMindEmptyState
              icon="notes"
              title="还没有笔记"
              message="创建第一篇笔记，内容会保存在这台设备上。"
            />
          );
        }
        if (searchError() !== undefined) {
          return (
            <CardMindEmptyState
              icon="search"
              title="搜索失败"
              message={searchError() ?? ""}
            />
          );
        }
        if (displayedNotes().length === 0) {
          return (
            <CardMindEmptyState
              icon="search"
              title="没有匹配结果"
              message={
                isSearching() ? "试试更短的关键词。" : "当前标签下没有笔记。"
              }
            />
          );
        }
        // 虚拟列表（施工 2.7）：`nsh` 导出的 virtual_list 只创建视口附近的行。
        return (
          <List
            each={displayedNotes()}
            keyExtractor={(n) => n.id}
            estimatedItemSize={estimatedRowHeight}
            style={{ flex: 1 }}
          >
            {(note, index) => (
              <NoteRow note={note} index={index} desktop={props.desktop} />
            )}
          </List>
        );
      }}
    </View>
  );
}
