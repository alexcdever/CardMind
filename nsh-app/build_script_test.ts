// 构建脚本固化验收测试（task.md 标准 1/2/4）：读文件断言 + 一次真实子进程行为断言。
// ①package.json 含 `build`/`build:web` script，且不含 `--alias:loro-crdt`；
// ②web/ 存在最小静态站点骨架（index.html + src/index.ts）；
// ③script 产物路径约定含 `web/dist`；
// ④web/.gitignore 忽略 dist/；
// ⑤build-nsh.mjs 不再要求 NSH_SOURCE（0.1.1 遗留），且在 CLI 版本与 Cargo 依赖
//   不一致时以非 0 退出并给出明确错误（0.3.0 CLI 的硬门槛）。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, mkdtempSync, writeFileSync, chmodSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (rel: string) => readFileSync(path.join(here, rel), 'utf8');

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

/** 把 build-nsh.mjs 跑起来，PATH 上放一个假的 nsh。 */
function runBuildScript(fakeNsh: { version?: string; exitCode?: number }) {
  const dir = mkdtempSync(path.join(tmpdir(), 'cardmind-fake-nsh-'));
  const version = fakeNsh.version ?? '0.3.0';
  const code = fakeNsh.exitCode ?? 0;
  try {
    if (process.platform === 'win32') {
      writeFileSync(
        path.join(dir, 'nsh.cmd'),
        [
          '@echo off',
          'if "%~1"=="--version" (',
          `  echo nsh ${version} (fake)`,
          '  exit /b 0',
          ')',
          `echo [fake-nsh] build %*`,
          `exit /b ${code}`,
          '',
        ].join('\r\n'),
      );
    } else {
      const bin = path.join(dir, 'nsh');
      writeFileSync(
        bin,
        [
          '#!/bin/sh',
          'if [ "$1" = "--version" ]; then',
          `  echo "nsh ${version} (fake)"`,
          '  exit 0',
          'fi',
          'echo "[fake-nsh] build $@"',
          `exit ${code}`,
          '',
        ].join('\n'),
      );
      chmodSync(bin, 0o755);
    }
    const env: NodeJS.ProcessEnv = { ...process.env };
    for (const key of Object.keys(env)) {
      if (/^path$/i.test(key)) delete env[key];
    }
    const basePath = process.env.PATH ?? process.env.Path ?? '';
    env.PATH = dir + path.delimiter + basePath;
    return spawnSync(process.execPath, [path.join(here, 'build-nsh.mjs')], {
      cwd: here,
      env,
      encoding: 'utf8',
      timeout: 60_000,
    });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

describe('build-nsh.mjs（0.3.0：NSH_SOURCE 检查删除，改为 CLI/Cargo 版本一致性）', () => {
  const script = read('build-nsh.mjs');

  it('不再引用 NSH_SOURCE（0.1.1 遗留，0.2.0+ CLI 无此环境变量）', () => {
    assert.doesNotMatch(script, /NSH_SOURCE/, 'build-nsh.mjs 仍在检查 NSH_SOURCE');
  });

  it('调用 nsh build . -o out', () => {
    assert.match(script, /['"]build['"]\s*,\s*['"]\.['"]\s*,\s*['"]-o['"]\s*,\s*['"]out['"]/);
  });

  it('CLI 版本与 Cargo 依赖不一致时非 0 退出并报出两个版本', () => {
    const r = runBuildScript({ version: '0.2.0' });
    assert.notEqual(r.status, 0, 'CLI 0.2.0 与 Cargo 0.3.0 不一致时应非 0 退出');
    const err = `${r.stderr ?? ''}${r.stdout ?? ''}`;
    assert.match(err, /0\.2\.0/, `错误信息应含 CLI 版本 0.2.0，实际：${err.slice(0, 500)}`);
    assert.match(err, /0\.3\.0/, `错误信息应含 Cargo 依赖版本 0.3.0，实际：${err.slice(0, 500)}`);
  });

  it('CLI 版本一致时继续执行 nsh build（假 CLI 退出 0 → 脚本退出 0）', () => {
    const r = runBuildScript({ version: '0.3.0' });
    assert.equal(r.status, 0, `版本一致时应 exit 0，stderr：${(r.stderr ?? '').slice(0, 500)}`);
    assert.match(`${r.stdout ?? ''}`, /build/, '应调用到 nsh build');
  });
});
