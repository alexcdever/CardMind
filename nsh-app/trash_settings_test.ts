// 施工方案 2.3 + 2.4 验收测试（task.md 标准 4/5/6）：读文件断言，不跑构建。
// P2-4 起断言读「入口 + 子目录全部 .ts/.tsx」并集（trash_page/、settings_page/），
// 断言条数与正则不削弱。
//
// 断言面：
//  ① trash_page.tsx / settings_page.tsx 存在；
//  ② 回收站四操作真接线：storeTrashList / noteRestore / notePurge /
//    purgeExpiredTrash（定期清理，cutoff = now-30d RFC3339）；
//  ③ 设置四项真接线：getDeviceName / setDeviceName / getSyncAllowed /
//    setSyncAllowed；日志目录显示；更新检查 UI 入口 + 版本号；
//  ④ 危险操作走 CardMindConfirmDialog（彻底删除 + 定期清理）；
//  ⑤ 空态用 CardMindEmptyState；
//  ⑥ 令牌纪律：无裸色值、触摸目标走 layout.mobileTouchTarget、无裸 48；
//  ⑦ 设置页紧凑断点 600（Dart 源面板紧凑断点镜像）；
//  ⑧ App.tsx 接入两页（import + 渲染），启动接真后端且无 Phase 1 演示副作用。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (name: string) => readFileSync(path.join(here, name), 'utf8');

const TRASH = 'trash_page.tsx';
const SETTINGS = 'settings_page.tsx';
const APP = 'App.tsx';

/** P2-4 起两页拆为入口 + 子目录（trash_page/、settings_page/，同
 *  note_list/editor_page/devices_page 拆分模式）。结构/令牌断言改读
 *  **并集**（入口 + 子目录全部 .ts/.tsx 拼接）——断言条数与正则一律
 *  不减少、不放宽，只是把「单文件源码面」扩大到「拆分后的源码面」。 */
const unionRead = (entry: string, dirName: string) => {
  const dir = path.join(here, dirName);
  const subs = existsSync(dir)
    ? readdirSync(dir)
        .filter((f) => f.endsWith('.ts') || f.endsWith('.tsx'))
        .sort()
        .map((f) => read(path.join(dirName, f)))
        .join('\n')
    : '';
  return read(entry) + '\n' + subs;
};

const trashPath = path.join(here, TRASH);
const settingsPath = path.join(here, SETTINGS);
const trash = existsSync(trashPath) ? unionRead(TRASH, 'trash_page') : '';
const settings = existsSync(settingsPath) ? unionRead(SETTINGS, 'settings_page') : '';
const app = read(APP);

/** 去掉行注释/块注释后的代码（查裸数字/裸色时用）。 */
const codeOnly = (src: string) =>
  src.replace(/\/\/[^\n]*/g, '').replace(/\/\*[\s\S]*?\*\//g, '');

describe('2.3 trash_page.tsx — 存在与回收站四操作', () => {
  it('trash_page.tsx 存在', () => {
    assert.ok(existsSync(trashPath), 'nsh-app/trash_page.tsx 不存在');
  });

  it('列出回收站（BackendNotes.storeTrashList）', () => {
    assert.match(
      trash,
      /storeTrashList\s*\(/,
      'trash_page.tsx 应调用 BackendNotes.storeTrashList() 列已删笔记',
    );
  });

  it('恢复走 BackendNotes.noteRestore', () => {
    assert.match(
      trash,
      /noteRestore\s*\(/,
      'trash_page.tsx 应调用 BackendNotes.noteRestore(id)（恢复）',
    );
  });

  it('彻底删除走 BackendNotes.notePurge', () => {
    assert.match(
      trash,
      /notePurge\s*\(/,
      'trash_page.tsx 应调用 BackendNotes.notePurge(id)（彻底删除）',
    );
  });

  it('定期清理走 BackendNotes.purgeExpiredTrash（30 天 cutoff）', () => {
    assert.match(
      trash,
      /purgeExpiredTrash\s*\(/,
      'trash_page.tsx 应调用 BackendNotes.purgeExpiredTrash(cutoff)（定期清理）',
    );
    // cutoff 语义：30 天前的 RFC3339。源码里应出现 30（天数）与 toISOString。
    const code = codeOnly(trash);
    assert.match(code, /30/, 'cutoff 应含 30 天语义（30 天前）');
    assert.match(
      code,
      /toISOString\s*\(\s*\)/,
      'cutoff 应为 RFC3339/ISO 字符串（toISOString）',
    );
  });

  it('彻底删除确认走 CardMindConfirmDialog（危险确认，不直删）', () => {
    assert.match(
      trash,
      /<CardMindConfirmDialog\b/,
      '彻底删除应弹 CardMindConfirmDialog 确认，不能直接执行',
    );
    assert.match(
      trash,
      /danger/,
      'CardMindConfirmDialog 应用 danger 危险态',
    );
  });

  it('空态用 CardMindEmptyState', () => {
    assert.match(
      trash,
      /CardMindEmptyState/,
      '回收站空态应使用 CardMindEmptyState 组件',
    );
  });
});

describe('2.3 trash_page.tsx — 令牌纪律', () => {
  it('从 ./theme 导入令牌', () => {
    assert.match(
      trash,
      /import\s*\{[^}]*\b(colors|layout|spacing|radii)\b[^}]*\}\s*from\s*['"]\.\/theme(\.ts)?['"]/,
      'trash_page.tsx 应 import { colors, layout, ... } from "./theme"',
    );
  });

  it('不含裸 #RRGGBB / 0x 色值字面量', () => {
    assert.ok(
      !/#[0-9A-Fa-f]{3,8}\b/.test(trash),
      'trash_page.tsx 出现裸 hex 色值（应改用 theme.ts 的 colors.*）',
    );
    assert.ok(!/0x[0-9A-Fa-f]{6,8}\b/.test(trash), 'trash_page.tsx 出现 0x 色值');
  });

  it('触摸目标走 layout.mobileTouchTarget（≥48dp 令牌，非裸 48）', () => {
    assert.match(
      trash,
      /layout\.mobileTouchTarget/,
      'trash_page.tsx 应用 layout.mobileTouchTarget 表达触摸目标',
    );
    const code = codeOnly(trash);
    assert.ok(
      !/(?<![\w.])48(?![\w.])/.test(code),
      'trash_page.tsx 不应出现裸 48（触摸目标经 layout.mobileTouchTarget）',
    );
  });

  it('不引入 React hooks（nsh 用 signal）', () => {
    for (const hook of ['useState', 'useEffect', 'useMemo', 'useCallback', 'useRef']) {
      assert.ok(!trash.includes(hook), `trash_page.tsx 不应使用 React 的 ${hook}`);
    }
  });
});

describe('2.4 settings_page.tsx — 存在与设置四项', () => {
  it('settings_page.tsx 存在', () => {
    assert.ok(existsSync(settingsPath), 'nsh-app/settings_page.tsx 不存在');
  });

  it('设备名读取（BackendPairing.getDeviceName）', () => {
    assert.match(
      settings,
      /getDeviceName\s*\(/,
      'settings_page.tsx 应调用 BackendPairing.getDeviceName() 显示设备名',
    );
  });

  it('设备名编辑保存（BackendPairing.setDeviceName）', () => {
    assert.match(
      settings,
      /setDeviceName\s*\(/,
      'settings_page.tsx 应调用 BackendPairing.setDeviceName(name) 保存',
    );
  });

  it('同步开关读取（BackendSync.getSyncAllowed）', () => {
    assert.match(
      settings,
      /getSyncAllowed\s*\(/,
      'settings_page.tsx 应调用 BackendSync.getSyncAllowed() 读同步开关',
    );
  });

  it('同步开关写入（BackendSync.setSyncAllowed）', () => {
    assert.match(
      settings,
      /setSyncAllowed\s*\(/,
      'settings_page.tsx 应调用 BackendSync.setSyncAllowed(bool) 写同步开关',
    );
  });

  it('日志目录显示（「日志目录」文案 + 路径槽位）', () => {
    assert.match(
      settings,
      /日志目录/,
      'settings_page.tsx 应显示「日志目录」区块',
    );
    assert.match(
      settings,
      /logDir|日志路径|logs?[/\\]|路径/,
      'settings_page.tsx 应有日志路径显示槽位',
    );
  });

  it('更新检查 UI 入口（检查更新按钮/区块 + 版本号显示）', () => {
    assert.match(
      settings,
      /检查更新|更新/,
      'settings_page.tsx 应有更新检查 UI 入口',
    );
    assert.match(
      settings,
      /版本|version/i,
      'settings_page.tsx 应显示版本号',
    );
  });

  it('紧凑断点 600（Dart 源面板紧凑断点镜像）', () => {
    const code = codeOnly(settings);
    assert.match(
      code,
      /(windowSize\s*\(\s*\)\.width|width)\s*(>=|>|<=|<)\s*(compactBreakpoint|600)/,
      'settings_page.tsx 应有「宽度 vs 600 紧凑断点」比较式',
    );
  });
});

describe('2.4 settings_page.tsx — 令牌纪律', () => {
  it('从 ./theme 导入令牌', () => {
    assert.match(
      settings,
      /import\s*\{[^}]*\b(colors|layout|spacing|radii)\b[^}]*\}\s*from\s*['"]\.\/theme(\.ts)?['"]/,
      'settings_page.tsx 应 import { colors, layout, ... } from "./theme"',
    );
  });

  it('不含裸 #RRGGBB / 0x 色值字面量', () => {
    assert.ok(
      !/#[0-9A-Fa-f]{3,8}\b/.test(settings),
      'settings_page.tsx 出现裸 hex 色值（应改用 theme.ts 的 colors.*）',
    );
    assert.ok(
      !/0x[0-9A-Fa-f]{6,8}\b/.test(settings),
      'settings_page.tsx 出现 0x 色值',
    );
  });

  it('触摸目标走 layout.mobileTouchTarget（≥48dp 令牌，非裸 48）', () => {
    assert.match(
      settings,
      /layout\.mobileTouchTarget/,
      'settings_page.tsx 应用 layout.mobileTouchTarget 表达触摸目标',
    );
    const code = codeOnly(settings);
    assert.ok(
      !/(?<![\w.])48(?![\w.])/.test(code),
      'settings_page.tsx 不应出现裸 48（触摸目标经 layout.mobileTouchTarget）',
    );
  });

  it('不引入 React hooks（nsh 用 signal）', () => {
    for (const hook of ['useState', 'useEffect', 'useMemo', 'useCallback', 'useRef']) {
      assert.ok(
        !settings.includes(hook),
        `settings_page.tsx 不应使用 React 的 ${hook}`,
      );
    }
  });
});

describe('2.3 + 2.4 App.tsx 接入', () => {
  it('App.tsx 导入 trash_page 模块', () => {
    assert.match(
      app,
      /import\s*[\s\S]*?from\s*['"]\.\/trash_page(\.tsx)?['"]/,
      'App.tsx 应 `import { ... } from "./trash_page"`',
    );
  });

  it('App.tsx 渲染 trash_page 导出的组件', () => {
    const imported = app.match(
      /import\s*\{([^}]*)\}\s*from\s*['"]\.\/trash_page(\.tsx)?['"]/,
    );
    assert.ok(imported, 'App.tsx 应 import { X } from "./trash_page"');
    const names = imported![1]
      .split(',')
      .map((s) => s.trim().split(/\s+as\s+/).pop()!)
      .filter(Boolean);
    const used = names.filter((n) => new RegExp(`<${n}\\b`).test(app));
    assert.ok(
      used.length > 0,
      `App.tsx 应渲染 ./trash_page 导出的组件（导入 ${names.join(',')}；用到 ${used.join(',') || '无'}）`,
    );
  });

  it('App.tsx 导入 settings_page 模块', () => {
    assert.match(
      app,
      /import\s*[\s\S]*?from\s*['"]\.\/settings_page(\.tsx)?['"]/,
      'App.tsx 应 `import { ... } from "./settings_page"`',
    );
  });

  it('App.tsx 渲染 settings_page 导出的组件', () => {
    const imported = app.match(
      /import\s*\{([^}]*)\}\s*from\s*['"]\.\/settings_page(\.tsx)?['"]/,
    );
    assert.ok(imported, 'App.tsx 应 import { X } from "./settings_page"');
    const names = imported![1]
      .split(',')
      .map((s) => s.trim().split(/\s+as\s+/).pop()!)
      .filter(Boolean);
    const used = names.filter((n) => new RegExp(`<${n}\\b`).test(app));
    assert.ok(
      used.length > 0,
      `App.tsx 应渲染 ./settings_page 导出的组件（导入 ${names.join(',')}；用到 ${used.join(',') || '无'}）`,
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
