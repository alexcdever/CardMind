// 施工方案 2.1 + 2.6 验收测试（task.md 标准 3/4/5）：读文件断言，不跑构建。
//
// 断言面：
//  ① components.tsx 存在且导出 6 个核心组件（CardMindPrimaryButton /
//     CardMindIconButton / CardMindSearchField / CardMindTag /
//     CardMindSyncStatus / CardMindEmptyState）+ 列表项 + 确认对话框；
//  ② components.tsx / navigation.tsx 全部颜色引用来自 theme.ts 令牌
//     ——不出现裸 `#RRGGBB` 或 `0xAARRGGBB` 字面量；
//  ③ 触摸目标走 `layout.mobileTouchTarget`（=48），不出现裸 48 或更小的
//     高度常量充当命中区；
//  ④ App.tsx 用了新组件 + 有路由定义（createNavigator）+ push/pop 代码路径。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (name: string) => readFileSync(path.join(here, name), 'utf8');

const COMPONENTS = 'components.tsx';
const NAVIGATION = 'navigation.tsx';
const APP = 'App.tsx';

describe('2.1 components.tsx — 6 个核心组件导出', () => {
  it('components.tsx 存在', () => {
    assert.ok(
      existsSync(path.join(here, COMPONENTS)),
      'nsh-app/components.tsx 不存在',
    );
  });

  const src = existsSync(path.join(here, COMPONENTS)) ? read(COMPONENTS) : '';

  for (const name of [
    'CardMindPrimaryButton',
    'CardMindIconButton',
    'CardMindSearchField',
    'CardMindTag',
    'CardMindSyncStatus',
    'CardMindEmptyState',
  ]) {
    it(`导出 ${name}`, () => {
      assert.match(
        src,
        new RegExp(`export\\s+function\\s+${name}\\b`),
        `components.tsx 应 \`export function ${name}\``,
      );
    });
  }

  it('另导出列表项与确认对话框组件（施工 2.1 的「列表项/对话框」）', () => {
    assert.match(
      src,
      /export\s+function\s+CardMindListItem\b/,
      'components.tsx 应导出 CardMindListItem（列表项）',
    );
    assert.match(
      src,
      /export\s+function\s+CardMindConfirmDialog\b/,
      'components.tsx 应导出 CardMindConfirmDialog（危险确认对话框）',
    );
  });
});

describe('2.1 令牌纪律 — 无裸色值/魔法像素', () => {
  for (const file of [COMPONENTS, NAVIGATION]) {
    const p = path.join(here, file);
    const src = existsSync(p) ? read(file) : '';

    it(`${file} 从 theme.ts 导入令牌`, () => {
      assert.ok(existsSync(p), `${file} 不存在`);
      assert.match(
        src,
        /import\s*\{[^}]*\bcolors\b[^}]*\}\s*from\s*['"]\.\/theme(\.ts)?['"]/,
        `${file} 应 \`import { colors, ... } from "./theme"\``,
      );
    });

    it(`${file} 不含裸 #RRGGBB / 0x 色值字面量`, () => {
      // 颜色只能经 theme 令牌进来；出现 hex 字面量即违规。
      assert.ok(
        !/#[0-9A-Fa-f]{3,8}\b/.test(src),
        `${file} 出现裸 hex 色值（应改用 theme.ts 的 colors.*）`,
      );
      assert.ok(
        !/0x[0-9A-Fa-f]{6,8}\b/.test(src),
        `${file} 出现 0x 色值字面量`,
      );
    });

    it(`${file} 不引入 React hooks（nsh 用 signal）`, () => {
      for (const hook of ['useState', 'useEffect', 'useMemo', 'useCallback', 'useRef']) {
        assert.ok(!src.includes(hook), `${file} 不应使用 React 的 ${hook}`);
      }
    });
  }

  it('触摸目标走 layout.mobileTouchTarget（≥48dp 令牌，非裸 48）', () => {
    const src = read(COMPONENTS);
    assert.match(
      src,
      /layout\.mobileTouchTarget/,
      'components.tsx 应用 layout.mobileTouchTarget 表达触摸目标',
    );
    // 只看代码：去掉行注释/块注释后不应再有裸 48。
    const code = src.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');
    assert.ok(
      !/(?<![\w.])48(?![\w.])/.test(code),
      'components.tsx 不应出现裸 48（触摸目标经 layout.mobileTouchTarget）',
    );
  });
});

describe('2.6 导航骨架 + App.tsx 接入', () => {
  const nav = existsSync(path.join(here, NAVIGATION)) ? read(NAVIGATION) : '';
  const app = read(APP);

  it('navigation.tsx 有路由定义 + createNavigator', () => {
    assert.ok(existsSync(path.join(here, NAVIGATION)), 'nsh-app/navigation.tsx 不存在');
    assert.match(nav, /createNavigator/, 'navigation.tsx 应用 createNavigator');
    assert.match(
      nav,
      /type\s+Route\b|export\s+type\s+Route\b/,
      'navigation.tsx 应定义 Route（路由枚举/联合类型）',
    );
    // 五条主路由：列表/回收站/设置/设备/编辑器
    for (const r of ['notes', 'trash', 'settings', 'devices', 'editor']) {
      assert.match(nav, new RegExp(`"${r}"|'${r}'`), `Route 应含 "${r}" 路由`);
    }
  });

  it('navigation.tsx 至少有一条 push/pop 代码路径', () => {
    assert.match(nav, /nav(igator)?\.push\(/, 'navigation.tsx 应有 push 调用');
    assert.match(nav, /nav(igator)?\.pop\(/, 'navigation.tsx 应有 pop 调用');
  });

  it('App.tsx 导入并使用新组件', () => {
    assert.match(
      app,
      /import\s*\{[^}]*CardMind\w+[^}]*\}\s*from\s*['"]\.\/components(\.tsx)?['"]/,
      'App.tsx 应从 ./components 导入 CardMind* 组件',
    );
    // 2.3–2.5 起页面组件被抽到独立模块（note_list/trash/settings/devices），
    // 骨架改为挂载这些页面。判定「骨架用上组件库」改为扫描 App.tsx + 它挂载的
    // 页面模块，仍要求 ≥4 种 CardMind*（阈值不变，不弱化）。
    const tree = [
      'devices_page.tsx',
      'note_list.tsx',
      'trash_page.tsx',
      'settings_page.tsx',
    ]
      .map((n) => readFileSync(path.join(here, n), 'utf8'))
      .join('\n');
    const used = [
      'CardMindPrimaryButton',
      'CardMindIconButton',
      'CardMindSearchField',
      'CardMindTag',
      'CardMindSyncStatus',
      'CardMindEmptyState',
      'CardMindListItem',
      'CardMindConfirmDialog',
    ].filter((n) => new RegExp(`<${n}\\b`).test(app + tree));
    assert.ok(
      used.length >= 4,
      `App.tsx（含挂载页面）应至少用 4 个新组件渲染骨架（当前 ${used.length}: ${used.join(', ')}）`,
    );
  });

  it('App.tsx 挂导航（Stack navigator）', () => {
    assert.match(app, /import\s*\{[^}]*nav\b|nav,[^}]*\}/, 'App.tsx 应引入 navigator');
    assert.match(app, /<Stack\b/, 'App.tsx 应渲染 <Stack> 挂页面栈');
  });
});
