// 施工方案 2.2 + 2.7 验收测试（task.md 标准 3/4/5）：读文件断言，不跑构建。
//
// 断言面：
//  ① note_list.tsx 存在，且是列表页主体（列表 + 搜索 + 标签 + 空态）；
//  ② 双布局：源码里有 desktopBreakpoint 断点分支（≥960 桌面 / <960 移动）；
//  ③ 虚拟化：用 "nsh" 导出的 <List>（即 virtual_list；0.3.0 起不再有
//     nsh/list 子模块）+ 稳定 key（keyExtractor 或 note.id）而不是 <Each> 全量渲染；
//  ④ 搜索走后端（BackendNotes.searchNotes 或 BackendStore.storeSearch）、
//     标签过滤走 getAllTags/searchByTag、软删除走 noteSoftDelete；
//  ⑤ 滑动删除不是唯一删除入口：有可见删除按钮/菜单项（手势之外的无障碍
//     替代），且软删除动作在源码中出现；
//  ⑥ 令牌纪律：无裸色值、触摸目标走 layout.mobileTouchTarget；
//  ⑦ App.tsx 接入新列表页（import note_list 且渲染其导出的组件），
//     启动接真后端（dataDir → createNoteStore → syncDeviceId → startReceiver），
//     且无 Phase 1 演示副作用。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (name: string) => readFileSync(path.join(here, name), 'utf8');

const PAGE = 'note_list.tsx';
const APP = 'App.tsx';

const pagePath = path.join(here, PAGE);
const page = existsSync(pagePath) ? read(PAGE) : '';
const app = read(APP);

/** 去掉行注释/块注释后的代码（查裸数字/裸色时用）。 */
const codeOnly = (src: string) =>
  src.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');

describe('2.2 note_list.tsx — 存在与布局分支', () => {
  it('note_list.tsx 存在', () => {
    assert.ok(existsSync(pagePath), 'nsh-app/note_list.tsx 不存在');
  });

  it('从 ./theme 导入令牌（colors/layout/spacing/radii 至少其一）', () => {
    assert.match(
      page,
      /import\s*\{[^}]*\b(colors|layout|spacing|radii)\b[^}]*\}\s*from\s*['"]\.\/theme(\.ts)?['"]/,
      'note_list.tsx 应 import { colors, layout, ... } from "./theme"',
    );
  });

  it('含 desktopBreakpoint 断点分支（双布局判断）', () => {
    assert.match(
      page,
      /desktopBreakpoint/,
      'note_list.tsx 应引用 layout.desktopBreakpoint 做 ≥960 断点判断',
    );
    // 断点必须是判断式而非摆设：出现 `>= layout.desktopBreakpoint`
    // 或 `windowSize().width` 之类的宽度比较。
    const code = codeOnly(page);
    assert.match(
      code,
      /(windowSize\s*\(\s*\)\.width|width)\s*(>=|>|<=|<)\s*(layout\.)?desktopBreakpoint/,
      '应有「宽度 vs desktopBreakpoint」的比较式（双布局分支）',
    );
  });
});

describe('2.7 列表虚拟化 — List 而非全量渲染', () => {
  it('从 "nsh" 导入 List（virtual_list；0.3.0 并入 nsh）', () => {
    assert.match(
      page,
      /import\s*\{[^}]*\bList\b[^}]*\}\s*from\s*['"]nsh['"]/,
      'note_list.tsx 应 `import { List } from "nsh"`（virtual_list）',
    );
  });

  it('渲染 <List> 且 each 绑定笔记数组', () => {
    assert.match(page, /<List\b/, '应渲染 <List>');
    assert.match(
      page,
      /each=\{[^}]*\}/,
      '<List> 应有 each={…} 绑定笔记数组（virtual_list 数据源）',
    );
  });

  it('行 key 走稳定 id（keyExtractor 或 item.id）', () => {
    const code = codeOnly(page);
    assert.match(
      code,
      /keyExtractor|\.id\b/,
      'virtual_list 应有稳定 key（keyExtractor 或取 item.id），不能用索引',
    );
  });

  it('不用 <Each> 全量渲染笔记列表', () => {
    const code = codeOnly(page);
    // <Each> 出现在笔记列表就是全量渲染反模式；标签行那种少量项不算。
    const eachCount = (code.match(/<Each\b/g) ?? []).length;
    assert.ok(
      eachCount === 0,
      `笔记列表应用 <List> 而非 <Each>（当前 <Each> 出现 ${eachCount} 次）`,
    );
  });
});

describe('2.2 功能接线 — 搜索/标签/删除/空态', () => {
  it('搜索框 + 后端搜索调用', () => {
    assert.match(
      page,
      /CardMindSearchField/,
      '应使用 CardMindSearchField 组件',
    );
    assert.match(
      page,
      /(searchNotes|storeSearch)\s*\(/,
      '应调用后端搜索（BackendNotes.searchNotes 或 BackendStore.storeSearch）',
    );
  });

  it('标签过滤（getAllTags 或 searchByTag 或 CardMindTag）', () => {
    const code = codeOnly(page);
    assert.match(
      code,
      /(getAllTags|searchByTag|CardMindTag)/,
      '应有标签过滤相关调用（getAllTags / searchByTag）或 CardMindTag 标签行',
    );
  });

  it('软删除走 BackendNotes.noteSoftDelete', () => {
    assert.match(
      page,
      /noteSoftDelete\s*\(/,
      '应调用 BackendNotes.noteSoftDelete(id)（软删除进回收站）',
    );
  });

  it('滑动删除有按钮/键盘替代（非仅手势）', () => {
    const code = codeOnly(page);
    // 手势（PanResponder / onMoveShouldSetResponder / swipe）之外，
    // 必须还有一个可见的删除触发：删除按钮、菜单项或“删除”文字按钮。
    const hasGesture =
      /PanResponder|onMoveShouldSetResponder|onPanResponder|swipe/i.test(code);
    const hasButtonAlt =
      /(icon="delete"|删除|noteSoftDelete)/.test(code) &&
      /(accessibilityLabel|onPress|CardMindIconButton)/.test(code);
    assert.ok(
      hasGesture && hasButtonAlt,
      `滑动删除需手势 + 可见替代并存（gesture=${hasGesture}, button=${hasButtonAlt}）`,
    );
  });

  it('空态用 CardMindEmptyState', () => {
    assert.match(page, /CardMindEmptyState/, '应使用 CardMindEmptyState 组件');
  });
});

describe('2.2 令牌纪律', () => {
  it('note_list.tsx 不含裸 #RRGGBB / 0x 色值字面量', () => {
    assert.ok(
      !/#[0-9A-Fa-f]{3,8}\b/.test(page),
      'note_list.tsx 出现裸 hex 色值（应改用 theme.ts 的 colors.*）',
    );
    assert.ok(!/0x[0-9A-Fa-f]{6,8}\b/.test(page), 'note_list.tsx 出现 0x 色值');
  });

  it('触摸目标走 layout.mobileTouchTarget（≥48dp 令牌）', () => {
    assert.match(
      page,
      /layout\.mobileTouchTarget/,
      'note_list.tsx 应用 layout.mobileTouchTarget 表达触摸目标',
    );
    const code = codeOnly(page);
    assert.ok(
      !/(?<![\w.])48(?![\w.])/.test(code),
      'note_list.tsx 不应出现裸 48（触摸目标经 layout.mobileTouchTarget）',
    );
  });

  it('不引入 React hooks（nsh 用 signal）', () => {
    for (const hook of ['useState', 'useEffect', 'useMemo', 'useCallback', 'useRef']) {
      assert.ok(!page.includes(hook), `note_list.tsx 不应使用 React 的 ${hook}`);
    }
  });
});

describe('2.2 App.tsx 接入', () => {
  it('App.tsx 导入 note_list 模块', () => {
    assert.match(
      app,
      /import\s*[\s\S]*?from\s*['"]\.\/note_list(\.tsx)?['"]/,
      'App.tsx 应 `import { ... } from "./note_list"`',
    );
  });

  it('App.tsx 渲染 note_list 导出的组件（替换占位 NoteList）', () => {
    // 新列表页的导出名以 NoteList* 命名；只要 App.tsx 里出现该 JSX 标签
    // 且来源是 ./note_list 的导入即可。
    const imported = app.match(
      /import\s*\{([^}]*)\}\s*from\s*['"]\.\/note_list(\.tsx)?['"]/,
    );
    assert.ok(imported, 'App.tsx 应 import { X } from "./note_list"');
    const names = imported![1]
      .split(',')
      .map((s) => s.trim().split(/\s+as\s+/).pop()!)
      .filter(Boolean);
    const used = names.filter((n) => new RegExp(`<${n}\\b`).test(app));
    assert.ok(
      used.length > 0,
      `App.tsx 应渲染 ./note_list 导出的组件（导入 ${names.join(',')}；用到 ${used.join(',') || '无'}）`,
    );
  });

  it('App.tsx 启动接真后端（dataDir → createNoteStore → syncDeviceId → startReceiver）', () => {
    for (const call of [
      'BackendStore.dataDir',
      'BackendStore.createNoteStore',
      'BackendStore.syncDeviceId',
      'BackendSync.startReceiver',
    ]) {
      assert.ok(app.includes(call), `App.tsx 启动缺失真后端调用 ${call}`);
    }
  });

  it('App.tsx 无 Phase 1 演示副作用（不再切同步开关/停接收器/关 endpoint）', () => {
    for (const call of [
      'setSyncAllowed(',
      'stopReceiver(',
      'BackendSync.close(',
    ]) {
      assert.ok(!app.includes(call), `App.tsx 仍有演示副作用调用 ${call}`);
    }
  });
});
