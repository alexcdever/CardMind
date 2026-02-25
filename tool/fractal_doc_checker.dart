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
      final file = File('$rootPath/$relativePath');
      if (!file.existsSync()) continue;
      final lines = file.readAsLinesSync();
      if (lines.length < 3 || !_looksLikeHeader(lines.take(3).toList())) {
        errors.add('missing header: $relativePath');
      }
    }
    return FractalDocCheckResult(errors);
  }

  bool _looksLikeHeader(List<String> lines) {
    return lines[0].contains('input:') &&
        lines[1].contains('output:') &&
        lines[2].contains('pos:');
  }
}
