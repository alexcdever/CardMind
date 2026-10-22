// 事件桥验收测试（task.md 标准 3）：读文件断言，不跑构建。
// ①lib.rs 含 `#[derive(Event)]`（事件枚举）；
// ②lib.rs 含 `emit(`（cx.emit 推事件）与 `spawn(`（引擎线程，不能 background）；
// ③App.tsx 引用了 `Bridge` 组件（TSX 侧接入事件桥）。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (name: string) => readFileSync(path.join(here, name), 'utf8');

describe('事件桥 #[component] + #[derive(Event)] + cx.emit', () => {
  const lib = read(path.join('src', 'lib.rs'));

  it('lib.rs 含 #[derive(Event)] 事件枚举', () => {
    assert.match(lib, /#\[derive\(Event\)\]/, 'lib.rs 应有 #[derive(Event)]');
    assert.match(lib, /enum\s+BridgeEvent/, 'lib.rs 应声明 BridgeEvent 枚举');
  });

  it('lib.rs 在 spawn( 里 emit(', () => {
    assert.ok(lib.includes('spawn('), 'lib.rs 应含 spawn(');
    assert.ok(lib.includes('emit('), 'lib.rs 应含 emit(');
    assert.ok(!lib.includes('background('), '事件推送不能用 background(（tokio 线程写不进 thread_local graph）');
  });

  it('native() 注册了 Bridge 组件', () => {
    assert.ok(lib.includes('register::<Bridge>()'), 'native() 应 .register::<Bridge>()');
  });

  it('App.tsx 引用 Bridge 组件', () => {
    const tsx = read('App.tsx');
    assert.match(tsx, /import\s*\{[^}]*\bBridge\b[^}]*\}\s*from\s*["']app\/native["']/, 'App.tsx 应从 app/native import Bridge');
    assert.match(tsx, /<Bridge\b/, 'App.tsx 应渲染 <Bridge');
  });
});
