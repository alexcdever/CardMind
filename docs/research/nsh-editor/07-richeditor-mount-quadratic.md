# NSH 0.4.0 `RichEditor` 首挂载是 O(块数²)：实测、定位与给 upstream 的 issue 草稿

> 记录时间：2026-11-06　环境：nsh 0.4.0（`e626a8d`）、macOS 27.2 Apple Silicon（M2）、dev/headless（`nsh test`）
> 结论：**不是布局或文本整形的固有成本**，是 `nsh-core` 组件模型里两处「每次按块操作都全表扫」造成的意外 O(N²)。
> 状态：**upstream 尚无相关 issue**（2026-11-06 检索 `RichEditor` / `slow` / `perf` / `hang` / `mount` 等关键词，仅有一条无关的「Web: RichEditor doesn't select text on mouse drag」与两条无关的 Input/DataTable 性能 issue）。
> **处置（2026-11-06 用户裁决）：不上报 upstream。** 触发阈值（千级块）在真实笔记里属极端场景，收益不抵沟通成本。本文与 §6 的 issue 草稿转为**归档**：若将来有用户报「长笔记打开极慢」，直接取这里的数据与 repro 再提。

## 1. 结论

挂载耗时随 **块数（顶层块/段落数）** 平方增长，与字符数几乎无关：

| 变体 | 形态 | 字符数 | 块数 | `createRichEditor` | `<RichEditor>` 挂载 |
|---|---|---|---|---|---|
| A | 100 段 × ~40 字 | 4 690 | 100 | 80 ms | **253 ms** |
| A | 500 段 × ~40 字 | 23 890 | 500 | 97 ms | **2 366 ms** |
| A | 1 000 段 × ~40 字 | 47 890 | 1 000 | 132 ms | **9 741 ms** |
| A | 2 000 段 × ~40 字 | 96 890 | 2 000 | 235 ms | **33 461 ms** |
| B | 1 段 × 5 000 字 | 5 001 | 1 | 54 ms | **199 ms** |
| B | 1 段 × 20 000 字 | 20 001 | 1 | 58 ms | **179 ms** |
| B | 1 段 × 50 000 字 | 50 001 | 1 | 74 ms | **219 ms** |
| C | 200 段 × ~200 字 | 41 490 | 200 | 111 ms | **428 ms** |
| C | 1 000 段 × ~40 字 | 47 890 | 1 000 | 90 ms | **6 117 ms** |
| C | 2 000 段 × ~20 字 | 56 890 | 2 000 | 147 ms | **29 522 ms** |

读法：
- B 组（单段）字符数 5k→50k（10×）耗时 199→219 ms：**字符数不是主变量**，解析与文本整形都是线性的。
- A/C 组：总字符数不变、只把内容拆成更多块时，耗时仍暴涨 —— **块数 100→2000（20×）耗时 ×132（指数 ≈1.9）**。
- 所以「长文档慢」这件事的正确归因是「**很多块**的文档慢」：一篇 2 000 个短段落的笔记（列表、日志、大纲）比一篇 50 000 字的单段文章慢两个数量级。

## 2. 最小复现

一个只放 `Harness.tsx` 的 nsh app（nsh 0.4.0），用 `nsh test` 跑（dev/headless，无需真窗口）：

```tsx
// Harness.tsx
import { effect, mount, signal, Storage, Text, View, type JSX } from "nsh";
import { createRichEditor, starterKit, starterSchema, RichEditor } from "nsh/base";

function Harness(): JSX.Element {
  const session = signal<ReturnType<typeof createRichEditor> | null>(null);
  effect(() => {
    void (async () => {
      const doc = (await Storage.getItem("test.doc")) ?? "hi\n";
      const t0 = Date.now();
      const s = createRichEditor({
        schema: starterSchema(),
        content: doc,
        format: "markdown",
        plugins: [starterKit()],
      });
      console.log(`createRichEditor=${Date.now() - t0}ms`);
      session.set(s);
    })();
  });
  return (
    <View style={{ flex: 1 }}>
      {session() === null ? (
        <Text>loading</Text>
      ) : (
        <RichEditor editor={session()} accessibilityLabel="富文本编辑器" style={{ flex: 1 }} />
      )}
    </View>
  );
}

mount(Harness);
```

```tsx
// rich.test.tsx —— 只换文档形状，其余不变
import { open } from "nsh/test";

const paragraphs = (n: number, chars: number) =>
  Array.from({ length: n }, (_, i) => `第${i + 1}段 ${"lorem ipsum ".repeat(Math.ceil(chars / 12)).slice(0, chars)}\n\n`).join("");

for (const [n, chars] of [[100, 40], [500, 40], [1000, 40], [2000, 40], [1, 50000]] as const) {
  test(`mount ${n} blocks × ${chars} chars`, async () => {
    const doc = paragraphs(n, chars);
    const t0 = Date.now();
    const app = await open("./Harness.tsx", { width: 1200, height: 900, storage: { "test.doc": doc } });
    await app.waitFor("label:富文本编辑器");
    console.log(`blocks=${n} chars=${doc.length} mount=${Date.now() - t0}ms`);
  });
}
```

单段与多段在**同字符数**下的对照，是这条 issue 最有说服力的一行：

```
blocks=1     chars=50001  mount≈219ms
blocks=2000  chars=96890  mount≈33461ms
```

## 3. 热点（`sample` 采样 + 计数器插桩）

n = 2 000 段时那一次 commit：`perf commit: 12 ops, 25.7–33.4 s, 18036 mount items, 8008 nodes` ——
**一次 commit 内完成**（不是多次 commit 累积；`nsh test --trace` 只有一个巨型 batch）。

| 热点 | 占比 | 说明 |
|---|---|---|
| `nsh_core::core::views::reconcile_region`（`match_children` + `forget_released`） | **~53 %** | `forget_released` 被调 **16 384** 次，累计扫描 **162 097 528** 次 handler/绑定表项 |
| `nsh_core::core::components::component_event` → `dispatch_event` → `handle` → `next_handler` | **~33 %** | `next_handler` 8 192 次调用，累计 **24 629 248** 次扫描 |
| `nsh_core::core::layout_tree::compute_child_layout`（taffy） | ~5 % | 线性，非主因 |

排除项：`node_focused` / `node_selected` / `node_decoration_classes` / `syntect` / `two_face` / 几何测量**均未进热点**。

### 机理

`<RichEditor>` 把每个块渲染成同一个组件实例下的一个「区域」。于是 N 块 = **N 个区域** = 同一个 `Instance`：

1. `reconcile_region`（每区域一次）末尾调 `forget_released(host, inst)`；
2. `forget_released` 对 `inst.handlers` / `event_handlers` / `responders` / `bound` 各做一次 `retain`，`retain` 的判定函数 `live()` 对**每个表项**查 4 次 map —— 也就是遍历**整个组件的全部表项**；
3. 首挂载时其实一个节点都不会释放，但每区域仍把整表扫一遍 → 区域数 × 表项数 = **O(N²)**。

同理，事件派发 `next_handler` 用 `iter().find()` 线性找 `(node, kind)`，N 个块各派一次事件 → 再一个 **O(N²)**。

## 4. 已验证的修法（局部 patch，约 40 行）

只改 `nsh-core` 的组件视图模块（`reconcile_region` 与 `forget_released` 所在文件）：

1. `reconcile_region` 先记下该区域**旧**的节点 id（`before`），reconcile 后再算 `after`；
2. 新增 `forget_released_ids(host, before, after, inst)`：`gone = before − after`，**`gone` 为空直接返回**（首挂载与无释放的 reconcile 从此零扫描）；非空时用一次 `HashSet::contains` 取代原来每项 4 次 map 查；
3. 调用点由 `forget_released(...)` 换成 `forget_released_ids(...)`。

实测（同机同探针，n = 2 000 段）：

| 版本 | 挂载耗时 |
|---|---|
| nsh 0.4.0 原样（clean 基线） | **39 071 ms**（同规模另测 25.1 / 29.5 / 33.5 s，抖动来自并发负载） |
| 上述 patch | **15 667 ms** |

≈ **2.5×**（保守 −38 %～−60 %）。**但这只削掉一半，没根治**：`next_handler` 那条 O(N²) 未动。

### 根治方案（建议 upstream 采纳这个）

把 `Instance` 的 handler 表从 `Vec<(NodeId, EventKind, Listener)>` 改成**按 node id 索引**的结构（`HashMap<NodeId, Vec<(EventKind, Listener)>>`，或按 id 排序 + 二分 + 同 id 保持插入序），于是：

- `next_handler`：`get(id)` 后在同 node 的小数组里找 kind → O(1) 或 O(k)；
- `forget_released`：只对 `gone` 里的 id 做定点清理 → O(gone)；
- 两处 O(N²) 一起消失。

代价：`Instance` 是核心结构，改造要跨组件/区域/插槽三处（约 150–250 行），并且**必须保持 handler 的派发顺序语义**（`next_handler` 带 `from` 游标，同 node 同 kind 可能多个监听器，顺序不能变）。

## 5. 影响面

不只是 `RichEditor`：任何「一个组件下有很多区域/很多子节点」的界面都会吃到这条 O(N²)——例如长表格（`DataTable`）、长列表里每个 `Each` 行都是一个区域、`TextView` 的大文档。所以修它对整个 SDK 都有普遍价值，不只是 CardMind 这一例。

## 6. 给 upstream 的 issue 草稿（英文，可直接提交）

**Title:** `core: Mounting a RichEditor costs O(blocks²) — region reconcile scans every instance's handler tables`

**Body:**

> **Summary.** Mounting a `RichEditor` with many top-level blocks takes quadratic time in the number of blocks. 2 000 short paragraphs take ~33 s in a dev/headless build while a single 50 000-character paragraph takes ~220 ms — so it is block count, not character count. Two places in `nsh-core` scan an instance's whole handler tables once per block; the cost is O(blocks²).
>
> **Environment.** nsh 0.4.0 (`e626a8d`), macOS 27.2 Apple Silicon, dev/headless (`nsh test`), a plain app whose only view is `<RichEditor editor={createRichEditor({ schema: starterSchema(), content, format: "markdown", plugins: [starterKit()] })} style={{ flex: 1 }} />`.
>
> **Repro.** Two documents, same `Harness.tsx`; only `content` differs:
>
> ```ts
> const many = (n: number, chars: number) =>
>   Array.from({ length: n }, (_, i) => `第${i + 1}段 ${"x".repeat(chars)}\n\n`).join("");
> // A: many(2000, 20) -> 56 890 chars, 2 000 blocks -> mount ≈ 29.5–33.5 s
> // B: many(1, 50000)  -> 50 001 chars, 1 block      -> mount ≈ 219 ms
> ```
>
> `createRichEditor` itself is ~150–240 ms in both cases, and `getMarkdown()` is 9–26 ms — the cost is in the first commit of the view, not in parsing or serializing.
>
> **Measurements** (single mount, wall clock from `open()` to `waitFor` the editor):

| blocks | chars | mount |
|---|---|---|
| 100 | 4 690 | 253 ms |
| 500 | 23 890 | 2 366 ms |
| 1 000 | 47 890 | 9 741 ms |
| 2 000 | 96 890 | 33 461 ms |
| 1 | 50 001 | 219 ms |

> **Profiling.** `sample` on the test process, plus counters inserted in the two functions below (n = 2 000 blocks, one commit, 18 036 mount items):
>
> - **~53 %** in `core::views::reconcile_region` → `forget_released`: `forget_released` is called **16 384** times and scans **162 097 528** handler/bound table entries in total (each call does four `retain`s over the whole `Instance` tables; the `live()` predicate does four map lookups per entry).
> - **~33 %** in `core::components::next_handler`: **8 192** calls scanning **24 629 248** entries (`inst.handlers.iter().enumerate().skip(from).find(...)`).
> - ~5 % in taffy layout; `syntect`, text shaping and decoration lookups are not hot.
>
> Since every top-level block of a `RichEditor` is a region of the same component instance, N blocks mean N region reconciles over one set of tables — O(N²). On first mount nothing is released at all, yet every region still walks the whole tables.
>
> **Local fix that halved it (verified).** In `reconcile_region`, record the region's child node ids before and after the reconcile, then only forget the ids that went (`before − after`); return early when nothing went:
>
> - before: 39 071 ms for 2 000 blocks
> - after: 15 667 ms (≈2.5×)
>
> **Suggested real fix.** Index an instance's handlers by node id (`HashMap<NodeId, Vec<(EventKind, Listener)>>`, or sorted by id with a stable order per id) so that `next_handler` is O(1)/O(k) and `forget_released` only touches the ids that went. That removes both quadratics. It is a core structure with dispatch-order semantics to preserve (the `from` cursor in `next_handler`, several listeners per node and kind), so I did not attempt it locally.
>
> This also affects other views built of many child nodes in one component (long `DataTable`s, `Each` rows, large documents in `TextView`), not only `RichEditor`.

## 7. 复现与证据归档

- 剖析脚本、`sample` 原始输出、`--trace` 日志、计数器插桩 diff、可验证 patch diff、upstream repro 两文件：`.git/pipeline/spikes/`（会话内归档，不进 Git）。
- 组件侧表现与处置决定见 `docs/progress-nsh-editor-2026-11-03.md` §27。
