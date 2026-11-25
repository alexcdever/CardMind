// Markdown 引用检查器（Node.js 移植版，入口 `node tool/lint/markdown_references_linter.mjs`）。
//
// 本文件由 tool/lint/markdown_references_linter.dart 移植为 Node.js ESM
// （1:1 语义等价），只用 Node 内置模块、零 npm 依赖；原「零依赖路径工具」
// （替代 package:path）一并移植，行为不变——JS 版同样不依赖 Node 的
// `path` 模块语义（统一 `/` 分隔输出）。

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/// 引用类型。
export const ReferenceKind = Object.freeze({
  /// Markdown 链接：`[文字](相对路径.md)`，相对所在文件解析。
  markdownLink: 'markdownLink',

  /// 行内代码里的仓库路径：`` `docs/product.md` ``，相对仓库根解析。
  inlineCodePath: 'inlineCodePath',
});

export class ReferenceInfo {
  constructor({ originalPath, sourceFile, kind = ReferenceKind.markdownLink }) {
    this.originalPath = originalPath;
    this.sourceFile = sourceFile;
    this.kind = kind;
  }
}

export class MissingReference {
  constructor({ originalPath, sourceFile, resolvedPath, kind }) {
    this.originalPath = originalPath;
    this.sourceFile = sourceFile;
    this.resolvedPath = resolvedPath;
    this.kind = kind;
  }
}

/// 不参与文档路径检查的目录段（按「相对扫描根」的路径段判断）：
///
/// 1. 各 AI 工具与技能包目录（`.claude/`、`.codex/`、`.github/prompts/` 等）：
///    里面是外部导入内容，引用的是「被服务项目」的路径，不是本仓库的路径；
/// 2. 扫描根之下的 `.worktrees/`（其它 checkout）、`.pipeline/` 等非源码目录；
/// 3. 依赖与构建缓存目录（`node_modules/`、`build/`、`target/` 等）。
export const ignoredDirectoryNames = new Set([
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
]);

/// 外部导入内容的前缀（相对扫描根）。
export const ignoredRelativePrefixes = ['.github/prompts/'];

/// 构建产物路径前缀（相对仓库根）：这些路径由构建命令生成，全新 checkout 中并不存在，
/// 文档描述它们不是「指向不存在对象」的错误，因此跳过存在性判定。
///
/// 判定是**前缀匹配**而不是段名匹配：只有确实位于这些目录**之下**的路径才跳过。
/// `lib/build/x.dart` 这类只是段名巧合的路径仍然照常判定。
export const buildOutputPrefixes = [
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
export const deletedHistoryPrefixes = [
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
  // P1 死代码清理（2026-11）：FRB 生成物与导出层整删；ADR/迁移/基线文档
  // 作为历史记录仍会引用这两个文件。
  'rust-backend/src/frb_generated.rs',
  'rust-backend/src/api.rs',
  // Rust-native 演示入口（P1 删除；TSX app 由 App.tsx 入口运行）。
  'nsh-app/src/main.rs',
  // 旧打包产物（整个 `.nsh/` 另见 buildOutputPrefixes）。
  'nsh-app/out/',
  'nsh-app/.nsh/out/',
  // 本地 git 元数据与历史归档（worktree 的 `.git` 是文件，内容随机器变化）。
  '.git/',
  '.workflow-archive-2026-09-30/',
];

export function runMarkdownReferencesLint({ projectRoot = null, log = null } = {}) {
  const root = projectRoot ?? process.cwd();
  const writer = log ?? ((message) => process.stdout.write(`${message}\n`));
  const files = listScannableMarkdownFiles(root);
  const references = extractReferencesIn(files);
  const missingReferences = verifyReferences(root, references);
  printMissingReferences(
    root,
    files.length,
    references,
    missingReferences,
    writer,
  );
  return missingReferences.length === 0 ? 0 : 1;
}

/// 参与检查的 markdown 文件（按「相对扫描根」的路径段过滤）。
export function listScannableMarkdownFiles(directory) {
  return _listAllFiles(directory)
    .filter((file) => file.endsWith('.md'))
    .filter((file) => shouldScanFile(directory, file));
}

function _listAllFiles(directory) {
  // 等价 Dart `listSync(recursive: true, followLinks: false)`：
  // Dirent 上 symlink 的 isFile()/isDirectory() 均为 false，自动跳过。
  const result = [];
  const walk = (dir) => {
    for (const entity of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = `${dir}/${entity.name}`;
      if (entity.isDirectory()) {
        walk(full);
      } else if (entity.isFile()) {
        result.push(full);
      }
    }
  };
  walk(directory);
  return result;
}

export function scanMarkdownFiles(directory) {
  return extractReferencesIn(listScannableMarkdownFiles(directory));
}

export function extractReferencesIn(files) {
  const references = [];

  for (const file of files) {
    const content = fs.readFileSync(file, 'utf8');
    references.push(
      ...extractReferences(content, file),
      ...extractInlineCodePathReferences(content, file),
    );
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
export function shouldScanFile(projectRoot, filePath) {
  const relative = _relativePathFrom(projectRoot, filePath);

  // 扫描根之外（正常不会出现）：保守起见不检查。
  if (relative.startsWith('../')) {
    return false;
  }

  for (const prefix of ignoredRelativePrefixes) {
    if (relative.startsWith(prefix)) {
      return false;
    }
  }

  const segments = _splitPath(relative);
  for (const segment of segments.slice(0, segments.length - 1)) {
    if (ignoredDirectoryNames.has(segment)) {
      return false;
    }
  }

  return true;
}

export function extractReferences(content, sourceFile) {
  const regex = /\[[^\]]*\]\(([^)#]+\.md)(?:#[^)]+)?\)/g;
  const references = [];
  for (const match of content.matchAll(regex)) {
    references.push(
      new ReferenceInfo({ originalPath: match[1], sourceFile }),
    );
  }
  return references;
}

/// 提取行内代码里的仓库路径引用（形如 `` `docs/product.md` ``）。
export function extractInlineCodePathReferences(content, sourceFile) {
  const references = [];
  for (const match of content.matchAll(_inlineCodePattern)) {
    const token = _normalizePathToken(match[1]);
    if (token == null) {
      continue;
    }
    references.push(
      new ReferenceInfo({
        originalPath: token,
        sourceFile,
        kind: ReferenceKind.inlineCodePath,
      }),
    );
  }
  return references;
}

export function verifyReferences(projectRoot, references) {
  const missingReferences = [];

  for (const reference of references) {
    const decodedPath = decodeURI(reference.originalPath);
    const resolvedFromSource = _joinPath(
      _parentPath(reference.sourceFile),
      decodedPath,
    );

    if (_exists(resolvedFromSource)) {
      continue;
    }

    if (reference.kind === ReferenceKind.markdownLink) {
      missingReferences.push(
        new MissingReference({
          originalPath: reference.originalPath,
          sourceFile: reference.sourceFile,
          resolvedPath: resolvedFromSource,
          kind: reference.kind,
        }),
      );
      continue;
    }

    // 行内代码路径：只判定本仓库自己的路径，并跳过已知构建产物与
    // 已删除历史链路（历史文档对它们的引用不算死链）。
    if (!isRepoRelativeToken(projectRoot, decodedPath)) {
      continue;
    }
    if (
      isBuildOutputPath(decodedPath) ||
      isDeletedHistoryPath(decodedPath) ||
      isLocalLogPath(decodedPath)
    ) {
      continue;
    }

    const resolvedFromRoot = _joinPath(projectRoot, decodedPath);
    if (_exists(resolvedFromRoot)) {
      continue;
    }

    missingReferences.push(
      new MissingReference({
        originalPath: reference.originalPath,
        sourceFile: reference.sourceFile,
        resolvedPath: resolvedFromRoot,
        kind: reference.kind,
      }),
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
export function isRepoRelativeToken(projectRoot, token) {
  const segments = token.split('/');
  const first = segments[0];
  if (first === '..' || first === '.') {
    return false;
  }
  return _exists(_joinPath(projectRoot, first));
}

/// 构建产物目录下的路径不做存在性判定。
export function isBuildOutputPath(token) {
  return _matchesAnyPrefix(token, buildOutputPrefixes);
}

/// 已删除历史链路下的路径不做存在性判定。
export function isDeletedHistoryPath(token) {
  return _matchesAnyPrefix(token, deletedHistoryPrefixes);
}

/// 本地运行日志（`.log`）不做存在性判定。
///
/// 日志是跑命令的本机产物，仓库从不提交它们：根 `.gitignore` 的 `*.log`
/// 规则（`git ls-files '*.log'` 为空）保证 fresh checkout 里没有任何 `.log`，
/// 文档引用它们只是「本机实测证据」。豁免的**只有日志文件本身**——同一探针
/// 目录下已提交的源码与截图（`App.tsx`、`logs/window-visual2.png` 等）照常判定。
export function isLocalLogPath(token) {
  return token.replaceAll('\\', '/').endsWith('.log');
}

/// 前缀匹配（不是段名匹配，也不是子串匹配）：token 等于前缀本身（去掉尾部
/// `/`）或位于其下才命中。`libx/a.dart` 不会命中 `lib/`。
function _matchesAnyPrefix(token, prefixes) {
  const normalized = token.replaceAll('\\', '/');
  for (const prefix of prefixes) {
    const trimmed = prefix.endsWith('/')
      ? prefix.substring(0, prefix.length - 1)
      : prefix;
    if (normalized === trimmed || normalized.startsWith(`${trimmed}/`)) {
      return true;
    }
  }
  return false;
}

export function printMissingReferences(
  projectRoot,
  scannedFileCount,
  references,
  missingReferences,
  log,
) {
  log('Markdown references check:');
  log('-----------------------------');
  log(`Scanned files: ${scannedFileCount}, references: ${references.length}`);

  if (missingReferences.length === 0) {
    log('All references are valid!');
    log('-----------------------------');
    return;
  }

  log('Missing references:');
  for (const reference of missingReferences) {
    log(
      `- ${_relativePath(projectRoot, reference.sourceFile)} -> ` +
        `${reference.originalPath} ` +
        `(${_kindLabel(reference.kind)}, ` +
        `resolved: ${_relativePath(projectRoot, reference.resolvedPath)})`,
    );
  }
  log('-----------------------------');
}

const _inlineCodePattern = /`([^`\r\n]+)`/g;

const _pathTokenPattern = /^[A-Za-z0-9_./-]+$/;

/// 行内代码里的仓库路径形态：含 `/`、只含路径安全字符、不是绝对路径。
function _normalizePathToken(raw) {
  let token = raw.trim();
  if (token.startsWith('./')) {
    token = token.substring(2);
  }
  if (token.endsWith('/')) {
    token = token.substring(0, token.length - 1);
  }
  if (!token.includes('/')) {
    return null;
  }
  if (token.startsWith('/') || token.startsWith('~') || token.endsWith('~')) {
    return null;
  }
  if (!_pathTokenPattern.test(token)) {
    return null;
  }
  return token;
}

function _exists(candidatePath) {
  return fs.existsSync(candidatePath);
}

function _parentPath(filePath) {
  const posix = filePath.replaceAll('\\', '/');
  const idx = posix.lastIndexOf('/');
  return idx === -1 ? '.' : posix.substring(0, idx);
}

function _relativePath(projectRoot, targetPath) {
  return _relativePathFrom(projectRoot, targetPath);
}

function _kindLabel(kind) {
  switch (kind) {
    case ReferenceKind.markdownLink:
      return 'markdown link';
    case ReferenceKind.inlineCodePath:
      return 'inline code path';
    default:
      return String(kind);
  }
}

// ---------------------------------------------------------------------------
// 零依赖路径工具（Dart 版为替代 package:path 而内建；JS 移植保留同一实现，
// 不改用 `node:path`——它输出 `\` 且语义不同）。
//
// 4 个函数覆盖全部用法（`relative` / `split` / `normalize(join(...))` / `join`），
// 语义对齐 package:path：
//
// - 分隔符统一为 `/`：Windows 输入里的 `\` 先归一化，输出一律用 `/`
//   （Windows API 接受 `/`，Node `fs` 同样接受）；
// - 根单独保留、不参与折叠：前导 `/`、盘符 `C:`、UNC `//`；
// - `.` 段丢弃，`..` 段回退一段；相对路径上越过起点时保留前导 `..`，
//   绝对路径上越过根时丢弃（与 `package:path` 一致）；
// - [_relativePathFrom] 用段比较：公共前缀之后每退一段补一个 `..`，
//   结果为空时返回 `.`。
//
// 已验证范围见 `markdown_references_linter_test.mjs`（POSIX + Windows 形态
// 的固定用例）。未覆盖：Windows 上大小写不同的盘符/目录名（`C:` vs `c:`）
// 不做大小写折叠——本 linter 的两侧路径都来自同一个根目录，大小写一致。
// ---------------------------------------------------------------------------

/// 零依赖路径工具的公开门面：linter 内部用的就是这几个函数，
/// `markdown_references_linter_test.mjs` 直接校验它们的 POSIX/Windows 行为。
export class PathTools {
  /// 等价于 `path.normalize`。
  static normalize(input) {
    return _normalizePath(input);
  }

  /// 等价于 `path.join` + `path.normalize`。
  static join(base, child) {
    return _joinPath(base, child);
  }

  /// 等价于 `path.relative(target, from: from)`。
  static relative(target, { from }) {
    return _relativePathFrom(from, target);
  }

  /// 等价于 `path.split`。
  static split(input) {
    return _splitPath(input);
  }
}

function _parsePath(input) {
  const posix = input.replaceAll('\\', '/');
  let root = '';
  let rest = posix;

  if (rest.startsWith('//')) {
    // UNC 根（`//server/share/…`）：保留前导 `//`，不要折叠成 `/`，
    // 否则 Windows 上重建出的路径会丢掉服务器/共享名。
    root = '//';
    rest = rest.substring(2);
  } else {
    const drive = /^[A-Za-z]:/.exec(rest);
    if (drive != null) {
      root = drive[0];
      rest = rest.substring(root.length);
    }
    if (rest.startsWith('/')) {
      root = `${root}/`;
      rest = rest.substring(1);
    }
  }

  const segments = [];
  for (const segment of rest.split('/')) {
    if (segment.length === 0 || segment === '.') {
      continue;
    }
    if (segment === '..') {
      if (segments.length > 0 && segments[segments.length - 1] !== '..') {
        segments.pop();
      } else if (root.length === 0) {
        // 相对路径越过起点：保留 `..`（`../../a`）。
        segments.push('..');
      }
      // 绝对路径越过根：丢弃（`/../a` → `/a`）。
      continue;
    }
    segments.push(segment);
  }
  return { root, segments };
}

function _renderPath(parsed) {
  const joined = parsed.segments.join('/');
  if (parsed.root.length === 0) {
    return joined.length === 0 ? '.' : joined;
  }
  return joined.length === 0 ? parsed.root : `${parsed.root}${joined}`;
}

/// 等价于 `path.normalize`。
function _normalizePath(input) {
  return _renderPath(_parsePath(input));
}

/// 等价于 `path.join` + `path.normalize`（原调用点的外层包装）。
///
/// 子路径是绝对路径时直接采用子路径，与 `package:path` 一致。
function _joinPath(base, child) {
  if (child.length === 0) {
    return _normalizePath(base);
  }
  if (_isAbsolutePath(child) || base.length === 0) {
    return _normalizePath(child);
  }
  // 根以分隔符结尾（`/`、`C:\`）时不要拼出 `//`——那会被当成 UNC 根。
  const separator = base.endsWith('/') || base.endsWith('\\') ? '' : '/';
  return _normalizePath(`${base}${separator}${child}`);
}

/// 等价于 `path.relative(target, from: from)`，结果一律 `/` 分隔。
///
/// 两侧根不同（不同盘符、绝对 vs 相对）时无法表达相对路径，返回归一化后的
/// 绝对目标——与 `package:path` 的行为一致。
function _relativePathFrom(from, target) {
  const fromPath = _parsePath(from);
  const targetPath = _parsePath(target);
  if (fromPath.root !== targetPath.root) {
    return _renderPath(targetPath);
  }

  const fromSegments = fromPath.segments;
  const targetSegments = targetPath.segments;
  let common = 0;
  while (
    common < fromSegments.length &&
    common < targetSegments.length &&
    fromSegments[common] === targetSegments[common]
  ) {
    common++;
  }

  const parts = [
    ...Array.from({ length: fromSegments.length - common }, () => '..'),
    ...targetSegments.slice(common),
  ];
  return parts.length === 0 ? '.' : parts.join('/');
}

/// 等价于 `path.split`：绝对路径把根作为首段（`/a/b` → `['/', 'a', 'b']`）。
///
/// 与 `package:path` 的差别只在输入未归一化时：这里会先折叠 `.`/`..`/重复
/// 分隔符。调用点（[shouldScanFile]）传入的是 [_relativePathFrom] 的结果，
/// 已经归一化，因此判定不受影响。
function _splitPath(input) {
  const parsed = _parsePath(input);
  if (parsed.root.length === 0 && parsed.segments.length === 0) {
    // `package:path`：`split('')` 是空表，`split('.')` 是 `['.']`。
    return input.trim().length === 0 ? [] : ['.'];
  }
  return parsed.root.length === 0
    ? parsed.segments
    : [parsed.root, ...parsed.segments];
}

function _isAbsolutePath(input) {
  const posix = input.replaceAll('\\', '/');
  return posix.startsWith('/') || /^[A-Za-z]:/.test(posix);
}

const isMain =
  process.argv[1] != null &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  process.exitCode = runMarkdownReferencesLint();
}
