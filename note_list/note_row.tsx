// 列表行（单个 Cell 的 JSX）。自 note_list.tsx 纯结构拆出，JSX 与样式逐字保留。
import { AnimatedValue, PanResponder, Text, View } from "nsh";
import type { JSX } from "nsh";
import { CardMindIconButton, CardMindListItem } from "../components";
import { colors, spacing, typography } from "../theme";
import { displayTitle, formatDate, previewLine, swipeTrigger } from "./helpers";
import { openNote, requestDelete, selectedNoteId } from "./state";
import type { NoteDto } from "./types";

export function NoteRow(props: {
  note: () => NoteDto;
  index: () => number;
  desktop: boolean;
}): JSX.Element {
  const note = props.note;
  const selected = () => props.desktop && selectedNoteId() === note().id;

  // ── 滑动删除的纯视觉手势层 ──
  // AnimatedValue 驱动 translateX（UI 线程）；release 过阈值 → requestDelete，
  // 无论删除与否都 spring 归零。真实删除的是 requestDelete 里弹的确认对话框。
  const dragX = new AnimatedValue(0);
  const responder = PanResponder.create({
    onMoveShouldSetPanResponder: (_, g) =>
      Math.abs(g.dx) > Math.abs(g.dy) && g.dx < -spacing.xs,
    onPanResponderMove: (_, g) => dragX.set(Math.min(0, g.dx)),
    onPanResponderRelease: (_, g) => {
      if (g.dx < -swipeTrigger) {
        requestDelete(note());
      }
      dragX.spring(0, { velocity: g.vx, stiffness: 180, damping: 22 });
    },
    onPanResponderTerminate: () =>
      dragX.spring(0, { stiffness: 180, damping: 22 }),
  });

  return (
    <View
      {...responder.panHandlers}
      testID={`note-${note().id}`}
      accessibilityLabel={`笔记：${displayTitle(note())}`}
      role="button"
      accessibilityState={{ selected: selected() }}
      style={{
        transform: [{ translateX: dragX }],
        backgroundColor: colors.surfaceRaised,
      }}
    >
      <CardMindListItem
        title={displayTitle(note())}
        subtitle={previewLine(note())}
        selected={selected()}
        onPress={() => openNote(note().id)}
        trailing={
          <View
            style={{
              flexDirection: "row",
              alignItems: "center",
              gap: spacing.sm,
            }}
          >
            <Text
              style={{
                color: colors.mutedInk,
                fontSize: typography.bodyMedium.fontSize - 3,
                fontWeight: "600",
              }}
            >
              {formatDate(note().updatedAt)}
            </Text>
            {/* 无障碍删除替代：每个列表项的可见删除按钮（48×48）。 */}
            <CardMindIconButton
              icon="delete"
              tooltip={`删除「${displayTitle(note())}」`}
              onPress={() => requestDelete(note())}
            />
          </View>
        }
      />
    </View>
  );
}
