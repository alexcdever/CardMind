// 骨架验收测试（task.md 标准 3–6）：读文件断言，不跑构建。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (name: string) => readFileSync(path.join(here, name), 'utf8');
const manifest = read('Cargo.toml');
const lockfile = read('Cargo.lock');

/** nsh-app 的 TSX 源码（本目录下的 *.tsx；测试文件都是 *_test.ts，不会混进来）。 */
const tsxSources = readdirSync(here)
  .filter((f) => f.endsWith('.tsx'))
  .map((f) => ({ name: f, code: read(f) }));

/** 0.3.0 起不再存在的旧 NSH 子模块路径（一切并入 `nsh` / `nsh/base`）。 */
const LEGACY_NSH_MODULES = ['webview', 'list', 'gesture', 'device', 'keymap', 'animated'];

describe('nsh.json', () => {
  it('是合法 JSON 且 id / rust 字段正确', () => {
    const config = JSON.parse(read('nsh.json'));
    assert.equal(config.id, 'com.cardmind.nsh');
    assert.equal(config.rust, '.');
  });
});

describe('Cargo.toml', () => {
  it('声明 nsh-core 与 nsh-base 0.3.0', () => {
    assert.match(manifest, /nsh-core\s*=\s*"0\.3\.0"/);
    assert.match(manifest, /nsh-base\s*=\s*"0\.3\.0"/);
  });

  // 0.3.0 CLI 硬门槛：Cargo.toml 的 nsh crate 版本必须与 CLI 一致，否则命令入口直接拒绝。
  it('4 个 nsh-platform-* 依赖均为 0.3.0（保留 default-features = false）', () => {
    for (const crate of [
      'nsh-platform-linux',
      'nsh-platform-macos',
      'nsh-platform-windows',
      'nsh-platform-android',
    ]) {
      assert.match(
        manifest,
        new RegExp(`${crate}\\s*=\\s*\\{\\s*version\\s*=\\s*"0\\.3\\.0"`),
        `${crate} 应为 version = "0.3.0"`,
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

  it('列出全部 NSH 依赖包', () => {
    assert.ok(
      nshPackages.length >= 8,
      `Cargo.lock 中 nsh-* 包仅 ${nshPackages.length} 个：${nshPackages.map((p) => p.name).join(', ')}`,
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

  it('nsh_base 只导入 theme（SafeAreaView 在 0.3.0 已移除）', () => {
    assert.match(lib, /use nsh_base::theme;/, 'lib.rs 应 `use nsh_base::theme;`');
    assert.doesNotMatch(lib, /SafeAreaView/, 'lib.rs 仍引用 0.3.0 不存在的 SafeAreaView');
  });

  it('用 view().p_safe_area() 承担安全区', () => {
    assert.match(lib, /\.p_safe_area\(\)/, 'lib.rs 应使用 0.3.0 的 `.p_safe_area()` 样式助手');
  });

  it('main.rs 的 platform::run_app 不变（0.2.0/0.3.0 签名一致）', () => {
    const main = read(path.join('src', 'main.rs'));
    assert.match(main, /platform::run_app\(/);
    assert.match(main, /AppSource::Rust/);
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
    for (const name of ['components.tsx', 'devices_page.tsx', 'settings_page.tsx']) {
      const code = read(name);
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

  it('WebView 从 "nsh" 导入（App.tsx 过渡期保留编辑器）', () => {
    const app = read('App.tsx');
    assert.match(
      app,
      /import\s*\{[^}]*\bWebView\b[^}]*\}\s*from\s*['"]nsh['"]/,
      'App.tsx 的 WebView 应从 "nsh" 导入',
    );
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

  it('screenChrome 传 headerStyle={{ backgroundColor, color, tintColor }}', () => {
    assert.match(nav, /headerStyle\s*:\s*\{/, 'screenChrome 应返回 headerStyle');
    assert.match(nav, /backgroundColor\s*:/);
    assert.match(nav, /tintColor\s*:/);
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
