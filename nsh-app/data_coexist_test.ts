// 数据共存验收测试（施工方案 4.4）：静态断言 + 真后端运行时探针。
//
// 背景（task.md「已查证的事实」）：旧版 Flutter 的数据在
// `%APPDATA%\com.cardmind\cardmind\`（cardmind.db 读模型 + cardmind.loro 真信源）。
// NSH 壳原先 `createNoteStore(":memory:")` 用内存库，旧笔记一条都看不到。
//
// ① lib.rs `#[module] impl BackendStore` 内有 `fn data_dir`；
// ② Windows 分支指向 `%APPDATA%\com.cardmind\cardmind`；
// ③ App.tsx 不再 `createNoteStore(":memory:")`，改用 `dataDir()` 推导的真路径；
// ④ App.tsx 不再写演示笔记（无 `BackendNotes.noteCreate`/`noteSoftDelete`），
//    启动只做 dataDir → createNoteStore → syncDeviceId → startReceiver；
// ⑤ `.nsh/types/app/native.d.ts`（`nsh build` 生成）导出 `dataDir`；
// ⑥ 运行时：把旧版 `cardmind.db` 复制进 `%TEMP%` 夹具，用真后端 `NoteStore`
//    打开并 `list_notes()` 读出旧笔记——Rust 集成测试
//    `nsh-app/tests/coexist_notes_probe.rs`（`cargo test -p nsh-app-cardmind --test coexist_notes_probe`）
//    承载真正的打开/断言，本测试 spawn 它并断言 exit 0 + `note_count = N`。
//    比起 `nsh trace`+解析 trace，这条路更短、更确定（不打包 GUI）。
//    `NoteStore::new` 会就地迁移（ALTER TABLE + 重建 FTS），故**必须用副本**
//    且本测试断言真实数据目录大小/时间戳前后未变。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, '..');
const read = (...p: string[]) => readFileSync(path.join(...p), 'utf8');

const lib = read(here, 'src', 'lib.rs');
const tsx = read(here, 'App.tsx');

function moduleBlocks(): { name: string; body: string }[] {
  return [...lib.matchAll(/#\[module\]\s*\n\s*impl\s+(\w+)\s*\{([\s\S]*?)\n\}/g)].map((m) => ({
    name: m[1],
    body: m[2],
  }));
}

/** 真实旧数据目录（Flutter 版 CardMind；本测试只读它）。 */
const realDir = path.join(process.env.APPDATA ?? '', 'com.cardmind', 'cardmind');
const realDb = path.join(realDir, 'cardmind.db');
const realLoro = path.join(realDir, 'cardmind.loro');

/** 只读快照：大小 + 修改时间（用来证明真数据未被改）。 */
function snapshot(p: string): string {
  if (!existsSync(p)) return 'missing';
  const s = statSync(p);
  return `${s.size}@${s.mtimeMs}`;
}

describe('4.4 数据共存：NSH 壳直接打开旧版数据目录', () => {
  it('lib.rs `#[module] impl BackendStore` 块内有 `fn data_dir`', () => {
    const block = moduleBlocks().find((b) => b.name === 'BackendStore');
    assert.ok(block, 'lib.rs 应有 `#[module] impl BackendStore { .. }` 块');
    assert.match(block!.body, /fn\s+data_dir\s*\(/, 'BackendStore 应导出 `fn data_dir`');
  });

  it('data_dir 的 Windows 分支指向 `%APPDATA%\\com.cardmind\\cardmind`', () => {
    const block = moduleBlocks().find((b) => b.name === 'BackendStore')!;
    assert.match(
      block.body,
      /com\.cardmind\\cardmind/,
      'data_dir 应含旧版路径 `com.cardmind\\cardmind`（Windows 数据目录）',
    );
    // 回退目录（首次运行）也要在：NSH 自有 com.cardmind.nsh。
    assert.match(block.body, /com\.cardmind\.nsh/, 'data_dir 应回退到 NSH 自有目录');
  });

  it('App.tsx 不再 `createNoteStore(":memory:")`，用 `dataDir()` 真路径', () => {
    assert.ok(
      !tsx.includes('createNoteStore(":memory:")'),
      'App.tsx 不应再 `createNoteStore(":memory:")`（内存库看不到旧笔记）',
    );
    assert.match(
      tsx,
      /await\s+BackendStore\.dataDir\s*\(/,
      'App.tsx 应 `await BackendStore.dataDir()` 推导数据目录',
    );
    assert.match(
      tsx,
      /createNoteStore\(\s*`?\$\{?dataDir/,
      'App.tsx 应把 dataDir() 的结果传给 createNoteStore（真路径）',
    );
  });

  it('App.tsx 不再写演示笔记（启动零写入，用户真实数据只读）', () => {
    // P4 收敛：Phase 1 的演示写（建/改/软删「测试笔记」）已整段删除，
    // 无论首次运行还是找到旧数据都不写——启动只开库/建 SyncService/收。
    for (const call of ['BackendNotes.noteCreate', 'BackendNotes.noteSoftDelete']) {
      assert.ok(!tsx.includes(call), `App.tsx 仍在启动时写演示笔记（${call}）`);
    }
    // 启动契约仍在（上一用例已断言 dataDir/createNoteStore；这里锁住收尾两步）。
    assert.match(
      tsx,
      /await\s+BackendStore\.syncDeviceId\s*\(/,
      'App.tsx 应 `await BackendStore.syncDeviceId()`（建真 SyncService）',
    );
    assert.match(
      tsx,
      /await\s+BackendSync\.startReceiver\s*\(/,
      'App.tsx 应 `await BackendSync.startReceiver()`（启动被动接收）',
    );
    // 旧数据目录判定仍保留：dataDir 返回的 `{dir}|{exists}` 必须被解析。
    assert.match(
      tsx,
      /\.split\(\s*["']\|["']\s*\)/,
      'App.tsx 应解析 dataDir() 的 `{dir}|{exists}` 返回值',
    );
  });

  it('.nsh/types/app/native.d.ts 导出 `dataDir`（nsh build 生成）', (t) => {
    const dts = path.join(here, '.nsh', 'types', 'app', 'native.d.ts');
    if (!existsSync(dts)) {
      t.skip('缺 .nsh/types/app/native.d.ts，需先 `npm run build`（内含 nsh build）');
      return;
    }
    const decl = readFileSync(dts, 'utf8');
    assert.match(decl, /dataDir\s*\(/, 'native.d.ts 应导出 `dataDir(`');
    assert.match(decl, /\bBackendStore\b/, 'native.d.ts 应有 `BackendStore` 模块对象');
  });

  it('运行时：cargo test 在 %TEMP% 夹具副本上读出旧笔记（真数据目录不变）', (t) => {
    if (!existsSync(realDb)) {
      t.skip(`真实旧数据目录缺 ${realDb}，无法验证数据共存`);
      return;
    }
    const probe = path.join(here, 'tests', 'coexist_notes_probe.rs');
    if (!existsSync(probe)) {
      t.skip(`缺 Rust 探针 ${probe}（本任务新增，承载真实打开/断言）`);
      return;
    }

    const before = { db: snapshot(realDb), loro: snapshot(realLoro) };

    // 真后端 NoteStore 直接打开夹具副本：夹具的造/删在 Rust 测试里完成
    // （tests/coexist_notes_probe.rs 复制 realDb → %TEMP%/coexist_probe →
    //   NoteStore::new → list_notes → 用完即删）。本测试只 spawn 并断言 exit 0
    //   + `note_count = N`。
    const out = spawnSync(
      'cargo',
      [
        'test',
        '-p',
        'nsh-app-cardmind',
        '--test',
        'coexist_notes_probe',
        '--',
        '--nocapture',
      ],
      {
        cwd: here,
        encoding: 'utf8',
        timeout: 300_000,
        env: {
          ...process.env,
          // 显式把夹具源传给探针（不依赖探针内部默认路径推导）。
          COEXIST_FIXTURE_DB: realDb,
          // 复用主树编译产物提速（target 在 .gitignore，不污染提交）。
          CARGO_TARGET_DIR:
            process.env.CARGO_TARGET_DIR ?? path.join(repoRoot, 'rust-backend', 'target'),
        },
      },
    );
    const log = `${out.stdout ?? ''}${out.stderr ?? ''}`;
    assert.equal(
      out.status,
      0,
      `cargo test --test coexist_notes_probe 应 exit 0，输出尾部：\n${log.slice(-3000)}`,
    );
    const opened = log.match(/note_count = (\d+)/);
    assert.ok(opened, `探针应输出 \`note_count = N\`，输出尾部：\n${log.slice(-3000)}`);
    assert.ok(Number(opened![1]) > 0, `旧数据应至少 1 条笔记，实际 ${opened![1]}`);

    // 安全：真实数据目录的大小/时间戳前后完全一致（只读夹具副本，绝不写真实库）。
    assert.deepEqual(
      { db: snapshot(realDb), loro: snapshot(realLoro) },
      before,
      '真实数据目录被修改了（大小/时间戳变化）——测试必须只用 %TEMP% 夹具',
    );
  });
});
