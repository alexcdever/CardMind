// Phase-1 演示组件已删除（P1 死代码清理）：读文件断言，不跑构建。
// ①`nsh-app/src/lib.rs` 不再声明 App / Bridge / BridgeEvent / BridgeProps，
//   native() 也不再注册它们（演示脚手架无 TSX 消费方）；
// ②App.tsx 不渲染 Phase 1 演示脚手架（`<App/>` 大黑条、`PhaseOneStatus`
//   调试面板、`<Bridge>` 事件行）——启动只挂真实页面栈；
// ③native() 的后端模块注册（启动契约）保持不变。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (name: string) => readFileSync(path.join(here, name), 'utf8');

describe('Phase-1 演示组件已移除', () => {
  const lib = read(path.join('src', 'lib.rs'));

  it('lib.rs 不再声明 Bridge 事件枚举 / Props / 组件', () => {
    assert.ok(!/pub\s+enum\s+BridgeEvent/.test(lib), 'lib.rs 仍声明 BridgeEvent 枚举');
    assert.ok(!/pub\s+struct\s+BridgeProps/.test(lib), 'lib.rs 仍声明 BridgeProps');
    assert.ok(!/pub\s+fn\s+Bridge\s*\(/.test(lib), 'lib.rs 仍声明 Bridge 组件');
    assert.ok(!lib.includes('CardMind NSH skeleton'), 'lib.rs 仍含 "CardMind NSH skeleton"');
  });

  it('lib.rs 不再声明 App 根组件', () => {
    assert.ok(!/pub\s+fn\s+App\s*\(/.test(lib), 'lib.rs 仍声明 App 组件');
  });

  it('native() 不再注册演示组件', () => {
    assert.ok(!lib.includes('register::<Bridge>()'), 'native() 仍 .register::<Bridge>()');
    assert.ok(!lib.includes('register::<App>()'), 'native() 仍 .register::<App>()');
  });

  it('native() 仍注册后端模块（启动契约不变）', () => {
    for (const name of ['BackendStore', 'BackendNotes', 'BackendSync', 'BackendPairing']) {
      assert.ok(
        lib.includes(`.module::<${name}>()`),
        `native() 应仍注册 ${name}（启动契约）`,
      );
    }
  });

  it('App.tsx 不再渲染 Phase 1 脚手架（<App/> / PhaseOneStatus / <Bridge>）', () => {
    const tsx = read('App.tsx');
    assert.ok(
      !tsx.includes('CardMind NSH skeleton'),
      'App.tsx 仍含 "CardMind NSH skeleton"（Phase 1 演示大黑条）',
    );
    assert.ok(
      !/\bPhaseOneStatus\b/.test(tsx),
      'App.tsx 仍引用 PhaseOneStatus（Phase 1 调试面板）',
    );
    assert.ok(
      !/<App\b/.test(tsx),
      'App.tsx 仍渲染 <App/>（Phase 1 演示组件）',
    );
    assert.ok(
      !/<Bridge\b/.test(tsx),
      'App.tsx 仍渲染 <Bridge（Phase 1 事件行）',
    );
    // 不再从 app/native 引入这两个演示符号（其余 Backend* 模块照常）。
    assert.ok(
      !/import\s*\{[^}]*\bBridge\b[^}]*\}\s*from\s*["']app\/native["']/.test(tsx),
      'App.tsx 仍从 app/native import Bridge',
    );
    assert.ok(
      !/import\s*\{[^}]*\bApp\b[^}]*\}\s*from\s*["']app\/native["']/.test(tsx),
      'App.tsx 仍从 app/native import App',
    );
  });
});
