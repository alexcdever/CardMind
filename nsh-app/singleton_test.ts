// 全局单例 + Backend.Store 验收测试（施工方案 1.7 + 1.4）：读文件断言，不跑构建。
//
// 1.7（全局单例改造）：`#[module]` 的函数不能带 receiver，状态必须放全局——
//   ① `nsh-app/src/lib.rs` 有 `static STORE: OnceLock<NoteStore>` 与
//      `static SYNC: OnceLock<tokio::sync::Mutex<Option<SyncService>>>`；
//   ② `nsh-app/Cargo.toml` 以 path 依赖引入 `cardmind-backend`；
//   ③ `SyncService` 的 `&mut self` 已放宽为 `&self`（只剩 `Drop` 的 `fn drop(&mut self)`）；
//   ④ `api.rs` 已随 P1 死代码清理删除（不再有 `svc: &mut SyncService`）。
// 1.4（Backend.Store 模块）：`#[module]` 导出 store 的 4 个函数（nsh 的模块对象名
//    = 结构体名，故最终形态是 `BackendStore.*`——`#[module]` 不支持嵌套命名空间），
//    App.tsx 启动时 `await` 真后端调用（dataDir → createNoteStore →
//    syncDeviceId → startReceiver；P4 收敛后不再渲染演示结果）。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..');
const read = (...p: string[]) => readFileSync(path.join(...p), 'utf8');

const lib = read(here, 'src', 'lib.rs');
const cargo = read(here, 'Cargo.toml');
const tsx = read(here, 'App.tsx');
const syncRs = read(repoRoot, 'rust-backend', 'src', 'sync.rs');

/** 所有 `#[module] impl X { .. }` 块：名字 + 块体。 */
function moduleBlocks(): { name: string; body: string }[] {
  return [...lib.matchAll(/#\[module\]\s*\n\s*impl\s+(\w+)\s*\{([\s\S]*?)\n\}/g)].map(
    (m) => ({ name: m[1], body: m[2] }),
  );
}

/** store 模块的名字（含 `fn generate_note_id` 的那个 `#[module]` 块）。 */
function storeModuleName(): string {
  const found = moduleBlocks().find((b) => b.body.includes('fn generate_note_id'));
  assert.ok(
    found,
    'lib.rs 应有一个含 `fn generate_note_id` 的 `#[module] impl <Module> { .. }` 块',
  );
  return found!.name;
}

describe('1.7 全局单例（OnceLock）', () => {
  it('Cargo.toml 以 path 依赖引入 cardmind-backend', () => {
    assert.match(
      cargo,
      /cardmind-backend\s*=\s*\{[^}]*path\s*=/,
      'nsh-app/Cargo.toml 应有 `cardmind-backend = { path = ".." }`',
    );
  });

  it('lib.rs 有 static STORE: OnceLock<NoteStore>', () => {
    assert.match(
      lib,
      /static\s+STORE\s*:\s*OnceLock\s*<\s*NoteStore\s*>/,
      'lib.rs 应声明 `static STORE: OnceLock<NoteStore>`',
    );
  });

  it('lib.rs 有 static SYNC: OnceLock<tokio::sync::Mutex<Option<SyncService>>>', () => {
    assert.match(
      lib,
      /static\s+SYNC\s*:\s*OnceLock\s*<\s*tokio::sync::Mutex\s*<\s*Option\s*<\s*SyncService\s*>>>/,
      'lib.rs 应声明 `static SYNC: OnceLock<tokio::sync::Mutex<Option<SyncService>>>`',
    );
  });
});

describe('1.7 SyncService 签名放宽（&mut self → &self）', () => {
  it('sync.rs 的 `&mut self` 只剩 Drop impl 的 `fn drop(&mut self)`', () => {
    const offenders = syncRs
      .split(/\r?\n/)
      .map((line, i) => ({ line, n: i + 1 }))
      .filter(({ line }) => line.includes('&mut self'))
      .filter(({ line }) => !/fn\s+drop\(\s*&mut self\s*\)/.test(line));
    assert.deepEqual(
      offenders.map((o) => `${o.n}: ${o.line.trim()}`),
      [],
      'sync.rs 仍有方法借 `&mut self`',
    );
  });

  it('sync.rs 关键方法改为 `&self`', () => {
    for (const name of [
      'create_note',
      'update_note',
      'update_metadata',
      'soft_delete_note',
      'restore_note',
      'purge_note',
      'purge_expired',
      'import_all',
      'accept_pairing_request',
      'accept_pairing_request_with_timeout',
      'run_sync_cycle',
    ]) {
      assert.match(
        syncRs,
        new RegExp(`fn\\s+${name}\\(\\s*&self`),
        `sync.rs 的 \`${name}\` 应改为 \`&self\``,
      );
    }
  });

  it('api.rs 已删除（P1 死代码清理，导出层不再存在）', () => {
    assert.ok(
      !existsSync(path.join(repoRoot, 'rust-backend', 'src', 'api.rs')),
      'rust-backend/src/api.rs 应已删除',
    );
  });
});

describe('1.4 Backend.Store 模块（#[module]，状态取全局单例）', () => {
  it('native() 注册了 store 模块', () => {
    const name = storeModuleName();
    assert.ok(lib.includes(`.module::<${name}>()`), `native() 应 .module::<${name}>()`);
  });

  it('store 模块导出 4 个函数（generateNoteId / createNoteStore / storeList / storeSearch）', () => {
    const name = storeModuleName();
    const block = moduleBlocks().find((b) => b.name === name)!;
    for (const fn of ['generate_note_id', 'create_note_store', 'store_list', 'store_search']) {
      assert.ok(block.body.includes(`fn ${fn}`), `store 模块应导出 \`fn ${fn}\``);
    }
    assert.ok(
      !/fn\s+\w+\(\s*&(mut\s+)?self/.test(block.body),
      '#[module] 的函数不能带 receiver',
    );
  });

  it('模块函数内部取全局 STORE 单例（不再自己 new 一个）', () => {
    assert.ok(
      /STORE\.get_or_init\(|STORE\.get\(\)/.test(lib),
      'lib.rs 的模块函数应经 `STORE.get_or_init(..)` / `STORE.get()` 取全局 store',
    );
  });
});

describe('App.tsx 真调用后端模块（启动契约）', () => {
  it('await 了 store 模块调用', () => {
    const name = storeModuleName();
    assert.match(tsx, new RegExp(`await\\s+${name}\\.`), `App.tsx 应 \`await ${name}.xxx(\``);
  });

  it('启动串起 store + SYNC 单例（非占位、非 [object Promise]）', () => {
    assert.ok(!tsx.includes('[object Promise]'), 'App.tsx 不应出现 [object Promise]');
    const name = storeModuleName();
    // 审查补强（P4 收敛后）：结果不再渲染进 Text（演示面板已删），改为锁住
    // 「TSX 侧真调用」——SYNC 单例要被 syncDeviceId → ensure_sync → 真
    // SyncService::new() 建起 iroh endpoint，再由 startReceiver 真正开始收。
    assert.match(
      tsx,
      new RegExp(`await\\s+${name}\\.syncDeviceId\\(`),
      `App.tsx 应 \`await ${name}.syncDeviceId()\`（真建 SyncService 走全局 SYNC 单例）`,
    );
    assert.match(
      tsx,
      /await\s+BackendSync\.startReceiver\(/,
      'App.tsx 应 `await BackendSync.startReceiver()`（启动被动接收）',
    );
    // 启动后不得再 close()（Phase 1 演示 bug：启动即关 iroh endpoint）。
    assert.ok(
      !tsx.includes('BackendSync.close('),
      'App.tsx 不应在启动时 BackendSync.close()',
    );
  });
});

describe('.nsh/types/app/native.d.ts（nsh build 生成）', () => {
  const dts = path.join(here, '.nsh', 'types', 'app', 'native.d.ts');

  it('store 模块的 4 个函数生成 Promise 签名', (t) => {
    if (!existsSync(dts)) {
      t.skip('缺 .nsh/types/app/native.d.ts，需先 `nsh build nsh-app -o nsh-app/out`');
      return;
    }
    const decl = readFileSync(dts, 'utf8');
    const name = storeModuleName();
    for (const fn of ['generateNoteId', 'createNoteStore', 'storeList', 'storeSearch']) {
      assert.match(decl, new RegExp(`${fn}\\s*\\(`), `native.d.ts 应导出 \`${fn}(\``);
    }
    assert.match(decl, new RegExp(`\\b${name}\\b`), `native.d.ts 应有模块对象 \`${name}\``);
    assert.match(decl, /Promise</, 'native.d.ts 的模块函数应返回 Promise<T>');
  });
});
