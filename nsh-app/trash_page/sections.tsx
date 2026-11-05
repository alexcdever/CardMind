// 回收站页区块组件（自 trash_page.tsx 纯结构拆出，JSX 逐字保留）。
import { View, type JSX } from "nsh";
import { CardMindIconButton, CardMindListItem } from "../components";
import { spacing } from "../theme";
import { displayTitle, formatDate } from "./helpers";
import { requestPurge, restore } from "./state";
import type { TrashNoteDto } from "./types";

// ─── 列表行 ──────────────────────────────────────────────────────────────────

export function TrashRow(props: { note: () => TrashNoteDto }): JSX.Element {
  const note = props.note;
  return (
    <CardMindListItem
      title={displayTitle(note())}
      subtitle={`删除于 ${formatDate(note().deletedAt ?? note().updatedAt)}`}
      trailing={
        <View
          style={{
            flexDirection: "row",
            alignItems: "center",
            gap: spacing.xs,
          }}
        >
          <CardMindIconButton
            icon="restore"
            tooltip={`恢复「${displayTitle(note())}」`}
            onPress={() => void restore(note())}
          />
          <CardMindIconButton
            icon="delete"
            tooltip={`彻底删除「${displayTitle(note())}」`}
            onPress={() => requestPurge(note())}
          />
        </View>
      }
    />
  );
}
