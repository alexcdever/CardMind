#!/usr/bin/env dart
// Markdown Link Checker
// Markdown 链接检查工具

import 'dart:io';

void main(List<String> args) {
  print('🔗 Checking Markdown Links...');
  print('🔗 检查 Markdown 链接...');
  print('=' * 60);
  print('');

  final checker = MarkdownLinkChecker();
  final exitCode = checker.run(args);
  exit(exitCode);
}

class MarkdownLinkChecker {
  final List<String> brokenLinks = [];
  final List<String> warnings = [];
  int totalLinks = 0;
  int checkedFiles = 0;

  int run(List<String> args) {
    // Get list of markdown files to check
    final files = args.isEmpty ? getAllMarkdownFiles() : args;

    if (files.isEmpty) {
      print('⚠️  No markdown files to check');
      print('⚠️  没有要检查的 markdown 文件');
      return 0;
    }

    print('📄 Checking ${files.length} markdown files...');
    print('📄 检查 ${files.length} 个 markdown 文件...');
    print('');

    for (final file in files) {
      checkFile(file);
    }

    printReport();

    return brokenLinks.isEmpty ? 0 : 1;
  }

  List<String> getAllMarkdownFiles() {
    final files = <String>[];
    final dirs = [
      'docs',
      'openspec',
      '.',
    ];

    for (final dir in dirs) {
      final directory = Directory(dir);
      if (!directory.existsSync()) continue;

      final mdFiles = directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .where((f) => !f.path.contains('node_modules'))
          .where((f) => !f.path.contains('.git'))
          .where((f) => !f.path.contains('target'))
          .map((f) => f.path);

      files.addAll(mdFiles);
    }

    return files;
  }

  void checkFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) {
      warnings.add('File not found: $filePath');
      return;
    }

    checkedFiles++;
    final content = file.readAsStringSync();
    final links = extractLinks(content);

    for (final link in links) {
      totalLinks++;
      checkLink(filePath, link);
    }
  }

  List<MarkdownLink> extractLinks(String content) {
    final links = <MarkdownLink>[];

    // Match [text](url) format
    final linkRegex = RegExp(r'\[([^\]]+)\]\(([^\)]+)\)');
    final matches = linkRegex.allMatches(content);

    for (final match in matches) {
      final text = match.group(1)!;
      final url = match.group(2)!;

      // Skip external links
      if (url.startsWith('http://') || url.startsWith('https://')) {
        continue;
      }

      // Skip anchors
      if (url.startsWith('#')) {
        continue;
      }

      links.add(MarkdownLink(text: text, url: url));
    }

    return links;
  }

  void checkLink(String sourceFile, MarkdownLink link) {
    // Resolve relative path
    final sourceDir = File(sourceFile).parent.path;
    final targetPath = resolvePath(sourceDir, link.url);

    // Check if file or directory exists
    final targetFile = File(targetPath);
    final targetDir = Directory(targetPath);

    if (!targetFile.existsSync() && !targetDir.existsSync()) {
      brokenLinks.add('$sourceFile: [${link.text}](${link.url}) -> $targetPath');
    }
  }

  String resolvePath(String baseDir, String relativePath) {
    // Remove anchor
    final path = relativePath.split('#').first;

    // Resolve relative path
    final parts = <String>[];
    parts.addAll(baseDir.split('/'));

    for (final part in path.split('/')) {
      if (part == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else if (part != '.' && part.isNotEmpty) {
        parts.add(part);
      }
    }

    return parts.join('/');
  }

  void printReport() {
    print('');
    print('=' * 60);
    print('📋 LINK CHECK REPORT');
    print('📋 链接检查报告');
    print('=' * 60);
    print('');

    print('📊 Summary / 总结:');
    print('   Files checked: $checkedFiles');
    print('   检查文件数: $checkedFiles');
    print('   Total links: $totalLinks');
    print('   总链接数: $totalLinks');
    print('   Broken links: ${brokenLinks.length}');
    print('   断链数: ${brokenLinks.length}');
    print('   Warnings: ${warnings.length}');
    print('   警告数: ${warnings.length}');
    print('');

    if (brokenLinks.isNotEmpty) {
      print('❌ Broken Links / 断链:');
      for (final link in brokenLinks.take(20)) {
        print('   - $link');
      }
      if (brokenLinks.length > 20) {
        print('   ... and ${brokenLinks.length - 20} more');
        print('   ... 还有 ${brokenLinks.length - 20} 个');
      }
      print('');
    }

    if (warnings.isNotEmpty) {
      print('⚠️  Warnings / 警告:');
      for (final warning in warnings.take(10)) {
        print('   - $warning');
      }
      if (warnings.length > 10) {
        print('   ... and ${warnings.length - 10} more');
        print('   ... 还有 ${warnings.length - 10} 个');
      }
      print('');
    }

    print('=' * 60);
    if (brokenLinks.isEmpty) {
      print('✅ All links are valid!');
      print('✅ 所有链接都有效！');
    } else {
      print('❌ Found ${brokenLinks.length} broken links');
      print('❌ 发现 ${brokenLinks.length} 个断链');
    }
    print('=' * 60);
  }
}

class MarkdownLink {
  final String text;
  final String url;

  MarkdownLink({required this.text, required this.url});
}
