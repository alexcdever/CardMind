import 'dart:io';

import 'package:path/path.dart' as path;

/// 引用类型。
enum ReferenceKind {
  /// Markdown 链接：`[文字](相对路径.md)`，相对所在文件解析。
  markdownLink,

  /// 行内代码里的仓库路径：`` `docs/product.md` ``，相对仓库根解析。
  inlineCodePath,
}

class ReferenceInfo {
  ReferenceInfo({
    required this.originalPath,
    required this.sourceFile,
    this.kind = ReferenceKind.markdownLink,
  });

  final String originalPath;
  final File sourceFile;
  final ReferenceKind kind;
}

class MissingReference {
  MissingReference({
    required this.originalPath,
    required this.sourceFile,
    required this.resolvedPath,
    required this.kind,
  });

  final String originalPath;
  final File sourceFile;
  final String resolvedPath;
  final ReferenceKind kind;
}

/// 不参与文档路径检查的目录段（按「相对扫描根」的路径段判断）：
///
/// 1. 各 AI 工具与技能包目录（`.claude/`、`.codex/`、`.github/prompts/` 等）：
///    里面是外部导入内容，引用的是「被服务项目」的路径，不是本仓库的路径；
/// 2. 扫描根之下的 `.worktrees/`（其它 checkout）、`.pipeline/` 等非源码目录；
/// 3. 依赖与构建缓存目录（`node_modules/`、`build/`、`target/` 等）。
const Set<String> ignoredDirectoryNames = <String>{
  'node_modules',
  'build',
  'target',
  '.dart_tool',
  '.git',
  '.pipeline',
  '.pi',
  '.workflow',
  // 本地未跟踪的历史归档快照（`.workflow/` 的备份），不是仓库 live 文档；
  // 扫描它会引入快照内部早已过期的引用。live 文档**指向**它的路径仍由
  // [deletedHistoryPrefixes] 豁免。
  '.workflow-archive-2026-09-30',
  '.worktrees',
  '.agents',
  '.augment',
  '.claude',
  '.codebuddy',
  '.codewhale',
  '.codex',
  '.continue',
  '.cursor',
  '.factory',
  '.gemini',
  '.kilocode',
  '.kiro',
  '.opencode',
  '.qoder',
  '.roo',
  '.trae',
  '.vscode',
  '.warp',
  '.windsurf',
};

/// 外部导入内容的前缀（相对扫描根）。
const List<String> ignoredRelativePrefixes = <String>['.github/prompts/'];

/// 构建产物路径前缀（相对仓库根）：这些路径由构建命令生成，全新 checkout 中并不存在，
/// 文档描述它们不是「指向不存在对象」的错误，因此跳过存在性判定。
///
/// 判定是**前缀匹配**而不是段名匹配：只有确实位于这些目录**之下**的路径才跳过。
/// `lib/build/x.dart` 这类只是段名巧合的路径仍然照常判定。
const List<String> buildOutputPrefixes = <String>[
  'build/',
  '.dart_tool/',
  'rust-backend/target/',
  'sync-verify/target/',
  'nsh-app/target/',
  // `nsh check` / `nsh test` / `nsh package` 生成的目录（types、runt、out 等）。
  'nsh-app/.nsh/',
  'android/build/',
  'android/app/build/',
  'android/app/src/main/jniLibs/',
  'android/.gradle/',
  'macos/build/',
  'linux/build/',
  'windows/build/',
];

/// 已删除历史链路的前缀（相对仓库根）：文档仍会作为历史记录引用这些路径，
/// 但它们在全新 checkout 中必然不存在，不是「指向不存在对象」的错误。
///
/// 覆盖：Flutter 前端链路（迁移 4.6 整删）、NSH 迁移期的探针与旧 WebView 前端、
/// Flutter 时代平台工程与本地生成/归档目录。
///
/// 判定与 [buildOutputPrefixes] 相同——**前缀匹配**：token 等于前缀本身
/// （去掉尾部 `/`）或位于其下才跳过。`libx/a.dart`、`docs/devtools/a.md`、
/// `nsh-app/webx/a.ts` 这类只是名字相近的路径仍照常判定；扫描范围也仍由
/// [shouldScanFile] 决定——这里只豁免「已删除对象」的存在性，不关闭文档检查。
const List<String> deletedHistoryPrefixes = <String>[
  // Flutter 前端链路（迁移 4.6 整删）。
  'lib/',
  'test/',
  'integration_test/',
  'docs/dev/',
  // Flutter 时代平台工程（打包已改走 `nsh package`）。
  'android/',
  'macos/',
  'linux/',
  'windows/',
  // NSH 迁移期探针与旧 WebView 前端（P2 删除）。
  'spike/',
  'nsh-app/web/',
  'nsh-app/editor_page_test.ts',
  'nsh-app/editor_test_entry.tsx',
  'nsh-app/editor_test_repo.ts',
  // Flutter 时代的 Dart 边界扫描器（4.6 删除；Rust 版在 rust-backend/tool/）。
  'tool/boundary_scanner',
  // 旧打包产物（整个 `.nsh/` 另见 buildOutputPrefixes）。
  'nsh-app/out/',
  'nsh-app/.nsh/out/',
  // 本地 git 元数据与历史归档（worktree 的 `.git` 是文件，内容随机器变化）。
  '.git/',
  '.workflow-archive-2026-09-30/',
];

Future<void> main() async {
  final exit = await runMarkdownReferencesLint();
  exitCode = exit;
}

Future<int> runMarkdownReferencesLint({
  Directory? projectRoot,
  void Function(String message)? log,
}) async {
  final root = projectRoot ?? Directory.current;
  final writer = log ?? (String message) => stdout.writeln(message);
  final files = listScannableMarkdownFiles(root);
  final references = extractReferencesIn(files);
  final missingReferences = verifyReferences(root, references);
  printMissingReferences(
    root,
    files.length,
    references,
    missingReferences,
    writer,
  );
  return missingReferences.isEmpty ? 0 : 1;
}

/// 参与检查的 markdown 文件（按「相对扫描根」的路径段过滤）。
List<File> listScannableMarkdownFiles(Directory directory) => directory
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((file) => file.path.endsWith('.md'))
    .where((file) => shouldScanFile(directory.path, file.path))
    .toList();

List<ReferenceInfo> scanMarkdownFiles(Directory directory) =>
    extractReferencesIn(listScannableMarkdownFiles(directory));

List<ReferenceInfo> extractReferencesIn(List<File> files) {
  final references = <ReferenceInfo>[];

  for (final file in files) {
    final content = file.readAsStringSync();
    references
      ..addAll(extractReferences(content, file))
      ..addAll(extractInlineCodePathReferences(content, file));
  }

  return references;
}

/// 是否检查该文件。
///
/// 判断基准是「相对扫描根」的路径段，而不是绝对路径：worktree 的绝对路径里
/// 必然含 `.worktrees`，若按绝对路径判断，worktree 自己的文档会被整体跳过，
/// 门禁等于空转。改判相对路径后：
///
/// - 在 worktree 内运行时，worktree 自己的文档照常检查；
/// - 在主工作树运行时，`.worktrees/` 下的其它 checkout 仍不会被递归检查。
bool shouldScanFile(String projectRoot, String filePath) {
  final relative = path
      .relative(filePath, from: projectRoot)
      .replaceAll('\\', '/');

  // 扫描根之外（正常不会出现）：保守起见不检查。
  if (relative.startsWith('../')) {
    return false;
  }

  for (final prefix in ignoredRelativePrefixes) {
    if (relative.startsWith(prefix)) {
      return false;
    }
  }

  final segments = path.split(relative);
  for (final segment in segments.take(segments.length - 1)) {
    if (ignoredDirectoryNames.contains(segment)) {
      return false;
    }
  }

  return true;
}

List<ReferenceInfo> extractReferences(String content, File sourceFile) {
  final regex = RegExp(r'\[[^\]]*\]\(([^)#]+\.md)(?:#[^)]+)?\)');
  final matches = regex.allMatches(content);

  return matches
      .map(
        (match) => ReferenceInfo(
          originalPath: match.group(1)!,
          sourceFile: sourceFile,
        ),
      )
      .toList();
}

/// 提取行内代码里的仓库路径引用（形如 `` `docs/product.md` ``）。
List<ReferenceInfo> extractInlineCodePathReferences(
  String content,
  File sourceFile,
) {
  final references = <ReferenceInfo>[];
  for (final match in _inlineCodePattern.allMatches(content)) {
    final token = _normalizePathToken(match.group(1)!);
    if (token == null) {
      continue;
    }
    references.add(
      ReferenceInfo(
        originalPath: token,
        sourceFile: sourceFile,
        kind: ReferenceKind.inlineCodePath,
      ),
    );
  }
  return references;
}

List<MissingReference> verifyReferences(
  Directory projectRoot,
  List<ReferenceInfo> references,
) {
  final missingReferences = <MissingReference>[];

  for (final reference in references) {
    final decodedPath = Uri.decodeFull(reference.originalPath);
    final resolvedFromSource = path.normalize(
      path.join(reference.sourceFile.parent.path, decodedPath),
    );

    if (_exists(resolvedFromSource)) {
      continue;
    }

    if (reference.kind == ReferenceKind.markdownLink) {
      missingReferences.add(
        MissingReference(
          originalPath: reference.originalPath,
          sourceFile: reference.sourceFile,
          resolvedPath: resolvedFromSource,
          kind: reference.kind,
        ),
      );
      continue;
    }

    // 行内代码路径：只判定本仓库自己的路径，并跳过已知构建产物与
    // 已删除历史链路（历史文档对它们的引用不算死链）。
    if (!isRepoRelativeToken(projectRoot, decodedPath)) {
      continue;
    }
    if (isBuildOutputPath(decodedPath) || isDeletedHistoryPath(decodedPath)) {
      continue;
    }

    final resolvedFromRoot = path.normalize(
      path.join(projectRoot.path, decodedPath),
    );
    if (_exists(resolvedFromRoot)) {
      continue;
    }

    missingReferences.add(
      MissingReference(
        originalPath: reference.originalPath,
        sourceFile: reference.sourceFile,
        resolvedPath: resolvedFromRoot,
        kind: reference.kind,
      ),
    );
  }

  return missingReferences;
}

/// 行内代码路径的判定对象：首段必须是扫描根下真实存在的条目
/// （如 `docs/…`、`rust-backend/…`），避免把第三方约定路径（如 `references/x.md`）
/// 误判为死链。
///
/// `../nsh/types` 这类以 `..` 开头的 token 描述的是仓库**之外**的相对路径
/// （例如 nsh 工具链目录），不是仓库根相对路径，不参与判定。
bool isRepoRelativeToken(Directory projectRoot, String token) {
  final segments = token.split('/');
  final first = segments.first;
  if (first == '..' || first == '.') {
    return false;
  }
  return _exists(path.join(projectRoot.path, first));
}

/// 构建产物目录下的路径不做存在性判定。
bool isBuildOutputPath(String token) =>
    _matchesAnyPrefix(token, buildOutputPrefixes);

/// 已删除历史链路下的路径不做存在性判定。
bool isDeletedHistoryPath(String token) =>
    _matchesAnyPrefix(token, deletedHistoryPrefixes);

/// 前缀匹配（不是段名匹配，也不是子串匹配）：token 等于前缀本身（去掉尾部
/// `/`）或位于其下才命中。`libx/a.dart` 不会命中 `lib/`。
bool _matchesAnyPrefix(String token, List<String> prefixes) {
  final normalized = token.replaceAll(r'\', '/');
  for (final prefix in prefixes) {
    final trimmed = prefix.endsWith('/')
        ? prefix.substring(0, prefix.length - 1)
        : prefix;
    if (normalized == trimmed || normalized.startsWith('$trimmed/')) {
      return true;
    }
  }
  return false;
}

void printMissingReferences(
  Directory projectRoot,
  int scannedFileCount,
  List<ReferenceInfo> references,
  List<MissingReference> missingReferences,
  void Function(String message) log,
) {
  log('Markdown references check:');
  log('-----------------------------');
  log('Scanned files: $scannedFileCount, references: ${references.length}');

  if (missingReferences.isEmpty) {
    log('All references are valid!');
    log('-----------------------------');
    return;
  }

  log('Missing references:');
  for (final reference in missingReferences) {
    log(
      '- ${_relativePath(projectRoot, reference.sourceFile.path)} -> '
      '${reference.originalPath} '
      '(${_kindLabel(reference.kind)}, '
      'resolved: ${_relativePath(projectRoot, reference.resolvedPath)})',
    );
  }
  log('-----------------------------');
}

final RegExp _inlineCodePattern = RegExp(r'`([^`\r\n]+)`');

final RegExp _pathTokenPattern = RegExp(r'^[A-Za-z0-9_./\-]+$');

/// 行内代码里的仓库路径形态：含 `/`、只含路径安全字符、不是绝对路径。
String? _normalizePathToken(String raw) {
  var token = raw.trim();
  if (token.startsWith('./')) {
    token = token.substring(2);
  }
  if (token.endsWith('/')) {
    token = token.substring(0, token.length - 1);
  }
  if (!token.contains('/')) {
    return null;
  }
  if (token.startsWith('/') || token.startsWith('~') || token.endsWith('~')) {
    return null;
  }
  if (!_pathTokenPattern.hasMatch(token)) {
    return null;
  }
  return token;
}

bool _exists(String candidatePath) =>
    File(candidatePath).existsSync() || Directory(candidatePath).existsSync();

String _relativePath(Directory projectRoot, String targetPath) {
  return path.relative(targetPath, from: projectRoot.path);
}

String _kindLabel(ReferenceKind kind) => switch (kind) {
  ReferenceKind.markdownLink => 'markdown link',
  ReferenceKind.inlineCodePath => 'inline code path',
};
