// 构建脚本固化验收测试（task.md 标准 1/2/4）：读文件断言，不跑构建。
// ①package.json 含 `build`/`build:web` script，且不含 `--alias:loro-crdt`；
// ②web/ 存在最小静态站点骨架（index.html + src/index.ts）；
// ③script 产物路径约定含 `web/dist`；
// ④web/.gitignore 忽略 dist/。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));

describe('package.json 构建 scripts', () => {
  const pkg = JSON.parse(readFileSync(path.join(here, 'package.json'), 'utf8'));

  it('含 build script（build:web → nsh build）', () => {
    assert.equal(typeof pkg.scripts?.build, 'string', '缺少 scripts.build');
    // 直接或经包装脚本（build-nsh.mjs）调用 nsh build
    assert.match(pkg.scripts.build, /nsh(\.exe|\.cmd)?\s+build|build-nsh\.mjs/);
    assert.match(pkg.scripts.build, /build:web/, 'build 应先跑 build:web');
  });

  it('含 build:web script（esbuild → web/dist）', () => {
    assert.equal(typeof pkg.scripts?.['build:web'], 'string', '缺少 scripts["build:web"]');
    assert.match(pkg.scripts['build:web'], /esbuild/);
    assert.match(pkg.scripts['build:web'], /web[\\/]dist/);
  });

  it('script 不含 --alias:loro-crdt（网页不跑 loro）', () => {
    for (const [name, cmd] of Object.entries(pkg.scripts ?? {})) {
      assert.ok(
        !String(cmd).includes('--alias:loro-crdt'),
        `scripts.${name} 不应含 --alias:loro-crdt`,
      );
    }
  });
});

describe('web/ 静态站点骨架', () => {
  it('web/index.html 存在并引用 dist/bundle.js', () => {
    const html = readFileSync(path.join(here, 'web', 'index.html'), 'utf8');
    assert.match(html, /dist[\\/]bundle\.js/);
  });

  it('web/src/index.ts 存在（esbuild 入口）', () => {
    assert.ok(existsSync(path.join(here, 'web', 'src', 'index.ts')));
  });

  it('web/.gitignore 忽略 dist/', () => {
    const gitignore = readFileSync(path.join(here, 'web', '.gitignore'), 'utf8');
    assert.ok(
      gitignore.split(/\r?\n/).includes('dist/'),
      'web/.gitignore 缺少 dist/',
    );
  });
});
