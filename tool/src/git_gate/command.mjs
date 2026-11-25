// 门禁命令模型：一条可执行的外部检查/测试命令。
//
// 本文件由 tool/src/git_gate/command.dart 移植为 Node.js ESM（门禁工具链
// 已从 Dart 迁移为纯 Node.js，零 npm 依赖，不再需要 Dart SDK）。
// 路径统一使用 POSIX 风格相对路径。

/**
 * 命令类别（同时决定执行优先级，数值越小越先执行）。
 * 与原 Dart enum 的 priority 一一对应；formatDart 已删除（仓库无 .dart 文件）。
 */
export const CommandKind = Object.freeze({
  formatRust: Object.freeze({ name: 'formatRust', priority: 1 }),
  docsLint: Object.freeze({ name: 'docsLint', priority: 10 }),
  clippy: Object.freeze({ name: 'clippy', priority: 20 }),
  rustTest: Object.freeze({ name: 'rustTest', priority: 30 }),
  buildLib: Object.freeze({ name: 'buildLib', priority: 40 }),
  tsxTest: Object.freeze({ name: 'tsxTest', priority: 70 }),
  pythonTest: Object.freeze({ name: 'pythonTest', priority: 80 }),
});

/** 一条门禁命令。 */
export class GateCommand {
  constructor({ executable, arguments: args, kind, label, workingDirectory = null }) {
    this.executable = executable;
    this.arguments = args;

    /** 工作目录（相对仓库根，POSIX 风格）；null 表示仓库根。 */
    this.workingDirectory = workingDirectory;
    this.kind = kind;
    this.label = label;
  }

  /** 去重签名。 */
  get signature() {
    return `${this.executable}|${this.arguments.join(' ')}|${this.workingDirectory ?? ''}`;
  }

  toString() {
    return (
      `${this.label}: ${this.executable} ${this.arguments.join(' ')}` +
      (this.workingDirectory == null ? '' : ` (in ${this.workingDirectory})`)
    );
  }
}

/** 标准命令工厂。 */
export const Commands = {
  formatRust: () =>
    new GateCommand({
      executable: 'cargo',
      arguments: ['fmt', '--all'],
      kind: CommandKind.formatRust,
      label: 'format:rust',
      workingDirectory: 'nsh-app',
    }),

  docsLint: () =>
    new GateCommand({
      executable: 'node',
      arguments: ['tool/lint/markdown_references_linter.mjs'],
      kind: CommandKind.docsLint,
      label: 'docs:lint',
    }),

  // nsh-app 是单 crate workspace（空 [workspace] 表、无 tool/ 成员），--workspace
  // 等价于只跑根 crate nsh-app-cardmind；保留参数与 CI rust_quality.yml 逐字同源。
  clippy: () =>
    new GateCommand({
      executable: 'cargo',
      arguments: [
        'clippy',
        '--all-targets',
        '--all-features',
        '--workspace',
        '--',
        '-D',
        'warnings',
      ],
      kind: CommandKind.clippy,
      label: 'rust:clippy',
      workingDirectory: 'nsh-app',
    }),

  rustTestTarget: (target) =>
    new GateCommand({
      executable: 'cargo',
      arguments: ['test', '--test', target],
      kind: CommandKind.rustTest,
      label: `rust:test:${target}`,
      workingDirectory: 'nsh-app',
    }),

  /** Rust 全量 host 测试。 */
  rustFullTest: () =>
    new GateCommand({
      executable: 'cargo',
      arguments: ['test', '--all-features', '--jobs', '1'],
      kind: CommandKind.rustTest,
      label: 'rust:test:full',
      workingDirectory: 'nsh-app',
    }),

  // release 构建检查：`cargo build --release`。
  // NSH 版把 backend 作为 crate 编进 nsh-app，不存在运行态动态库复制步骤。
  hostBuildLib: () =>
    new GateCommand({
      executable: 'cargo',
      arguments: ['build', '--release'],
      kind: CommandKind.buildLib,
      label: 'rust:build-lib',
      workingDirectory: 'nsh-app',
    }),

  // nsh-app 的 TSX 全量测试：node --test 语义，匹配根级 *_test.ts；
  // 在 nsh-app/ 目录跑（package.json type:module + tsx 依赖）。
  // executable 固定 'npx'——Windows 上由 runner.resolveExecutable 解析为 npx.cmd。
  tsxTest: () =>
    new GateCommand({
      executable: 'npx',
      arguments: ['tsx', '--test', '*_test.ts'],
      kind: CommandKind.tsxTest,
      label: 'tsx:test',
      workingDirectory: 'nsh-app',
    }),

  // tool/release 下发布脚本的 Python 单元测试（unittest discover）。
  // 参数与手动验证命令一致：discover -s tool/release -p test_*.py。
  pythonReleaseTest: () =>
    new GateCommand({
      executable: 'python',
      arguments: [
        '-m',
        'unittest',
        'discover',
        '-s',
        'tool/release',
        '-p',
        'test_*.py',
      ],
      kind: CommandKind.pythonTest,
      label: 'python:test:release',
    }),
};
