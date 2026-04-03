import 'dart:io';
import 'package:path/path.dart' as path;

/// Markdown引用信息类
class ReferenceInfo {
  final String originalPath;
  final Directory parentDir;

  ReferenceInfo(this.originalPath, this.parentDir);
}

/// 主函数
void main() {
  final projectRoot = Directory.current;
  final references = <String, ReferenceInfo>{};

  /// 扫描所有Markdown文件
  scanMarkdownFiles(projectRoot, references);

  /// 验证引用的文件是否存在
  final missingReferences = verifyReferences(projectRoot, references);

  /// 输出不存在的引用
  printMissingReferences(missingReferences);
}

/// 扫描Markdown文件
void scanMarkdownFiles(
  Directory directory,
  Map<String, ReferenceInfo> references,
) {
  final files = directory.listSync(recursive: true, followLinks: false);

  for (final file in files) {
    if (file is File && file.path.endsWith('.md')) {
      final content = file.readAsStringSync();
      extractReferences(content, file.parent, references);
    }
  }
}

/// 提取引用
void extractReferences(
  String content,
  Directory parentDir,
  Map<String, ReferenceInfo> references,
) {
  /// 匹配Markdown中的相对路径引用，如 [text](./path/to/file.md) 或 [text](../path/to/file.md)
  final regex = RegExp(r'\[.*?\]\(([^)]+\.md)\)');
  final matches = regex.allMatches(content);

  for (final match in matches) {
    final originalPath = match.group(1)!;
    references[originalPath] = ReferenceInfo(originalPath, parentDir);
  }
}

/// 验证引用
List<String> verifyReferences(
  Directory projectRoot,
  Map<String, ReferenceInfo> references,
) {
  final missingReferences = <String>[];

  for (final entry in references.entries) {
    final originalPath = entry.key;
    final referenceInfo = entry.value;

    /// 尝试1: 作为相对于项目根目录的路径
    final absolutePath1 = path.join(projectRoot.path, originalPath);
    if (File(absolutePath1).existsSync()) {
      continue;
    }

    /// 尝试2: 作为相对于引用所在文件目录的路径
    final absolutePath2 = path.normalize(
      path.join(referenceInfo.parentDir.path, originalPath),
    );
    if (File(absolutePath2).existsSync()) {
      continue;
    }

    /// 尝试3: 搜索整个项目中是否存在同名文件
    bool found = false;
    final files = projectRoot.listSync(recursive: true, followLinks: false);
    for (final file in files) {
      if (file is File &&
          file.path.endsWith('.md') &&
          path.basename(file.path) == path.basename(originalPath)) {
        found = true;
        break;
      }
    }

    if (!found) {
      missingReferences.add(originalPath);
    }
  }

  return missingReferences;
}

/// 输出缺失的引用
void printMissingReferences(List<String> missingReferences) {
  stdout.writeln('Missing Markdown references:');
  stdout.writeln('-----------------------------');

  if (missingReferences.isEmpty) {
    stdout.writeln('All references are valid!');
  } else {
    for (final missingPath in missingReferences) {
      stdout.writeln('- $missingPath');
    }
  }
  stdout.writeln('-----------------------------');
}
