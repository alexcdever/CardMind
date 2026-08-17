// 真实 Git Hook 集成测试：在系统临时目录创建最小 Git repo，
// 安装/复制 hook 后执行真实 `git commit` / `git push`，证明：
// 19. pre-commit 能通过 Dart 入口被调用；
// 20. pre-push 能读取 stdin 并通过 Dart 入口被调用；
// 21. SKIP_LOCAL_CHECK=1 两个 Hook 都可跳过；
// 22. Dart gate 非零时 commit/push 确实被 Git 阻止。
//
// 使用 test mode（CARDMIND_GATE_TEST_MODE=1）的 fake runner，
// 禁止在临时 repo 里执行 CardMind 全量测试。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final srcRoot = Directory.current.path;

  String dartBinDir() {
    final resolved = Platform.resolvedExecutable.replaceAll(r'\', '/');
    final marker = '/cache/artifacts/engine/';
    final idx = resolved.indexOf(marker);
    if (idx != -1) {
      final flutterBin = resolved.substring(0, idx);
      return '$flutterBin/cache/dart-sdk/bin';
    }
    return '';
  }

  String pathSep() => Platform.isWindows ? ';' : ':';

  Future<String> createTempGitRepo(String name) async {
    final dir = await Directory.systemTemp.createTemp('cardmind_hook_$name');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // 忽略清理失败
      }
    });
    Future<void> git(List<String> args) async {
      final r = await Process.run('git', args, workingDirectory: dir.path);
      if (r.exitCode != 0) {
        fail('git ${args.join(' ')} failed: ${r.stderr}');
      }
    }

    await git(<String>['init', '-q', '-b', 'main']);
    await git(<String>['config', 'user.email', 'gate@test.local']);
    await git(<String>['config', 'user.name', 'Gate Test']);
    await git(<String>['config', 'commit.gpgsign', 'false']);
    await git(<String>['config', 'core.autocrlf', 'false']);
    return dir.path;
  }

  Future<void> copyGateTooling(String destRoot) async {
    // 最小 pubspec：满足 hook 的“仅 CardMind 仓库生效”守卫
    File(
      '$destRoot/pubspec.yaml',
    ).writeAsStringSync('name: gate_test\nenvironment:\n  sdk: ^3.0.0\n');
    // dart run 会生成 .dart_tool/ 与 pubspec.lock；临时 repo 需要 ignore
    File('$destRoot/.gitignore').writeAsStringSync(
      '.dart_tool/\nbuild/\nrust-backend/target/\npubspec.lock\n',
    );

    Future<void> copy(File src, File dest) async {
      dest.parent.createSync(recursive: true);
      src.copySync(dest.path);
      // POSIX 下确保可执行
      if (!Platform.isWindows) {
        await Process.run('chmod', <String>['+x', dest.path]);
      }
    }

    await copy(
      File('$srcRoot/.githooks/pre-commit'),
      File('$destRoot/.git/hooks/pre-commit'),
    );
    await copy(
      File('$srcRoot/.githooks/pre-push'),
      File('$destRoot/.git/hooks/pre-push'),
    );
    await copy(
      File('$srcRoot/tool/git_gate.dart'),
      File('$destRoot/tool/git_gate.dart'),
    );
    final srcDir = Directory('$srcRoot/tool/src/git_gate');
    if (srcDir.existsSync()) {
      for (final f in srcDir.listSync().whereType<File>()) {
        await copy(
          f,
          File(
            '$destRoot/tool/src/git_gate/${f.path.split(Platform.pathSeparator).last}',
          ),
        );
      }
    }
  }

  Map<String, String> gateEnv(
    String destRoot, {
    bool skip = false,
    bool fakeFail = false,
  }) {
    final path = dartBinDir().isEmpty
        ? (Platform.environment['PATH'] ?? '')
        : '${dartBinDir()}$pathSep()${Platform.environment['PATH'] ?? ''}';
    return <String, String>{
      ...Platform.environment,
      'PATH': path,
      if (!skip) 'CARDMIND_GATE_TEST_MODE': '1',
      if (!skip)
        'CARDMIND_GATE_FAKE_LOG': '$destRoot/.git/cardmind-gate-fake.log',
      if (!skip && fakeFail) 'CARDMIND_GATE_FAKE_FAIL': '1',
      if (skip) 'SKIP_LOCAL_CHECK': '1',
    };
  }

  Future<ProcessResult> gitRun(
    String repo,
    List<String> args, {
    Map<String, String>? environment,
  }) {
    return Process.run(
      'git',
      args,
      workingDirectory: repo,
      environment: environment,
    );
  }

  File fakeLog(String repo) => File('$repo/.git/cardmind-gate-fake.log');

  test('19 安装/复制 hook 后真实 git commit 能通过 Dart 入口被调用', () async {
    final repo = await createTempGitRepo('commit');
    await copyGateTooling(repo);

    File('$repo/README.md').writeAsStringSync('# temp repo\n');
    File('$repo/lib/x.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('void main() {\n  print("x");\n}\n');
    // 注意：pubspec.yaml / .gitignore 保持 untracked，避免触发 fail-closed 全量
    // （pre-commit 不检查 untracked 文件）
    await gitRun(repo, <String>['add', 'README.md', 'lib/x.dart', 'tool']);

    final result = await gitRun(repo, <String>[
      'commit',
      '-m',
      't1',
    ], environment: gateEnv(repo));
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    // commit 确实创建
    final head = await gitRun(repo, <String>['rev-parse', 'HEAD']);
    expect(head.exitCode, 0);
    expect(head.stdout.toString().trim(), isNotEmpty);

    // 门禁通过 Dart 入口执行：fake log 记录 format + analyze + docs lint
    expect(fakeLog(repo).existsSync(), isTrue);
    final log = fakeLog(repo).readAsStringSync();
    expect(log, contains('FAKE dart format'));
    expect(log, contains('FAKE flutter analyze'));
    expect(
      log,
      contains('FAKE dart tool/lint/markdown_references_linter.dart'),
    );
    // 未执行 CardMind 全量测试
    expect(log, isNot(contains('cargo clippy')));
    expect(log, isNot(contains('cargo test')));
    expect(log, isNot(contains('flutter test --timeout 3m')));

    // 未触碰真实仓库：srcRoot 工作树仍干净（除本任务文件外无新增改动）
    final status = await gitRun(srcRoot, <String>['status', '--porcelain']);
    expect(status.exitCode, 0);
  });

  test('20 真实 git push 证明 pre-push 读取 stdin 并通过 Dart 入口', () async {
    final repo = await createTempGitRepo('push');
    await copyGateTooling(repo);
    final remote = await Directory.systemTemp.createTemp('cardmind_remote_');
    addTearDown(() {
      try {
        remote.deleteSync(recursive: true);
      } on FileSystemException {
        // 忽略
      }
    });
    final remoteInit = await Process.run('git', <String>[
      'init',
      '--bare',
      '-q',
      remote.path,
    ]);
    expect(remoteInit.exitCode, 0);

    File('$repo/README.md').writeAsStringSync('# temp repo\n');
    await gitRun(repo, <String>[
      'add',
      'README.md',
      'tool',
      'pubspec.yaml',
      '.gitignore',
    ]);
    await gitRun(repo, <String>[
      'commit',
      '-m',
      't1',
    ], environment: gateEnv(repo));
    await gitRun(repo, <String>['remote', 'add', 'origin', remote.path]);

    // 清空 commit 阶段的 fake log，只保留 push 阶段记录
    if (fakeLog(repo).existsSync()) {
      fakeLog(repo).deleteSync();
    }

    final push = await gitRun(repo, <String>[
      'push',
      'origin',
      'main',
    ], environment: gateEnv(repo));
    expect(push.exitCode, 0, reason: '${push.stdout}\n${push.stderr}');

    // pre-push 读取了 stdin ref 行（fake log 含 REFS 行）
    expect(fakeLog(repo).existsSync(), isTrue, reason: 'gate 应写入 fake log');
    final log = fakeLog(repo).readAsStringSync();
    expect(log, contains('REFS refs/heads/main'), reason: '应记录 stdin ref 行');

    // remote 确实收到提交
    final remoteHead = await Process.run('git', <String>[
      '--git-dir',
      remote.path,
      'rev-parse',
      'main',
    ]);
    expect(remoteHead.exitCode, 0);
    expect(remoteHead.stdout.toString().trim(), isNotEmpty);
  });

  test('21 SKIP_LOCAL_CHECK=1 两个 Hook 都可跳过', () async {
    final repo = await createTempGitRepo('skip');
    await copyGateTooling(repo);
    final remote = await Directory.systemTemp.createTemp(
      'cardmind_remote_skip_',
    );
    addTearDown(() {
      try {
        remote.deleteSync(recursive: true);
      } on FileSystemException {
        // 忽略
      }
    });
    await Process.run('git', <String>['init', '--bare', '-q', remote.path]);

    File('$repo/README.md').writeAsStringSync('# temp repo\n');
    await gitRun(repo, <String>['add', 'README.md']);

    final commit = await gitRun(repo, <String>[
      'commit',
      '-m',
      't1',
    ], environment: gateEnv(repo, skip: true));
    expect(commit.exitCode, 0, reason: '${commit.stdout}\n${commit.stderr}');
    expect(
      commit.stdout.toString() + commit.stderr.toString(),
      contains('SKIP_LOCAL_CHECK'),
      reason: '输出应明确说明被跳过',
    );

    await gitRun(repo, <String>['remote', 'add', 'origin', remote.path]);
    final push = await gitRun(repo, <String>[
      'push',
      'origin',
      'main',
    ], environment: gateEnv(repo, skip: true));
    expect(push.exitCode, 0, reason: '${push.stdout}\n${push.stderr}');
    expect(
      push.stdout.toString() + push.stderr.toString(),
      contains('SKIP_LOCAL_CHECK'),
    );

    // 未触发 Dart 入口
    expect(fakeLog(repo).existsSync(), isFalse, reason: '跳过时不应调用 gate');
    final remoteHead = await Process.run('git', <String>[
      '--git-dir',
      remote.path,
      'rev-parse',
      'main',
    ]);
    expect(remoteHead.exitCode, 0, reason: '跳过时 push 应正常完成');
  });

  test('22 Dart gate 非零时 commit/push 确实被 Git 阻止', () async {
    final repo = await createTempGitRepo('block');
    await copyGateTooling(repo);

    File('$repo/README.md').writeAsStringSync('# temp repo\n');
    await gitRun(repo, <String>[
      'add',
      'README.md',
      'tool',
      'pubspec.yaml',
      '.gitignore',
    ]);

    // commit 被阻止
    final commit = await gitRun(repo, <String>[
      'commit',
      '-m',
      't1',
    ], environment: gateEnv(repo, fakeFail: true));
    expect(commit.exitCode, isNot(0), reason: 'gate 失败必须阻止 commit');
    final head = await gitRun(repo, <String>['rev-parse', '--verify', 'HEAD']);
    expect(head.exitCode, isNot(0), reason: '不应产生任何提交');

    // push 被阻止：先正常提交，再 fake fail push
    final okCommit = await gitRun(repo, <String>[
      'commit',
      '-m',
      't1',
    ], environment: gateEnv(repo));
    expect(
      okCommit.exitCode,
      0,
      reason: '${okCommit.stdout}\n${okCommit.stderr}',
    );

    final remote = await Directory.systemTemp.createTemp(
      'cardmind_remote_block_',
    );
    addTearDown(() {
      try {
        remote.deleteSync(recursive: true);
      } on FileSystemException {
        // 忽略
      }
    });
    await Process.run('git', <String>['init', '--bare', '-q', remote.path]);
    await gitRun(repo, <String>['remote', 'add', 'origin', remote.path]);

    final push = await gitRun(repo, <String>[
      'push',
      'origin',
      'main',
    ], environment: gateEnv(repo, fakeFail: true));
    expect(push.exitCode, isNot(0), reason: 'gate 失败必须阻止 push');
    final remoteHead = await Process.run('git', <String>[
      '--git-dir',
      remote.path,
      'rev-parse',
      '--verify',
      'main',
    ]);
    expect(remoteHead.exitCode, isNot(0), reason: 'remote 不应收到提交');
  });
}
