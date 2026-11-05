// 骨架验收测试（task.md 标准 3–6）：读文件断言，不跑构建。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (name: string) => readFileSync(path.join(here, name), 'utf8');
const manifest = read('Cargo.toml');
const lockfile = read('Cargo.lock');

/** nsh-app 的 TSX 源码（本目录下的 *.tsx；测试文件都是 *_test.ts，不会混进来）。 */
const topLevelTsx = readdirSync(here)
  .filter((f) => f.endsWith('.tsx'))
  .map((f) => ({ name: f, code: read(f) }));

/** P2-5 起组件库拆为入口 + components/ 子目录；把子目录 .tsx 并入扫描面，
 *  不削弱「NSH 导入面」断言的覆盖（断言条数/正则不减少）。 */
const COMPONENTS_DIR = path.join(here, 'components');
const componentsTsx = existsSync(COMPONENTS_DIR)
  ? readdirSync(COMPONENTS_DIR)
      .filter((f) => f.endsWith('.tsx'))
      .sort()
      .map((f) => ({ name: path.join('components', f), code: read(path.join('components', f)) }))
  : [];

const tsxSources = [...topLevelTsx, ...componentsTsx];

/** 0.3.0 起不再存在的旧 NSH 子模块路径（一切并入 `nsh` / `nsh/base`）。 */
const LEGACY_NSH_MODULES = ['webview', 'list', 'gesture', 'device', 'keymap', 'animated'];

describe('nsh.json', () => {
  it('是合法 JSON 且 id / rust 字段正确', () => {
    const config = JSON.parse(read('nsh.json'));
    assert.equal(config.id, 'com.cardmind.nsh');
    assert.equal(config.rust, '.');
  });

  it('不再声明 webview capability（WebView 链路已删），声明 clipboard', () => {
    const config = JSON.parse(read('nsh.json'));
    assert.equal(config.capabilities?.webview, undefined, 'nsh.json 仍有 capabilities.webview');
    assert.equal(config.capabilities?.clipboard, true, 'nsh.json 缺少 capabilities.clipboard');
  });
});

describe('Cargo.toml', () => {
  it('声明 nsh-core 与 nsh-base 0.3.0', () => {
    assert.match(manifest, /nsh-core\s*=\s*"0\.3\.0"/);
    assert.match(manifest, /nsh-base\s*=\s*"0\.3\.0"/);
  });

  // P2-3 起：P1 删除 src/main.rs 后，`env_logger` 与 4 个 `nsh-platform-*`
  // 失去唯一消费者（env_logger::init / platform::run_app 只被 main 用）。
  // app crate 由 nsh 0.3.0 CLI 驱动构建，不再需要在 manifest 声明平台 crate。
  it('不声明 env_logger 与 nsh-platform-*（已随 main.rs 删除成为死依赖）', () => {
    assert.doesNotMatch(
      manifest,
      /(^|[^A-Za-z0-9_-])env_logger\s*=/,
      'Cargo.toml 不应再声明 env_logger（唯一消费者 main.rs 已删）',
    );
    for (const crate of [
      'nsh-platform-linux',
      'nsh-platform-macos',
      'nsh-platform-windows',
      'nsh-platform-android',
    ]) {
      assert.doesNotMatch(
        manifest,
        new RegExp(`${crate}\\s*=`),
        `Cargo.toml 不应再声明 ${crate}`,
      );
    }
  });

  it('含空的 [workspace] 段', () => {
    assert.match(manifest, /^\[workspace\]\s*$/m);
  });

  // 施工方案 1.7 + 1.4 起，nsh-app 就是要接真后端：路径依赖 rust-backend
  // （独立 workspace，靠 path 依赖引入，不并入 rust-backend 的 members）。
  // 之前那条「不引入后端依赖」的 Phase 0 断言已随 1.7 落地而反转——
  // 但「loro / iroh 不得由 nsh-app 直接声明」这条覆盖要保留：
  // 它们只能经 cardmind-backend 间接使用，直接声明等于绕过后端 crate
  // 自己操纵 CRDT / 网络层。（path 依赖行 `cardmind-backend = { path = "../rust-backend" }`
  // 本身不含 loro/iroh，按「依赖名 =」匹配不会误命中。）
  it('以 path 依赖引入 cardmind-backend（不直接依赖 loro/iroh）', () => {
    assert.match(
      manifest,
      /cardmind-backend\s*=\s*\{\s*path\s*=\s*"\.\.\/rust-backend"\s*\}/,
      '应引入 cardmind-backend（path = "../rust-backend"）',
    );
    for (const dep of ['loro', 'iroh']) {
      assert.ok(
        !new RegExp(`(^|[^A-Za-z0-9_-])${dep}\\s*=`).test(manifest),
        `nsh-app/Cargo.toml 不应直接依赖 ${dep}（应经 cardmind-backend 间接用）`,
      );
    }
  });
});

describe('Cargo.lock（已跟踪，须随 Cargo.toml 一起升）', () => {
  const nshPackages = lockfile
    .split('[[package]]')
    .slice(1)
    .map((block) => ({
      name: block.match(/^name\s*=\s*"([^"]+)"/m)?.[1] ?? '',
      version: block.match(/^version\s*=\s*"([^"]+)"/m)?.[1] ?? '',
    }))
    // `nsh-app-cardmind` 是本 crate 自己，不是 NSH 依赖。
    .filter((p) => /^nsh-(?!app-)/.test(p.name));

  it('列出全部 NSH 依赖包（platform crate 已随死依赖清理移除）', () => {
    // nsh-engine 是 nsh-platform-* 的传递依赖，随平台 crate 一并从 lock 移除；
    // app crate 直接依赖只剩 nsh-core + nsh-base（+ proc-macro 的 nsh-macros）。
    const names = nshPackages.map((p) => p.name);
    for (const required of ['nsh-base', 'nsh-core', 'nsh-macros']) {
      assert.ok(names.includes(required), `Cargo.lock 缺少 ${required}`);
    }
    assert.equal(
      names.filter((n) => /^nsh-platform-/.test(n)).length,
      0,
      `Cargo.lock 仍含 nsh-platform-*：${names.filter((n) => /^nsh-platform-/.test(n)).join(', ')}`,
    );
    assert.doesNotMatch(
      lockfile,
      /^name\s*=\s*"env_logger"/m,
      'Cargo.lock 仍含 env_logger',
    );
  });

  it('所有 nsh-* 包解析为 0.3.0', () => {
    for (const p of nshPackages) {
      assert.equal(p.version, '0.3.0', `${p.name} 在 Cargo.lock 里是 ${p.version}，应为 0.3.0`);
    }
  });
});

describe('src/lib.rs（0.3.0 API）', () => {
  const lib = read(path.join('src', 'lib.rs'));

  it('使用 nsh_core::prelude::*（0.3.0 无 ui 模块）', () => {
    assert.match(lib, /use nsh_core::prelude::\*;/, 'lib.rs 应 `use nsh_core::prelude::*;`');
    assert.doesNotMatch(lib, /nsh_core::ui/, 'lib.rs 仍有 0.2.0 的 `nsh_core::ui` 导入');
  });

  it('lib.rs 只保留模块边界（Phase-1 组件已随 P1 删除）', () => {
    assert.doesNotMatch(lib, /#\[component\]/, 'lib.rs 仍有 #[component]（Phase-1 演示组件）');
    assert.doesNotMatch(lib, /nsh_base::theme/, 'lib.rs 仍导入 nsh_base::theme（仅演示组件用）');
  });

  it('不再有 Rust-native 演示入口 src/main.rs（TSX 入口运行 App.tsx）', () => {
    assert.ok(
      !existsSync(path.join(here, 'src', 'main.rs')),
      'src/main.rs 应已删除：TSX app 由 App.tsx 入口运行，不再挂 Rust Root 组件',
    );
  });
});

describe('TSX 源码的 NSH 导入面（0.3.0：只剩 nsh 与 nsh/base）', () => {
  it('不再 import 旧子模块（nsh/webview|list|gesture|device|keymap|animated）', () => {
    for (const { name, code } of tsxSources) {
      for (const mod of LEGACY_NSH_MODULES) {
        assert.doesNotMatch(
          code,
          new RegExp(`from\\s*['"]nsh/${mod}['"]`),
          `${name} 仍从 "nsh/${mod}" 导入 —— 0.3.0 已并入 "nsh"`,
        );
      }
    }
  });

  it('Input 从 nsh/base 导入（0.3.0 的 nsh 不再导出 Input）', () => {
    // P2-2c 起 devices_page 拆为入口 + devices_page/ 子模块（Input 在
    // pair_sheets.tsx / sections.tsx），断言改读并集，条数/正则不削弱。
    const devicesDir = path.join(here, 'devices_page');
    const devicesUnion =
      read('devices_page.tsx') +
      '\n' +
      (existsSync(devicesDir)
        ? readdirSync(devicesDir)
            .filter((f) => f.endsWith('.ts') || f.endsWith('.tsx'))
            .sort()
            .map((f) => read(path.join('devices_page', f)))
            .join('\n')
        : '');
    // P2-5 起 components.tsx 同样拆为入口 + components/ 子模块（Input 在
    // components/search_field.tsx），断言改读并集，条数/正则不削弱。
    const componentsDir = path.join(here, 'components');
    const componentsUnion =
      read('components.tsx') +
      '\n' +
      (existsSync(componentsDir)
        ? readdirSync(componentsDir)
            .filter((f) => f.endsWith('.ts') || f.endsWith('.tsx'))
            .sort()
            .map((f) => read(path.join('components', f)))
            .join('\n')
        : '');
    for (const name of ['components.tsx', 'devices_page.tsx', 'settings_page.tsx']) {
      const code =
        name === 'devices_page.tsx'
          ? devicesUnion
          : name === 'components.tsx'
            ? componentsUnion
            : read(name);
      assert.doesNotMatch(
        code,
        /import\s*\{[^}]*\bInput\b[^}]*\}\s*from\s*['"]nsh['"]/,
        `${name} 仍从 "nsh" 导入 Input`,
      );
      assert.match(
        code,
        /import\s*\{[^}]*\bInput\b[^}]*\}\s*from\s*['"]nsh\/base['"]/,
        `${name} 的 Input 应来自 "nsh/base"`,
      );
    }
  });

  it('编辑器页用 nsh/base 的原生 Editor（不再是 WebView + Tiptap）', () => {
    const app = read('App.tsx');
    assert.doesNotMatch(app, /\bWebView\b/, 'App.tsx 仍引用 WebView');
    assert.doesNotMatch(app, /EDITOR_HTML|EDITOR_BASE_URL/, 'App.tsx 仍有 WebView 内联页常量');
    assert.doesNotMatch(app, /editor-ready|postMessage/, 'App.tsx 仍有 WebView 桥协议');
    assert.match(
      app,
      /import\s*\{[^}]*\bEditorScreen\b[^}]*\}\s*from\s*['"]\.\/editor_page['"]/,
      'App.tsx 的 EditorScreen 应来自 ./editor_page',
    );
    const editor = read('editor_page.tsx');
    assert.match(
      editor,
      /import\s*\{[\s\S]*?\bEditor\b[\s\S]*?\}\s*from\s*['"]nsh\/base['"]/,
      'editor_page.tsx 应从 "nsh/base" 导入 Editor',
    );
    assert.match(editor, /autoClose=\{false\}/, 'Editor 必须 autoClose={false} 才能输入 [[ 字面量');
    assert.match(editor, /language="markdown"/, 'Editor 应为 markdown 语言');
    assert.match(editor, /accessibilityLabel=/, 'Editor 应有 accessibilityLabel');
  });

  it('nsh-app/web/ 不存在（WebView 静态站点已删）', () => {
    assert.equal(existsSync(path.join(here, 'web')), false, 'web/ 仍存在');
  });
});

describe('navigation.tsx — 顶栏颜色走 headerStyle', () => {
  const nav = read('navigation.tsx');

  // 0.2.0 与 0.3.0 的 NavPage 都只有 headerStyle；旧写法经 spread 传入被静默忽略。
  it('不再使用从未存在的 header*Color props', () => {
    assert.doesNotMatch(
      nav,
      /header(Background|Tint|Title)Color/,
      'navigation.tsx 仍在用不存在的 header*Color props（应改 headerStyle）',
    );
  });

  it('headerStyle 用令牌色（backgroundColor / color / tintColor）', () => {
    assert.match(
      nav,
      /headerStyle\s*=\s*\{[\s\S]*?backgroundColor\s*:/,
      'headerStyle 应有 backgroundColor（来自 colors 令牌）',
    );
    assert.match(
      nav,
      /headerStyle\s*=\s*\{[\s\S]*?tintColor\s*:/,
      'headerStyle 应有 tintColor（来自 colors 令牌）',
    );
  });

  it('screenChrome 把 headerStyle 传给 NavPage', () => {
    assert.match(nav, /return\s*\{\s*title,\s*headerStyle\s*\}/, 'screenChrome 应返回 title + headerStyle');
  });
});

describe('.gitignore', () => {
  const gitignore = read('.gitignore');

  it('包含 node_modules/、.nsh/、target/', () => {
    for (const entry of ['node_modules/', '.nsh/', 'target/']) {
      assert.ok(
        gitignore.split(/\r?\n/).includes(entry),
        `.gitignore 缺少 ${entry}`,
      );
    }
  });
});
