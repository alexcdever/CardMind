import 'dart:io';

Set<String> parseRustPublicItems(String source) {
  final Set<String> items = <String>{};
  final List<String> lines = source.split('\n');
  final RegExp structPattern = RegExp(
    r'^\s*pub(\([^)]*\))?\s+struct\s+([A-Za-z_][A-Za-z0-9_]*)',
  );
  final RegExp enumPattern = RegExp(
    r'^\s*pub(\([^)]*\))?\s+enum\s+([A-Za-z_][A-Za-z0-9_]*)',
  );
  final RegExp traitPattern = RegExp(
    r'^\s*pub(\([^)]*\))?\s+trait\s+([A-Za-z_][A-Za-z0-9_]*)',
  );
  final RegExp typePattern = RegExp(
    r'^\s*pub(\([^)]*\))?\s+type\s+([A-Za-z_][A-Za-z0-9_]*)',
  );
  final RegExp constPattern = RegExp(
    r'^\s*pub(\([^)]*\))?\s+const\s+([A-Za-z_][A-Za-z0-9_]*)',
  );
  final RegExp staticPattern = RegExp(
    r'^\s*pub(\([^)]*\))?\s+static\s+([A-Za-z_][A-Za-z0-9_]*)',
  );
  final RegExp fnPattern = RegExp(
    r'^\s*pub(\([^)]*\))?\s+fn\s+([A-Za-z_][A-Za-z0-9_]*)',
  );
  final RegExp implStartPattern = RegExp(
    r'^\s*impl\b[^;{]*\b([A-Za-z_][A-Za-z0-9_]*)\b',
  );
  final RegExp implForPattern = RegExp(r'\bfor\s+([A-Za-z_][A-Za-z0-9_]*)\b');
  final RegExp implMethodPattern = RegExp(
    r'\bpub(\([^)]*\))?\s+fn\s+([A-Za-z_][A-Za-z0-9_]*)',
  );

  String? currentImplType;
  String? pendingImplType;
  int implBraceDepth = 0;

  for (final String rawLine in lines) {
    final String line = _stripLineComment(rawLine).trimRight();
    if (line.isEmpty) {
      continue;
    }

    if (currentImplType == null && pendingImplType != null) {
      if (line.contains('{')) {
        currentImplType = pendingImplType;
        pendingImplType = null;
        implBraceDepth = _braceDelta(line);
      }
    }

    if (currentImplType == null && pendingImplType == null) {
      final RegExpMatch? implMatch = implStartPattern.firstMatch(line);
      if (implMatch != null) {
        final RegExpMatch? forMatch = implForPattern.firstMatch(line);
        final String implType = forMatch != null
            ? forMatch.group(1)!
            : implMatch.group(1)!;
        if (line.contains('{')) {
          currentImplType = implType;
          implBraceDepth = _braceDelta(line);
        } else {
          pendingImplType = implType;
        }
      }
    }

    if (currentImplType != null) {
      final Iterable<RegExpMatch> methodMatches = implMethodPattern.allMatches(
        line,
      );
      for (final RegExpMatch match in methodMatches) {
        final String methodName = match.group(2)!;
        items.add('${currentImplType!}__${methodName}');
      }
      implBraceDepth += _braceDelta(line);
      if (implBraceDepth <= 0) {
        currentImplType = null;
        implBraceDepth = 0;
      }
      continue;
    }

    _addIfMatch(items, structPattern, line);
    _addIfMatch(items, enumPattern, line);
    _addIfMatch(items, traitPattern, line);
    _addIfMatch(items, typePattern, line);
    _addIfMatch(items, constPattern, line);
    _addIfMatch(items, staticPattern, line);

    final RegExpMatch? fnMatch = fnPattern.firstMatch(line);
    if (fnMatch != null) {
      items.add(fnMatch.group(2)!);
    }
  }

  return items;
}

Set<String> parseDartPublicItems(String source) {
  final Set<String> items = <String>{};
  final List<String> lines = source.split('\n');
  final RegExp classPattern = RegExp(r'^\s*class\s+([A-Za-z][A-Za-z0-9_]*)\b');
  final RegExp mixinPattern = RegExp(r'^\s*mixin\s+([A-Za-z][A-Za-z0-9_]*)\b');
  final RegExp enumPattern = RegExp(r'^\s*enum\s+([A-Za-z][A-Za-z0-9_]*)\b');
  final RegExp extensionPattern = RegExp(
    r'^\s*extension\s+([A-Za-z][A-Za-z0-9_]*)\b',
  );
  final RegExp functionPattern = RegExp(
    r'^\s*(?:[A-Za-z0-9_<>,? ]+\s+)?([A-Za-z][A-Za-z0-9_]*)\s*\(',
  );

  String? currentClass;
  int classBraceDepth = 0;

  for (final String rawLine in lines) {
    final String line = _stripLineComment(rawLine).trimRight();
    if (line.isEmpty) {
      continue;
    }

    if (currentClass == null) {
      final RegExpMatch? classMatch = classPattern.firstMatch(line);
      if (classMatch != null) {
        final String className = classMatch.group(1)!;
        if (!className.startsWith('_')) {
          items.add(className);
        }
        currentClass = className;
        classBraceDepth = _braceDelta(line);
        final int bodyStart = line.indexOf('{');
        if (bodyStart != -1) {
          final String body = line.substring(bodyStart + 1);
          final RegExpMatch? methodMatch = functionPattern.firstMatch(body);
          if (methodMatch != null) {
            final String methodName = methodMatch.group(1)!;
            if (!methodName.startsWith('_') && methodName != currentClass) {
              items.add('${currentClass!}__${methodName}');
            }
          }
        }
        if (classBraceDepth <= 0) {
          currentClass = null;
          classBraceDepth = 0;
        }
        continue;
      }
    }

    if (currentClass == null) {
      _addIfMatch(items, mixinPattern, line);
      _addIfMatch(items, enumPattern, line);
      _addIfMatch(items, extensionPattern, line);

      final RegExpMatch? functionMatch = functionPattern.firstMatch(line);
      if (functionMatch != null) {
        final String functionName = functionMatch.group(1)!;
        if (!functionName.startsWith('_') && !_isDartDeclarationKeyword(line)) {
          items.add(functionName);
        }
      }
      continue;
    }

    final String trimmed = line.trimLeft();
    if (trimmed.startsWith('set ')) {
      classBraceDepth += _braceDelta(line);
      if (classBraceDepth <= 0) {
        currentClass = null;
        classBraceDepth = 0;
      }
      continue;
    }

    final RegExpMatch? methodMatch = functionPattern.firstMatch(line);
    if (methodMatch != null) {
      final String methodName = methodMatch.group(1)!;
      if (!methodName.startsWith('_') && methodName != currentClass) {
        items.add('${currentClass!}__${methodName}');
      }
    }

    classBraceDepth += _braceDelta(line);
    if (classBraceDepth <= 0) {
      currentClass = null;
      classBraceDepth = 0;
    }
  }

  return items;
}

Set<String> parseRustUnitTestItems(String source) {
  final Set<String> items = <String>{};
  final List<String> lines = source.split('\n');
  final RegExp testPattern = RegExp(
    r'^\s*(?:async\s+)?fn\s+it_should_([A-Za-z0-9_]+)\s*\(',
  );

  for (final String rawLine in lines) {
    final String line = _stripLineComment(rawLine).trimRight();
    final RegExpMatch? match = testPattern.firstMatch(line);
    if (match != null) {
      items.add(match.group(1)!);
    }
  }

  return items;
}

Set<String> parseDartUnitTestItems(String source) {
  final Set<String> items = <String>{};
  final RegExp testPattern = RegExp(
    r'''test(?:Widgets)?\s*\(\s*['"]it_should_([^'"]+)['"]''',
  );

  final Iterable<RegExpMatch> matches = testPattern.allMatches(source);
  for (final RegExpMatch match in matches) {
    items.add(match.group(1)!);
  }

  return items;
}

CoverageSummary calculateCoverageSummary({
  required Set<String> publicItems,
  required Set<String> unitTestItems,
}) {
  final int expectedCount = publicItems.length;
  final int actualCount = unitTestItems.length;
  final double coverageRate = expectedCount == 0
      ? 1.0
      : (actualCount / expectedCount).clamp(0.0, 1.0);

  return CoverageSummary(
    expectedCount: expectedCount,
    actualCount: actualCount,
    coverageRate: coverageRate,
    missingItems: const <String>[],
  );
}

Future<CoverageSummary> analyzeCoverageFromPaths({
  required List<String> sourceDirectories,
  required List<String> testDirectories,
  required String sourceExtension,
  required String testExtension,
  required Set<String> Function(String) publicParser,
  required Set<String> Function(String) unitTestParser,
  required Set<String> excludedPathFragments,
}) async {
  final Set<String> publicItems = await _collectItemsFromDirectories(
    directories: sourceDirectories,
    extension: sourceExtension,
    parser: publicParser,
    excludedPathFragments: excludedPathFragments,
  );
  final Set<String> unitTestItems = await _collectItemsFromDirectories(
    directories: testDirectories,
    extension: testExtension,
    parser: unitTestParser,
    excludedPathFragments: excludedPathFragments,
  );

  return calculateCoverageSummary(
    publicItems: publicItems,
    unitTestItems: unitTestItems,
  );
}

class CoverageSummary {
  const CoverageSummary({
    required this.expectedCount,
    required this.actualCount,
    required this.coverageRate,
    required this.missingItems,
  });

  final int expectedCount;
  final int actualCount;
  final double coverageRate;
  final List<String> missingItems;
}

Future<Set<String>> _collectItemsFromDirectories({
  required List<String> directories,
  required String extension,
  required Set<String> Function(String) parser,
  required Set<String> excludedPathFragments,
}) async {
  final Set<String> items = <String>{};
  for (final String directoryPath in directories) {
    final Directory directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      continue;
    }
    await for (final FileSystemEntity entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      if (!entity.path.endsWith(extension)) {
        continue;
      }
      if (_isExcludedPath(entity.path, excludedPathFragments)) {
        continue;
      }
      final String contents = await entity.readAsString();
      items.addAll(parser(contents));
    }
  }
  return items;
}

bool _isExcludedPath(String path, Set<String> excludedPathFragments) {
  for (final String fragment in excludedPathFragments) {
    if (path.contains(fragment)) {
      return true;
    }
  }
  return false;
}

void _addIfMatch(Set<String> items, RegExp pattern, String line) {
  final RegExpMatch? match = pattern.firstMatch(line);
  if (match != null) {
    final String? name = match.groupCount >= 2
        ? match.group(2)
        : match.group(1);
    if (name != null && !name.startsWith('_')) {
      items.add(name);
    }
  }
}

String _stripLineComment(String line) {
  final int index = line.indexOf('//');
  if (index == -1) {
    return line;
  }
  return line.substring(0, index);
}

int _braceDelta(String line) {
  int delta = 0;
  for (int i = 0; i < line.length; i += 1) {
    final String char = line[i];
    if (char == '{') {
      delta += 1;
    } else if (char == '}') {
      delta -= 1;
    }
  }
  return delta;
}

bool _isDartDeclarationKeyword(String line) {
  final String trimmed = line.trimLeft();
  return trimmed.startsWith('class ') ||
      trimmed.startsWith('enum ') ||
      trimmed.startsWith('mixin ') ||
      trimmed.startsWith('extension ') ||
      trimmed.startsWith('typedef ');
}
