// 施工方案 1.5（事件回推面）+ 1.6（退出钩子）验收测试：读文件断言，不跑构建。
//
// 1.5：Bridge 组件的事件必须来自 SyncService 真读（receiver_progress /
//     receiver_running / receiver_content_revision 或 store().list_paired_devices），
//     不再是硬编码 `for i in 1..=3` 假数据；spawn + cx.emit 机制保留。
// 1.6：`rust-backend/src/sync.rs` 有 `pub async fn close(&self)`，且方法体内
//     `stop_receiver` 出现在 `endpoint.close` 之前；`BackendSync` 模块导出 `close`。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..');
const read = (...p: string[]) => readFileSync(path.join(...p), 'utf8');

const lib = read(here, 'src', 'lib.rs');
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

describe('1.5 Bridge 接真数据源（替代硬编码假数据）', () => {
  it('Bridge 不再有硬编码 `for i in 1..=3` 假事件循环', () => {
    assert.ok(
      !/for\s+\w+\s+in\s+1\.\.=3/.test(lib),
      'lib.rs 仍有硬编码 `for i in 1..=3`（1.5 要求改读 SyncService 真状态）',
    );
  });

  it('Bridge 的 spawn 循环读 SyncService 真状态（receiver_progress/running/revision）', () => {
    const m = lib.match(/pub fn Bridge[\s\S]*?\n\}/);
    assert.ok(m, 'lib.rs 应有 `pub fn Bridge` 组件');
    const body = m![0];
    assert.ok(
      /receiver_progress|receiver_running|receiver_content_revision/.test(body),
      'Bridge 的 spawn 应读 SyncService 的 receiver_progress()/receiver_running()/receiver_content_revision()',
    );
    assert.ok(body.includes('emit('), 'Bridge 仍应 cx.emit 推事件');
    assert.ok(body.includes('spawn('), 'Bridge 仍应在 spawn( 里跑引擎线程任务');
  });

  it('peer 发现读真数据源（list_paired_devices 或 discover_peers），不再 format! 假名', () => {
    const m = lib.match(/pub fn Bridge[\s\S]*?\n\}/);
    assert.ok(m, 'lib.rs 应有 `pub fn Bridge` 组件');
    const body = m![0];
    assert.ok(
      /list_paired_devices|discover_peers/.test(body),
      'Bridge 应读 list_paired_devices()/discover_peers() 拿 peer（真数据源）',
    );
    assert.ok(
      !/format!\s*\(\s*"peer-\{/.test(body),
      'Bridge 不应再 format!("peer-{i}") 造假 peer 名',
    );
  });
});
