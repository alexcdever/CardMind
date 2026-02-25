import 'dart:convert';
import 'dart:io';

import 'fractal_doc_checker.dart';

const _headerLines = [
  '// input: ',
  '// output: ',
  '// pos: ',
];

const _sourceExtensions = {
  '.dart',
  '.rs',
};

Future<void> bootstrapFractalDocs({required String rootPath}) async {
  final rootDir = Directory(rootPath);
  if (!rootDir.existsSync()) return;

  final normalizedRoot = _normalizeRoot(rootPath);
  final dirsWithFiles = <String>{};
  final filesToUpdate = <File>[];

  Future<void> walk(Directory dir) async {
    await for (final entity in dir.list(followLinks: false)) {
      final relativePath = _relativePath(normalizedRoot, entity.path);
      if (entity is Directory) {
        if (relativePath.isNotEmpty && isExcludedPath('$relativePath/')) {
          continue;
        }
        await walk(entity);
        continue;
      }
      if (entity is! File) continue;
      if (relativePath.isEmpty) continue;
      if (isExcludedPath(relativePath)) continue;
      _recordDirAndAncestors(
        normalizedRoot: normalizedRoot,
        dir: entity.parent,
        dirsWithFiles: dirsWithFiles,
      );
      if (_isDirFile(relativePath)) continue;
      if (!_isSourceFile(relativePath)) continue;
      filesToUpdate.add(entity);
    }
  }

  await walk(rootDir);

  for (final dirPath in dirsWithFiles) {
    final dirFile = File('$dirPath/DIR.md');
    if (!dirFile.existsSync()) {
      dirFile.createSync(recursive: true);
    }
  }

  for (final file in filesToUpdate) {
    await _ensureHeader(file);
  }
}

void _recordDirAndAncestors({
  required String normalizedRoot,
  required Directory dir,
  required Set<String> dirsWithFiles,
}) {
  var current = dir;
  while (_isWithinRoot(normalizedRoot, current.path)) {
    final relativePath = _relativePath(normalizedRoot, current.path);
    if (relativePath.isEmpty || !isExcludedPath('$relativePath/')) {
      dirsWithFiles.add(current.path);
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      break;
    }
    current = parent;
  }
}

bool _isWithinRoot(String normalizedRoot, String path) {
  final normalizedPath = path.replaceAll('\\', '/');
  if (normalizedPath == normalizedRoot) return true;
  return normalizedPath.startsWith('$normalizedRoot/');
}

String _normalizeRoot(String path) {
  var normalized = path.replaceAll('\\', '/');
  if (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

String _relativePath(String normalizedRoot, String fullPath) {
  final normalizedFull = fullPath.replaceAll('\\', '/');
  if (normalizedFull == normalizedRoot) return '';
  final withSlash = '$normalizedRoot/';
  if (normalizedFull.startsWith(withSlash)) {
    return normalizedFull.substring(withSlash.length);
  }
  if (normalizedFull.startsWith(normalizedRoot)) {
    var trimmed = normalizedFull.substring(normalizedRoot.length);
    if (trimmed.startsWith('/')) trimmed = trimmed.substring(1);
    return trimmed;
  }
  return normalizedFull;
}

bool _isDirFile(String relativePath) {
  final normalized = relativePath.replaceAll('\\', '/');
  return normalized == 'DIR.md' || normalized.endsWith('/DIR.md');
}

bool _isSourceFile(String relativePath) {
  final normalized = relativePath.replaceAll('\\', '/');
  final name = normalized.split('/').last;
  final dotIndex = name.lastIndexOf('.');
  if (dotIndex == -1) return false;
  final extension = name.substring(dotIndex).toLowerCase();
  return _sourceExtensions.contains(extension);
}

Future<void> _ensureHeader(File file) async {
  final lines = await _readFirstLines(file, 3);
  if (lines.length >= 3 && _looksLikeHeader(lines)) return;
  final original = await file.readAsString();
  final header = _headerLines.join('\n');
  await file.writeAsString('$header\n$original');
}

Future<List<String>> _readFirstLines(File file, int count) async {
  final lines = <String>[];
  await for (final line in file
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())) {
    lines.add(line);
    if (lines.length >= count) break;
  }
  return lines;
}

bool _looksLikeHeader(List<String> lines) {
  return lines[0].contains('input:') &&
      lines[1].contains('output:') &&
      lines[2].contains('pos:');
}
