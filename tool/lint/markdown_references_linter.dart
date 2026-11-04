import 'dart:io';

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
  // NSH 迁移期的旧探针（未跟踪、仅存在于旧机器）与旧 WebView 前端（P2 删除）。
  // 注意只豁免这两个**未跟踪**的旧探针目录：`spike/nsh-editor-md-probe/`
  // 是已提交的 P2 探针（源码/截图），指向它的引用必须照常校验。
  'spike/nsh-probe/',
  'spike/nsh-rich-editor-probe/',
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
  final relative = _relativePathFrom(projectRoot, filePath);

  // 扫描根之外（正常不会出现）：保守起见不检查。
  if (relative.startsWith('../')) {
    return false;
  }

  for (final prefix in ignoredRelativePrefixes) {
    if (relative.startsWith(prefix)) {
      return false;
    }
  }

  final segments = _splitPath(relative);
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
    final resolvedFromSource = _joinPath(
      reference.sourceFile.parent.path,
      decodedPath,
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
    if (isBuildOutputPath(decodedPath) ||
        isDeletedHistoryPath(decodedPath) ||
        isLocalLogPath(decodedPath)) {
      continue;
    }

    final resolvedFromRoot = _joinPath(projectRoot.path, decodedPath);
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
  return _exists(_joinPath(projectRoot.path, first));
}

/// 构建产物目录下的路径不做存在性判定。
bool isBuildOutputPath(String token) =>
    _matchesAnyPrefix(token, buildOutputPrefixes);

/// 已删除历史链路下的路径不做存在性判定。
bool isDeletedHistoryPath(String token) =>
    _matchesAnyPrefix(token, deletedHistoryPrefixes);

/// 本地运行日志（`.log`）不做存在性判定。
///
/// 日志是跑命令的本机产物，仓库从不提交它们：根 `.gitignore` 的 `*.log`
/// 规则（`git ls-files '*.log'` 为空）保证 fresh checkout 里没有任何 `.log`，
/// 文档引用它们只是「本机实测证据」。豁免的**只有日志文件本身**——同一探针
/// 目录下已提交的源码与截图（`App.tsx`、`logs/window-visual2.png` 等）照常判定。
bool isLocalLogPath(String token) =>
    token.replaceAll(r'\', '/').endsWith('.log');

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

String _relativePath(Directory projectRoot, String targetPath) =>
    _relativePathFrom(projectRoot.path, targetPath);

String _kindLabel(ReferenceKind kind) => switch (kind) {
  ReferenceKind.markdownLink => 'markdown link',
  ReferenceKind.inlineCodePath => 'inline code path',
};

// ---------------------------------------------------------------------------
// 零依赖路径工具
//
// 仓库从 4.6 起没有 `pubspec.yaml`（Dart 只服务 `tool/`），所以 linter 不能依赖
// `package:path`：fresh clone / CI 没有 `.dart_tool/package_config.json`，
// `dart tool/lint/…` 会直接以 `Couldn't resolve the package 'path'` 失败，
// 让 pre-commit 门禁在新机器上硬挂。
//
// 下面 4 个函数覆盖原先 `package:path` 的全部用法
// （`relative` / `split` / `normalize(join(...))` / `join`），语义对齐：
//
// - 分隔符统一为 `/`：Windows 输入里的 `\` 先归一化，输出一律用 `/`
//   （Windows API 接受 `/`，`dart:io` 的 `File`/`Directory` 同样接受）；
// - 根单独保留、不参与折叠：前导 `/`、盘符 `C:`、UNC `//`；
// - `.` 段丢弃，`..` 段回退一段；相对路径上越过起点时保留前导 `..`，
//   绝对路径上越过根时丢弃（与 `package:path` 一致）；
// - [_relativePathFrom] 用段比较：公共前缀之后每退一段补一个 `..`，
//   结果为空时返回 `.`。
//
// 已验证范围见 `markdown_references_linter_test.dart`（POSIX + Windows 形态
// 的固定用例）。未覆盖：Windows 上大小写不同的盘符/目录名（`C:` vs `c:`）
// 不做大小写折叠——本 linter 的两侧路径都来自同一个 `Directory`，大小写一致。
// ---------------------------------------------------------------------------

/// 零依赖路径工具的公开门面：linter 内部用的就是这几个函数，
/// `markdown_references_linter_test.dart` 直接校验它们的 POSIX/Windows 行为。
///
/// 仓库没有 `pubspec.yaml`，拿不到 `package:path`（fresh clone / CI 里
/// `package:` import 会直接解析失败），因此这些工具必须留在本文件内。
abstract final class PathTools {
  /// 等价于 `path.normalize`。
  static String normalize(String input) => _normalizePath(input);

  /// 等价于 `path.join` + `path.normalize`。
  static String join(String base, String child) => _joinPath(base, child);

  /// 等价于 `path.relative(target, from: from)`。
  static String relative(String target, {required String from}) =>
      _relativePathFrom(from, target);

  /// 等价于 `path.split`。
  static List<String> split(String input) => _splitPath(input);
}

/// 归一化后的路径：根 + 已解析 `.`/`..` 的段。
class _ParsedPath {
  const _ParsedPath(this.root, this.segments);

  /// 根：`''`（相对路径）、`/`、`C:/`、`//`（UNC）。
  final String root;

  /// 已折叠 `.`/`..` 的路径段（不含空段）。
  final List<String> segments;
}

_ParsedPath _parsePath(String input) {
  final posix = input.replaceAll(r'\', '/');
  var root = '';
  var rest = posix;

  if (rest.startsWith('//')) {
    // UNC 根（`//server/share/…`）：保留前导 `//`，不要折叠成 `/`，
    // 否则 Windows 上重建出的路径会丢掉服务器/共享名。
    root = '//';
    rest = rest.substring(2);
  } else {
    final drive = RegExp(r'^[A-Za-z]:').firstMatch(rest);
    if (drive != null) {
      root = drive.group(0)!;
      rest = rest.substring(root.length);
    }
    if (rest.startsWith('/')) {
      root = '$root/';
      rest = rest.substring(1);
    }
  }

  final segments = <String>[];
  for (final segment in rest.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (segments.isNotEmpty && segments.last != '..') {
        segments.removeLast();
      } else if (root.isEmpty) {
        // 相对路径越过起点：保留 `..`（`../../a`）。
        segments.add('..');
      }
      // 绝对路径越过根：丢弃（`/../a` → `/a`）。
      continue;
    }
    segments.add(segment);
  }
  return _ParsedPath(root, segments);
}

String _renderPath(_ParsedPath parsed) {
  final joined = parsed.segments.join('/');
  if (parsed.root.isEmpty) {
    return joined.isEmpty ? '.' : joined;
  }
  return joined.isEmpty ? parsed.root : '${parsed.root}$joined';
}

/// 等价于 `path.normalize`。
String _normalizePath(String input) => _renderPath(_parsePath(input));

/// 等价于 `path.join` + `path.normalize`（原调用点的外层包装）。
///
/// 子路径是绝对路径时直接采用子路径，与 `package:path` 一致。
String _joinPath(String base, String child) {
  if (child.isEmpty) {
    return _normalizePath(base);
  }
  if (_isAbsolutePath(child) || base.isEmpty) {
    return _normalizePath(child);
  }
  // 根以分隔符结尾（`/`、`C:\`）时不要拼出 `//`——那会被当成 UNC 根。
  final separator = base.endsWith('/') || base.endsWith(r'\') ? '' : '/';
  return _normalizePath('$base$separator$child');
}

/// 等价于 `path.relative(target, from: from)`，结果一律 `/` 分隔。
///
/// 两侧根不同（不同盘符、绝对 vs 相对）时无法表达相对路径，返回归一化后的
/// 绝对目标——与 `package:path` 的行为一致。
String _relativePathFrom(String from, String target) {
  final fromPath = _parsePath(from);
  final targetPath = _parsePath(target);
  if (fromPath.root != targetPath.root) {
    return _renderPath(targetPath);
  }

  final fromSegments = fromPath.segments;
  final targetSegments = targetPath.segments;
  var common = 0;
  while (common < fromSegments.length &&
      common < targetSegments.length &&
      fromSegments[common] == targetSegments[common]) {
    common++;
  }

  final parts = <String>[
    for (var index = common; index < fromSegments.length; index++) '..',
    ...targetSegments.skip(common),
  ];
  return parts.isEmpty ? '.' : parts.join('/');
}

/// 等价于 `path.split`：绝对路径把根作为首段（`/a/b` → `['/', 'a', 'b']`）。
///
/// 与 `package:path` 的差别只在输入未归一化时：这里会先折叠 `.`/`..`/重复
/// 分隔符。调用点（[shouldScanFile]）传入的是 [_relativePathFrom] 的结果，
/// 已经归一化，因此判定不受影响。
List<String> _splitPath(String input) {
  final parsed = _parsePath(input);
  if (parsed.root.isEmpty && parsed.segments.isEmpty) {
    // `package:path`：`split('')` 是空表，`split('.')` 是 `['.']`。
    return input.trim().isEmpty ? const <String>[] : const <String>['.'];
  }
  return parsed.root.isEmpty
      ? parsed.segments
      : <String>[parsed.root, ...parsed.segments];
}

bool _isAbsolutePath(String input) {
  final posix = input.replaceAll(r'\', '/');
  return posix.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(posix);
}
