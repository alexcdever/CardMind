// 构建脚本固化验收测试：读文件断言 + 一次真实子进程行为断言。
// ①package.json 的 build 直接走 `node build-nsh.mjs`，不含已删除的 `build:web`；
// ②WebView/Tiptap 链路（nsh-app/web/）整目录不存在，devDependencies 不再含
//   esbuild/jsdom/tiptap；
// ③script 产物路径约定不含 web/dist；
// ④build-nsh.mjs 不要求 NSH_SOURCE（0.1.1 遗留），且在 CLI 版本与 Cargo 依赖
//   不一致时以非 0 退出并给出明确错误（0.3.0 起 CLI 的硬门槛）。
import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync, mkdtempSync, writeFileSync, chmodSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const read = (rel: string) => readFileSync(path.join(here, rel), 'utf8');

describe('package.json 构建 scripts（P2：WebView/Tiptap 链路已删）', () => {
  const pkg = JSON.parse(readFileSync(path.join(here, 'package.json'), 'utf8'));

  it('build 直接跑 build-nsh.mjs（nsh build），不再先跑 build:web', () => {
    assert.equal(typeof pkg.scripts?.build, 'string', '缺少 scripts.build');
    assert.match(pkg.scripts.build, /build-nsh\.mjs/);
    assert.doesNotMatch(pkg.scripts.build, /build:web/, 'build 不应再依赖 build:web');
  });

  it('不含 build:web script（esbuild/web 链路已删）', () => {
    assert.equal(pkg.scripts?.['build:web'], undefined, '仍有 scripts["build:web"]');
  });

  it('devDependencies 不含 esbuild/jsdom 与 tiptap/prosemirror 依赖', () => {
    const deps = {
      ...(pkg.dependencies ?? {}),
      ...(pkg.devDependencies ?? {}),
    } as Record<string, string>;
    for (const removed of [
      'esbuild',
      'jsdom',
      'tiptap-markdown',
      'prosemirror-markdown',
    ]) {
      assert.equal(deps[removed], undefined, `仍依赖 ${removed}`);
    }
    for (const name of Object.keys(deps)) {
      assert.ok(
        !name.startsWith('@tiptap/') && !name.startsWith('prosemirror-'),
        `仍依赖 ${name}`,
      );
    }
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

describe('WebView 静态站点已删除', () => {
  it('nsh-app/web/ 不存在（编辑器改原生 Editor）', () => {
    assert.equal(existsSync(path.join(here, 'web')), false, 'web/ 仍存在');
  });
});

/** 把 build-nsh.mjs 跑起来，PATH 上放一个假的 nsh；假 CLI 被要求 build 时写标记文件。 */
function runBuildScript(fakeNsh: { version?: string; exitCode?: number }) {
  const dir = mkdtempSync(path.join(tmpdir(), 'cardmind-fake-nsh-'));
  const marker = path.join(dir, 'build-called.txt');
  const version = fakeNsh.version ?? '0.3.0';
  const code = fakeNsh.exitCode ?? 0;
  try {
    if (process.platform === 'win32') {
      // 用 goto 而不是 if (...) 块：批处理的括号块里出现未转义括号（如 "(fake)"）会
      // 提前闭合块，导致后续行不被执行。
      writeFileSync(
        path.join(dir, 'nsh.cmd'),
        [
          '@echo off',
          'if not "%~1"=="--version" goto run_build',
          `echo nsh ${version} (fake)`,
          'exit /b 0',
          ':run_build',
          `echo %* > "${marker}"`,
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
          `echo "$@" > "${marker}"`,
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
    const result = spawnSync(process.execPath, [path.join(here, 'build-nsh.mjs')], {
      cwd: here,
      env,
      encoding: 'utf8',
      timeout: 60_000,
    });
    return {
      ...result,
      buildCalled: existsSync(marker) ? readFileSync(marker, 'utf8').trim() : null,
    };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

describe('build-nsh.mjs（0.3.0 起：NSH_SOURCE 检查删除，改为 CLI/Cargo 版本一致性）', () => {
  const script = read('build-nsh.mjs');

  it('不再引用 NSH_SOURCE（0.1.1 遗留，0.2.0+ CLI 无此环境变量）', () => {
    assert.doesNotMatch(script, /NSH_SOURCE/, 'build-nsh.mjs 仍在检查 NSH_SOURCE');
  });

  it('调用 nsh build . -o out', () => {
    assert.match(script, /['"]build['"]\s*,\s*['"]\.['"]\s*,\s*['"]-o['"]\s*,\s*['"]out['"]/);
  });

  it('CLI 版本与 Cargo 依赖不一致时非 0 退出并报出两个版本', () => {
    const r = runBuildScript({ version: '0.2.0' });
    assert.notEqual(r.status, 0, 'CLI 0.2.0 与 Cargo 0.4.0 不一致时应非 0 退出');
    const err = `${r.stderr ?? ''}${r.stdout ?? ''}`;
    assert.match(err, /0\.2\.0/, `错误信息应含 CLI 版本 0.2.0，实际：${err.slice(0, 500)}`);
    assert.match(err, /0\.4\.0/, `错误信息应含 Cargo 依赖版本 0.4.0，实际：${err.slice(0, 500)}`);
  });

  it('CLI 版本一致时继续执行 nsh build（假 CLI 退出 0 → 脚本退出 0）', () => {
    const r = runBuildScript({ version: '0.4.0' });
    assert.equal(r.status, 0, `版本一致时应 exit 0，stderr：${(r.stderr ?? '').slice(0, 500)}`);
    assert.match(r.buildCalled ?? '', /build\s+\.\s+-o\s+out/, '应调用 nsh build . -o out');
  });
});
