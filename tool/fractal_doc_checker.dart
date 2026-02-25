import 'dart:convert';
import 'dart:io';

const _excludedPrefixes = [
  'build/',
  'rust/target/',
  'ios/Pods/',
  'android/.gradle/',
  'linux/build/',
  'macos/Build/',
  'windows/build/',
];
const _excludedExact = ['pubspec.lock'];

bool isExcludedPath(String relativePath) {
  final normalizedPath = relativePath.replaceAll('\\', '/');
  if (_excludedExact.contains(normalizedPath)) return true;
  for (final prefix in _excludedPrefixes) {
    if (normalizedPath.startsWith(prefix)) return true;
  }
  if (normalizedPath.endsWith('.g.dart') ||
      normalizedPath.endsWith('.freezed.dart')) {
    return true;
  }
  return false;
}

class FractalDocCheckResult {
  FractalDocCheckResult(this.errors);

  final List<String> errors;

  bool get isOk => errors.isEmpty;
}

class FractalDocChecker {
  FractalDocChecker({required this.rootPath});

  final String rootPath;

  Future<FractalDocCheckResult> check({
    required List<String> changedFiles,
  }) async {
    final errors = <String>[];
    for (final relativePath in changedFiles) {
      if (_isAbsolutePath(relativePath)) {
        errors.add('absolute path not allowed: $relativePath');
        continue;
      }
      if (isExcludedPath(relativePath)) {
        continue;
      }
      final file = File.fromUri(Uri.directory(rootPath).resolve(relativePath));
      if (!file.existsSync()) continue;
      final lines = await _readFirstLines(file, 3);
      if (lines.length < 3 || !_looksLikeHeader(lines)) {
        errors.add('missing header: $relativePath');
      }
      final fileName = File(relativePath).uri.pathSegments.last;
      final dirPath = file.parent.path;
      if (!_dirHasEntry(dirPath, fileName)) {
        errors.add('DIR.md missing entry: $relativePath');
      }
    }
    return FractalDocCheckResult(errors);
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

  bool _isAbsolutePath(String path) {
    if (path.startsWith('/')) return true;
    if (path.startsWith('\\')) return true;
    if (RegExp(r'^[A-Za-z]:[\\/]')
        .hasMatch(path)) return true;
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) return true;
    return false;
  }

  bool _looksLikeHeader(List<String> lines) {
    return lines[0].contains('input:') &&
        lines[1].contains('output:') &&
        lines[2].contains('pos:');
  }

  bool _dirHasEntry(String dirPath, String fileName) {
    final dirFile = File('$dirPath/DIR.md');
    if (!dirFile.existsSync()) return false;
    final lines = dirFile.readAsLinesSync();
    final tokenStripper =
        RegExp(r'^[`*\-~\[\](){}<>.,:;!?]+|[`*\-~\[\](){}<>.,:;!?]+$');
    final markdownLink = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    for (final line in lines) {
      for (final match in markdownLink.allMatches(line)) {
        final label = match.group(1);
        final target = match.group(2);
        if (label != null) {
          final labelToken = label.replaceAll(tokenStripper, '');
          if (labelToken == fileName) return true;
        }
        if (target != null) {
          final targetFileName = _linkTargetFileName(target);
          if (targetFileName == fileName) return true;
        }
      }
      final tokens = line.split(RegExp(r'\s+'));
      for (final rawToken in tokens) {
        final token = rawToken.replaceAll(tokenStripper, '');
        if (token == fileName) return true;
      }
    }
    return false;
  }

  String _linkTargetFileName(String target) {
    final withoutQuery = target.split('?').first;
    final withoutFragment = withoutQuery.split('#').first;
    var trimmed = withoutFragment.trim();
    if (trimmed.startsWith('<') && trimmed.endsWith('>')) {
      trimmed = trimmed.substring(1, trimmed.length - 1);
    }
    final normalized = trimmed.replaceAll('\\', '/');
    final parts = normalized.split('/');
    for (var i = parts.length - 1; i >= 0; i--) {
      if (parts[i].isNotEmpty) return parts[i];
    }
    return normalized;
  }
}
