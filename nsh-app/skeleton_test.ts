// 骨架验收测试（task.md 标准 3–6）：读文件断言，不跑构建。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (name: string) => readFileSync(path.join(here, name), 'utf8');

describe('nsh.json', () => {
  it('是合法 JSON 且 id / rust 字段正确', () => {
    const config = JSON.parse(read('nsh.json'));
    assert.equal(config.id, 'com.cardmind.nsh');
    assert.equal(config.rust, '.');
  });
});

describe('Cargo.toml', () => {
  const manifest = read('Cargo.toml');

  it('声明 nsh-core 与 nsh-base 0.2.0', () => {
    assert.match(manifest, /nsh-core\s*=\s*"0\.2\.0"/);
    assert.match(manifest, /nsh-base\s*=\s*"0\.2\.0"/);
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
