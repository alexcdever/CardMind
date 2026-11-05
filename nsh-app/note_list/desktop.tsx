// 桌面布局（三栏）。自 note_list.tsx 纯结构拆出，JSX 与样式逐字保留。
import { Text, View } from "nsh";
import type { JSX } from "nsh";
import {
  CardMindListItem,
  CardMindPrimaryButton,
  CardMindSearchField,
  CardMindSyncStatus,
  Glyph,
} from "../components";
import { DesktopEditorPane } from "../editor_page";
import { nav, openEditor, routes } from "../navigation";
import { colors, layout, spacing, typography } from "../theme";
import { ListBody } from "./list_body";
import {
  allTags,
  clearSearch,
  displayedNotes,
  isSearching,
  listHeader,
  notes,
  onSearchChanged,
  searchText,
  selectedNoteId,
} from "./state";
import { TagFilterBar } from "./tag_filter_bar";

export function DesktopSidebar(): JSX.Element {
  return (
    <View
      style={{
        width: layout.sidebarWidth,
        backgroundColor: colors.surfaceLow,
        borderRightWidth: 1,
        borderRightColor: colors.border,
        padding: spacing.lg,
        gap: spacing.md,
      }}
    >
      <Text
        style={{
          fontSize: typography.titleMedium.fontSize,
          lineHeight: typography.titleMedium.lineHeight,
          fontWeight: "600",
          color: colors.ink,
        }}
      >
        CardMind
      </Text>
      <CardMindPrimaryButton
        label="新建笔记"
        icon="add"
        onPress={() => openEditor("new")}
        expanded
      />
      <View
        style={{
          flexDirection: "row",
          alignItems: "center",
          height: spacing.xl + spacing.md,
          paddingLeft: spacing.md,
          borderLeftWidth: 2,
          borderLeftColor: colors.accent,
          backgroundColor: colors.surfaceLow,
        }}
      >
        <Glyph name="notes" size={20} tint={colors.accent} />
        <View style={{ width: spacing.md }} />
        <Text
          style={{
            flex: 1,
            color: colors.accent,
            fontWeight: "600",
            fontSize: typography.bodyMedium.fontSize,
          }}
        >
          笔记
        </Text>
        <Text style={{ color: colors.mutedInk, fontSize: typography.bodyMedium.fontSize - 3 }}>
          {notes().length}
        </Text>
      </View>
      <View style={{ flex: 1 }} />
      <CardMindListItem title="回收站" onPress={() => nav.push(routes.trash)} />
      <CardMindListItem title="设备" onPress={() => nav.push(routes.devices)} />
      <CardMindListItem title="设置" onPress={() => nav.push(routes.settings)} />
      <CardMindSyncStatus label="本地已就绪" pendingCount={0} />
    </View>
  );
}

export function DesktopListPane(): JSX.Element {
  return (
    <View
      style={{
        width: layout.listWidth,
        backgroundColor: colors.paper,
        borderRightWidth: 1,
        borderRightColor: colors.border,
      }}
    >
      <View style={{ padding: spacing.lg }}>
        <View style={{ flexDirection: "row", alignItems: "center" }}>
          <Text
            style={{
              flex: 1,
              fontSize: typography.titleMedium.fontSize,
              lineHeight: typography.titleMedium.lineHeight,
              fontWeight: "600",
              color: colors.ink,
            }}
          >
            {listHeader()}
          </Text>
          <Text
            style={{
              color: colors.mutedInk,
              fontSize: typography.bodyMedium.fontSize - 3,
            }}
          >
            {displayedNotes().length}
          </Text>
        </View>
        <View style={{ height: spacing.lg }} />
        <CardMindSearchField
          value={searchText}
          onChanged={onSearchChanged}
          onClear={clearSearch}
        />
        <If when={!isSearching() && allTags().length > 0}>
          <View style={{ height: spacing.md }} />
          <TagFilterBar />
        </If>
      </View>
      <View style={{ height: 1, backgroundColor: colors.border }} />
      <ListBody desktop />
    </View>
  );
}

export function DesktopLayout(props: { status?: JSX.Element }): JSX.Element {
  return (
    <View
      style={{
        flex: 1,
        flexDirection: "row",
        backgroundColor: colors.paper,
      }}
    >
      <DesktopSidebar />
      <DesktopListPane />
      <View style={{ flex: 1, flexDirection: "column" }}>
        {/* 第三栏：真实编辑区（后端注入走默认 repo）；未选中显示空态。 */}
        <DesktopEditorPane noteId={selectedNoteId} />
        <If when={props.status !== undefined}>{props.status}</If>
      </View>
    </View>
  );
}
