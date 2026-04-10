import 'dart:io';

import 'package:path/path.dart' as path;

class ReferenceInfo {
  ReferenceInfo({required this.originalPath, required this.sourceFile});

  final String originalPath;
  final File sourceFile;
}

class MissingReference {
  MissingReference({
    required this.originalPath,
    required this.sourceFile,
    required this.resolvedPath,
  });

  final String originalPath;
  final File sourceFile;
  final String resolvedPath;
}

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
  final references = scanMarkdownFiles(root);
  final missingReferences = verifyReferences(root, references);
  printMissingReferences(root, missingReferences, writer);
  return missingReferences.isEmpty ? 0 : 1;
}

List<ReferenceInfo> scanMarkdownFiles(Directory directory) {
  final references = <ReferenceInfo>[];
  final files = directory.listSync(recursive: true, followLinks: false);

  for (final file in files) {
    if (file is! File || !file.path.endsWith('.md')) {
      continue;
    }
    if (_isUnderIgnoredDirectory(file.path)) {
      continue;
    }

    final content = file.readAsStringSync();
    references.addAll(extractReferences(content, file));
  }

  return references;
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

List<MissingReference> verifyReferences(
  Directory projectRoot,
  List<ReferenceInfo> references,
) {
  final missingReferences = <MissingReference>[];

  for (final reference in references) {
    final decodedPath = Uri.decodeFull(reference.originalPath);
    final resolvedPath = path.normalize(
      path.join(reference.sourceFile.parent.path, decodedPath),
    );

    if (File(resolvedPath).existsSync()) {
      continue;
    }

    missingReferences.add(
      MissingReference(
        originalPath: reference.originalPath,
        sourceFile: reference.sourceFile,
        resolvedPath: resolvedPath,
      ),
    );
  }

  return missingReferences;
}

void printMissingReferences(
  Directory projectRoot,
  List<MissingReference> missingReferences,
  void Function(String message) log,
) {
  log('Markdown references check:');
  log('-----------------------------');

  if (missingReferences.isEmpty) {
    log('All references are valid!');
    log('-----------------------------');
    return;
  }

  log('Missing Markdown references:');
  for (final reference in missingReferences) {
    log(
      '- ${_relativePath(projectRoot, reference.sourceFile.path)} -> '
      '${reference.originalPath} '
      '(resolved: ${_relativePath(projectRoot, reference.resolvedPath)})',
    );
  }
  log('-----------------------------');
}

String _relativePath(Directory projectRoot, String targetPath) {
  return path.relative(targetPath, from: projectRoot.path);
}

bool _isUnderIgnoredDirectory(String filePath) {
  final normalizedPath = path.normalize(filePath);
  return path.split(normalizedPath).contains('.worktrees');
}
