// 标签过滤条。自 note_list.tsx 纯结构拆出，JSX 与样式逐字保留。
import { Scroll } from "nsh";
import type { JSX } from "nsh";
import { CardMindTag } from "../components";
import { spacing } from "../theme";
import { allTags, selectTag, selectedTag } from "./state";

export function TagFilterBar(props: { comfortable?: boolean }): JSX.Element {
  return (
    <Scroll
      horizontal
      scrollbar={false}
      style={{
        flexDirection: "row",
        paddingBottom: spacing.md,
      }}
      contentStyle={{
        flexDirection: "row",
        gap: spacing.sm,
      }}
    >
      {() =>
        allTags().map((tag) => (
          <CardMindTag
            label={tag}
            selected={selectedTag() === tag}
            comfortable={props.comfortable === true}
            onTap={() => selectTag(tag)}
          />
        ))
      }
    </Scroll>
  );
}
