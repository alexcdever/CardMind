// Backend.Notes / Backend.Sync / Backend.Pairing 验收测试（施工方案 1.1 + 1.2 + 1.3）：
// 读文件断言，不跑构建。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..');
const read = (...p: string[]) => readFileSync(path.join(...p), 'utf8');

const lib = read(here, 'src', 'lib.rs');
const storeRs = read(repoRoot, 'rust-backend', 'src', 'store.rs');
const syncRs = read(repoRoot, 'rust-backend', 'src', 'sync.rs');

function moduleBlocks(): { name: string; body: string }[] {
  return [...lib.matchAll(/#\[module\]\s*\n\s*impl\s+(\w+)\s*\{([\s\S]*?)\n\}/g)].map(
    (m) => ({ name: m[1], body: m[2] }),
  );
}

function moduleBlock(name: string): { name: string; body: string } {
  const found = moduleBlocks().find((b) => b.name === name);
  assert.ok(found, `lib.rs 应有 \`#[module] impl ${name} { .. }\` 块`);
  return found!;
}

describe('1.1 BackendNotes 模块', () => {
  it('#[module] impl BackendNotes 存在且导出整组函数', () => {
    const block = moduleBlock('BackendNotes');
    for (const fn of [
      'note_create', 'note_get', 'note_update_metadata',
      'note_soft_delete', 'note_restore', 'note_purge',
      'purge_expired_trash', 'store_trash_list',
      'search_notes', 'auto_complete_links', 'get_all_tags',
      'search_by_tag', 'get_outgoing_links', 'get_backlinks',
      'note_export_all', 'note_import_all', 'sync_notes_to_store',
    ]) {
      assert.ok(block.body.includes(`fn ${fn}`), `BackendNotes 应导出 \`fn ${fn}\``);
    }
    assert.ok(!/fn\s+\w+\(\s*&(mut\s+)?self/.test(block.body), 'module fn 不能带 receiver');
  });

  it('native() 注册 BackendNotes', () => {
    assert.ok(lib.includes('.module::<BackendNotes>()'));
  });
});

describe('1.2 BackendSync 模块', () => {
  it('#[module] impl BackendSync 存在且导出整组函数', () => {
    const block = moduleBlock('BackendSync');
    for (const fn of [
      'set_sync_allowed', 'get_sync_allowed', 'pending_sync_count',
      'sync_poll_interval_secs', 'push_pending', 'run_sync_cycle',
      'start_receiver', 'stop_receiver', 'receiver_running',
      'receiver_content_revision', 'push_to_peer', 'accept_push',
      'push_to_devices', 'check_device_connectivity',
      'accept_push_and_import', 'create_sync_service',
    ]) {
      assert.ok(block.body.includes(`fn ${fn}`), `BackendSync 应导出 \`fn ${fn}\``);
    }
    assert.ok(!/fn\s+\w+\(\s*&(mut\s+)?self/.test(block.body));
  });

  it('native() 注册 BackendSync', () => {
    assert.ok(lib.includes('.module::<BackendSync>()'));
  });
});

describe('1.3 BackendPairing 模块', () => {
  it('#[module] impl BackendPairing 存在且导出整组函数', () => {
    const block = moduleBlock('BackendPairing');
    for (const fn of [
      'get_device_id', 'get_device_name', 'set_device_name',
      'set_device_name_and_notify', 'local_addrs',
      'begin_pairing_accept', 'begin_pairing_accept_with_advertising',
      'stop_pairing_advertising', 'sync_discover_peers', 'discover_peers',
      'accept_pairing_request', 'accept_pairing_request_with_timeout',
      'confirm_pairing', 'begin_pairing_connect',
      'begin_pairing_credential', 'begin_pairing_credential_with_advertising',
      'parse_pairing_credential', 'begin_pairing_connect_with_credential',
      'list_paired_devices', 'remove_paired_device', 'start_advertising',
    ]) {
      assert.ok(block.body.includes(`fn ${fn}`), `BackendPairing 应导出 \`fn ${fn}\``);
    }
    assert.ok(!/fn\s+\w+\(\s*&(mut\s+)?self/.test(block.body));
  });

  it('native() 注册 BackendPairing', () => {
    assert.ok(lib.includes('.module::<BackendPairing>()'));
  });
});

describe('行类型 DTO（nsh-app 侧镜像 + JsObject derive）', () => {
  it('NoteRow/LinkRow/PairedDeviceRow/PeerInfo 有 JsObject DTO', () => {
    for (const dto of ['NoteDto', 'LinkDto', 'PairedDeviceDto', 'PeerInfoDto']) {
      assert.match(lib, new RegExp(`pub struct ${dto}\\b`), `lib.rs 应有 ${dto}`);
      const idx = lib.indexOf(`pub struct ${dto}`);
      const head = lib.slice(Math.max(0, idx - 300), idx);
      assert.match(head, /#\[derive\([^)]*JsObject[^)]*\)\]/, `${dto} 应有 #[derive(JsObject)]`);
    }
  });
});

describe('防污染：rust-backend 内核不依赖 nsh-core / JsObject', () => {
  it('store.rs 与 sync.rs 不含 nsh_core / nsh-core / JsObject', () => {
    for (const [name, src] of [['store.rs', storeRs], ['sync.rs', syncRs]] as const) {
      assert.ok(!src.includes('nsh_core'), `${name} 不应出现 nsh_core`);
      assert.ok(!src.includes('nsh-core'), `${name} 不应出现 nsh-core`);
      assert.ok(!src.includes('JsObject'), `${name} 不应出现 JsObject`);
    }
  });
});
