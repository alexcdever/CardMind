// 施工方案 1.5（事件回推面，已随 P1 死代码清理删除）+ 1.6（退出钩子）
// 验收测试：读文件断言，不跑构建。
//
// 1.5：Phase-1 演示用的 Bridge 组件（事件回推面）已删除——lib.rs 不再声明
//     Bridge / BridgeEvent / BridgeProps，也不再注册；只断言「不存在」。
// 1.6：`rust-backend/src/sync.rs` 有 `pub async fn close(&self)`，且方法体内
//     `stop_receiver` 出现在 `endpoint.close` 之前；`BackendSync` 模块导出 `close`。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..');
const read = (...p: string[]) => readFileSync(path.join(...p), 'utf8');

// P2-1 起后端接缝拆到 `src/backend/*.rs`；把 lib.rs + 各模块源拼起来，保持原断言语义。
function readModuleSources(): string {
  const backendDir = path.join(here, 'src', 'backend');
  const modules = readdirSync(backendDir).filter((f) => f.endsWith('.rs')).sort();
  return [read(here, 'src', 'lib.rs'), ...modules.map((f) => read(backendDir, f))].join('\n');
}

const lib = readModuleSources();
const syncRs = read(repoRoot, 'rust-backend', 'src', 'sync.rs');

function moduleBlocks(): { name: string; body: string }[] {
  return [...lib.matchAll(/#\[module\]\s*\n\s*impl\s+(\w+)\s*\{([\s\S]*?)\n\}/g)].map(
    (m) => ({ name: m[1], body: m[2] }),
  );
}

/** 取 `pub async fn close` 的方法体（粗略：到同级 `pub fn`/`pub async fn`/末尾）。 */
function closeBody(src: string): string {
  const m = src.match(/pub async fn close\(&self\)[\s\S]*?\n    \}/);
  assert.ok(m, 'sync.rs 应有 `pub async fn close(&self)` 方法');
  return m![0];
}

describe('1.6 SyncService::close（退出钩子）', () => {
  it('sync.rs 有 `pub async fn close(&self)`', () => {
    assert.match(
      syncRs,
      /pub async fn close\(&self\)/,
      'rust-backend/src/sync.rs 应新增 `pub async fn close(&self)`',
    );
  });

  it('close 方法体内 stop_receiver 在 endpoint.close 之前', () => {
    const body = closeBody(syncRs);
    const iStop = body.indexOf('stop_receiver');
    const iClose = body.indexOf('endpoint.close');
    assert.ok(iStop >= 0, 'close() 体内应先调 self.stop_receiver()');
    assert.ok(iClose >= 0, 'close() 体内应再调 self.endpoint.close()');
    assert.ok(
      iStop < iClose,
      `close() 顺序错误：stop_receiver 出现在 ${iStop}，endpoint.close 在 ${iClose}（应先停接收器再关 endpoint）`,
    );
  });

  it('BackendSync 模块导出 close 函数', () => {
    const block = moduleBlocks().find((b) => b.name === 'BackendSync');
    assert.ok(block, 'lib.rs 应有 `#[module] impl BackendSync { .. }` 块');
    assert.match(
      block!.body,
      /fn\s+close\s*\(/,
      'BackendSync 应导出 `fn close`（调 SyncService::close）',
    );
  });
});

describe('1.5 Bridge 演示组件已删除（P1 死代码清理）', () => {
  it('lib.rs 不再声明 Bridge 组件 / 事件 / Props', () => {
    assert.ok(!lib.includes('pub fn Bridge'), 'lib.rs 仍有 `pub fn Bridge` 组件');
    assert.ok(!lib.includes('pub enum BridgeEvent'), 'lib.rs 仍有 `pub enum BridgeEvent`');
    assert.ok(!lib.includes('BridgeProps'), 'lib.rs 仍有 BridgeProps');
  });

  it('native() 不再注册 Bridge', () => {
    assert.ok(!lib.includes('register::<Bridge>()'), 'native() 仍注册 Bridge');
  });

  it('lib.rs 不再有硬编码 `for i in 1..=3` 假事件循环', () => {
    assert.ok(
      !/for\s+\w+\s+in\s+1\.\.=3/.test(lib),
      'lib.rs 仍有硬编码 `for i in 1..=3`（Phase-1 演示循环应随 Bridge 一并删除）',
    );
  });
});
