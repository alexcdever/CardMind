// CardMind 回收站页（施工方案 2.3）：对照 lib/pages/trash_page.dart。
//
// 功能：列已删笔记（BackendNotes.storeTrashList，含标题 + 删除时间）、
// 恢复（noteRestore）、彻底删除（notePurge，走 CardMindConfirmDialog 危险
// 确认）、定期清理（purgeExpiredTrash，cutoff = now-30d RFC3339，同样走
// 危险确认）、空态（CardMindEmptyState）。
//
// 列表主体用 <List>（virtual_list）——与列表页同一回收复用，回收站也可能
// 积累数百条墓碑。每条行尾挂「恢复」「彻底删除」两个 48×48 图标按钮。
//
// 令牌纪律：所有颜色 / 间距 / 圆角 / 触摸目标全部来自 ./theme，禁止裸值。
//
// 结构（P2-4 纯结构拆分）：本文件仅保留页面根 `TrashPage` 与公共 API 的
// re-export；类型/常量/文本工具/状态/列表行分别落在 `./trash_page/` 子模块。
// render 段 JSX 与交互逐字不变；signals 仍是 state.ts 模块顶层单例（单一
// 创建点）。
import { effect, List, Text, View } from "nsh";
import type { JSX } from "nsh";
import {
  CardMindConfirmDialog,
  CardMindEmptyState,
  Glyph,
  panel,
} from "./components";
import { colors, layout, radii, spacing, typography } from "./theme";
import { estimatedRowHeight } from "./trash_page/constants";
import { displayTitle } from "./trash_page/helpers";
import { TrashRow } from "./trash_page/sections";
import {
  actionMessage,
  busy,
  cancelPurge,
  cancelPurgeExpired,
  confirmPurge,
  confirmPurgeExpired,
  items,
  loadError,
  loading,
  loadTrashWithRetry,
  purgeExpiredConfirm,
  purgeTarget,
  requestPurgeExpired,
} from "./trash_page/state";

export type { TrashNoteDto, TrashSource } from "./trash_page/types";
export { setTrashSource } from "./trash_page/state";

// ─── 页面根 ─────────────────────────────────────────────────────────────────

/**
 * 回收站页：标题行（计数 + 「清理 30 天前」按钮）+ 列表/空态。
 *
 * `status` 插槽：调用方传入的状态面板（App.tsx 的 Phase 1 后端证据行），
 * 渲染在页面底部。
 */
export function TrashPage(props: { status?: JSX.Element }): JSX.Element {
  effect(() => {
    void loadTrashWithRetry();
  });
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      {/* 顶部说明 + 定期清理入口 */}
      <View
        style={{
          flexDirection: "row",
          alignItems: "center",
          minHeight: layout.mobileTouchTarget,
          paddingHorizontal: spacing.lg,
          paddingVertical: spacing.sm,
          borderBottomWidth: 1,
          borderBottomColor: colors.border,
          gap: spacing.sm,
        }}
      >
        <Glyph name="trash" size={20} tint={colors.mutedInk} />
        <View style={{ flex: 1 }}>
          <Text
            style={{
              fontSize: typography.bodyMedium.fontSize,
              color: colors.mutedInk,
            }}
          >
            {() =>
              loading()
                ? "加载中…"
                : `${items().length} 条已删笔记 · 保留 30 天`
            }
          </Text>
        </View>
        <View
          onPress={requestPurgeExpired}
          role="button"
          accessibilityLabel="清理 30 天前的笔记"
          accessibilityState={{ disabled: busy() }}
          style={{
            minHeight: layout.mobileTouchTarget,
            paddingHorizontal: spacing.md,
            alignItems: "center",
            justifyContent: "center",
            borderRadius: radii.md,
            borderWidth: 1,
            borderColor: colors.border,
            opacity: busy() ? 0.4 : 1,
          }}
        >
          <Text
            style={{
              color: colors.danger,
              fontSize: typography.bodyMedium.fontSize - 3,
              fontWeight: "600",
            }}
          >
            清理过期
          </Text>
        </View>
      </View>

      {/* 列表主体 */}
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
          if (loadError() !== undefined) {
            return (
              <CardMindEmptyState
                icon="trash"
                title="加载失败"
                message={loadError() ?? ""}
              />
            );
          }
          if (items().length === 0) {
            return (
              <CardMindEmptyState
                icon="trash"
                title="回收站是空的"
                message="删除的笔记会在这里保留 30 天，之后自动清理。"
              />
            );
          }
          return (
            <List
              each={items()}
              keyExtractor={(n) => n.id}
              estimatedItemSize={estimatedRowHeight}
              style={{ flex: 1 }}
            >
              {(note, _index) => <TrashRow note={note} />}
            </List>
          );
        }}
      </View>

      {/* 操作反馈行 */}
      <View
        style={{
          paddingHorizontal: spacing.lg,
          paddingVertical: spacing.sm,
          borderTopWidth: 1,
          borderTopColor: colors.border,
          backgroundColor: panel.sidebar,
        }}
      >
        <Text
          style={{
            color: colors.mutedInk,
            fontSize: typography.bodyMedium.fontSize - 3,
          }}
        >
          {() => actionMessage() ?? "恢复/删除后列表自动刷新"}
        </Text>
      </View>

      <If when={props.status !== undefined}>{props.status}</If>

      {/* 彻底删除确认（危险态） */}
      <CardMindConfirmDialog
        visible={purgeTarget() !== undefined}
        title="彻底删除？"
        message={`「${purgeTarget() ? displayTitle(purgeTarget()!) : "无标题"}」将被永久删除，无法恢复。`}
        confirmLabel="彻底删除"
        onConfirm={confirmPurge}
        onCancel={cancelPurge}
        danger
      />
      {/* 定期清理确认（危险态） */}
      <CardMindConfirmDialog
        visible={purgeExpiredConfirm()}
        title="清理过期笔记？"
        message="删除超过 30 天的笔记将被永久移除，无法恢复。"
        confirmLabel="清理"
        onConfirm={confirmPurgeExpired}
        onCancel={cancelPurgeExpired}
        danger
      />
    </View>
  );
}
