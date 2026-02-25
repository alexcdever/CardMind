import 'dart:convert';
import 'dart:io';

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
      final file = File.fromUri(Uri.directory(rootPath).resolve(relativePath));
      if (!file.existsSync()) continue;
      final lines = await _readFirstLines(file, 3);
      if (lines.length < 3 || !_looksLikeHeader(lines)) {
        errors.add('missing header: $relativePath');
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

  bool _looksLikeHeader(List<String> lines) {
    return lines[0].contains('input:') &&
        lines[1].contains('output:') &&
        lines[2].contains('pos:');
  }
}
