// 移动布局（堆叠 + 双 Tab）。自 note_list.tsx 纯结构拆出，JSX 与样式逐字保留。
//
// 说明（AC2）：`tab` 是本组件**实例级** UI 状态（每次挂载从「笔记」Tab 开始），
// 不是跨组件共享的模块单例；迁到 state.ts 会改变「桌面↔移动切换重挂载后选中
// Tab 是否复位」的语义，故按「零行为变化」保留在此，未上提。
import { signal, Text, View } from "nsh";
import type { JSX } from "nsh";
import {
  CardMindIconButton,
  CardMindPrimaryButton,
  CardMindSearchField,
  CardMindSyncStatus,
  Glyph,
} from "../components";
import { nav, openEditor, routes } from "../navigation";
import { colors, layout, spacing, typography } from "../theme";
import { ListBody } from "./list_body";
import { allTags, clearSearch, isSearching, onSearchChanged, searchText } from "./state";
import { TagFilterBar } from "./tag_filter_bar";

export function MobileNotesTab(): JSX.Element {
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      <View style={{ padding: spacing.lg, paddingBottom: spacing.md }}>
        <CardMindSearchField
          value={searchText}
          onChanged={onSearchChanged}
          onClear={clearSearch}
          mobile
        />
        <If when={!isSearching() && allTags().length > 0}>
          <View style={{ height: spacing.md }} />
          <TagFilterBar comfortable />
        </If>
      </View>
      <ListBody desktop={false} />
    </View>
  );
}

export function MobileDevicesTab(props: { status?: JSX.Element }): JSX.Element {
  return (
    <View
      style={{
        flex: 1,
        backgroundColor: colors.paper,
        padding: spacing.lg,
        gap: spacing.sm,
      }}
    >
      <Text style={{ color: colors.mutedInk }}>设备页在「设备」页（2.5 实现）。</Text>
      <CardMindPrimaryButton
        label="打开设备页"
        icon="devices"
        onPress={() => nav.push(routes.devices)}
      />
      <If when={props.status !== undefined}>{props.status}</If>
    </View>
  );
}

export function MobileLayout(props: { status?: JSX.Element }): JSX.Element {
  const tab = signal<"notes" | "devices">("notes");
  return (
    <View style={{ flex: 1, backgroundColor: colors.paper }}>
      <View
        style={{
          flexDirection: "row",
          alignItems: "center",
          minHeight: layout.mobileTouchTarget,
          paddingHorizontal: spacing.lg,
          borderBottomWidth: 1,
          borderBottomColor: colors.border,
          gap: spacing.sm,
        }}
      >
        <Text
          style={{
            flex: 1,
            fontSize: typography.titleMedium.fontSize,
            lineHeight: typography.titleMedium.lineHeight,
            fontWeight: "600",
            color: colors.ink,
          }}
        >
          {tab() === "notes" ? "CardMind" : "设备"}
        </Text>
        {/* 移动端新建入口（<960 无桌面侧栏，列表页头直接建笔记 → push 编辑路由）。 */}
        <CardMindIconButton
          icon="add"
          tooltip="新建笔记"
          onPress={() => openEditor("new")}
        />
        <CardMindIconButton
          icon="settings"
          tooltip="设置"
          onPress={() => nav.push(routes.settings)}
        />
        <CardMindIconButton
          icon="trash"
          tooltip="回收站"
          onPress={() => nav.push(routes.trash)}
        />
        <CardMindSyncStatus label="已就绪" pendingCount={0} />
      </View>
      <If when={tab() === "notes"} else={<MobileDevicesTab status={props.status} />}>
        <MobileNotesTab />
      </If>
      {/* 双 Tab 底栏（规范：恰好「笔记」「设备」两个入口）。 */}
      <View
        style={{
          flexDirection: "row",
          borderTopWidth: 1,
          borderTopColor: colors.border,
          backgroundColor: colors.surfaceRaised,
        }}
      >
        <View
          onPress={() => tab.set("notes")}
          role="button"
          accessibilityLabel="笔记"
          accessibilityState={{ selected: tab() === "notes" }}
          style={{
            flex: 1,
            minHeight: layout.mobileTouchTarget,
            alignItems: "center",
            justifyContent: "center",
            borderTopWidth: tab() === "notes" ? 2 : 0,
            borderTopColor: colors.accent,
          }}
        >
          <Glyph name="notes" size={20} tint={tab() === "notes" ? colors.accent : colors.mutedInk} />
          <Text
            style={{
              fontSize: typography.bodyMedium.fontSize - 3,
              color: tab() === "notes" ? colors.accent : colors.mutedInk,
              fontWeight: "600",
              marginTop: spacing.xs,
            }}
          >
            笔记
          </Text>
        </View>
        <View
          onPress={() => tab.set("devices")}
          role="button"
          accessibilityLabel="设备"
          accessibilityState={{ selected: tab() === "devices" }}
          style={{
            flex: 1,
            minHeight: layout.mobileTouchTarget,
            alignItems: "center",
            justifyContent: "center",
            borderTopWidth: tab() === "devices" ? 2 : 0,
            borderTopColor: colors.accent,
          }}
        >
          <Glyph name="devices" size={20} tint={tab() === "devices" ? colors.accent : colors.mutedInk} />
          <Text
            style={{
              fontSize: typography.bodyMedium.fontSize - 3,
              color: tab() === "devices" ? colors.accent : colors.mutedInk,
              fontWeight: "600",
              marginTop: spacing.xs,
            }}
          >
            设备
          </Text>
        </View>
      </View>
    </View>
  );
}
