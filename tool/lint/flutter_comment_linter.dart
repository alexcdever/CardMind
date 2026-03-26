import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

// 配置类
class LinterConfig {
  final bool checkClassComments;
  final bool checkMemberComments;
  final bool checkFormatting;
  final bool autoFix;
  final List<String> excludePaths;

  LinterConfig({
    this.checkClassComments = true,
    this.checkMemberComments = true,
    this.checkFormatting = true,
    this.autoFix = false,
    this.excludePaths = const [],
  });

  factory LinterConfig.fromJson(Map<String, dynamic> json) {
    return LinterConfig(
      checkClassComments: json['checkClassComments'] ?? true,
      checkMemberComments: json['checkMemberComments'] ?? true,
      checkFormatting: json['checkFormatting'] ?? true,
      autoFix: json['autoFix'] ?? false,
      excludePaths: List<String>.from(json['excludePaths'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkClassComments': checkClassComments,
      'checkMemberComments': checkMemberComments,
      'checkFormatting': checkFormatting,
      'autoFix': autoFix,
      'excludePaths': excludePaths,
    };
  }
}

// 问题类
class LinterIssue {
  final String filePath;
  final int lineNumber;
  final String issueType;
  final String message;

  LinterIssue({
    required this.filePath,
    required this.lineNumber,
    required this.issueType,
    required this.message,
  });

  @override
  String toString() {
    return '$filePath:$lineNumber: $issueType - $message';
  }
}

// 注释检查器
class CommentLinter {
  final LinterConfig config;
  final List<LinterIssue> issues = [];
  int validComments = 0;

  CommentLinter(this.config);

  // 扫描目录
  void scanDirectory(String directoryPath) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      print('Directory not found: $directoryPath');
      return;
    }

    final files = directory.listSync(recursive: true, followLinks: false);
    for (final file in files) {
      if (file is File && file.path.endsWith('.dart')) {
        // 检查是否在排除路径中
        bool excluded = false;
        for (final excludePath in config.excludePaths) {
          if (file.path.contains(excludePath)) {
            excluded = true;
            break;
          }
        }
        if (!excluded) {
          checkFile(file.path);
        }
      }
    }
  }

  // 检查文件
  void checkFile(String filePath) {
    final file = File(filePath);
    final lines = file.readAsLinesSync();

    // 检查类注释
    if (config.checkClassComments) {
      checkClassComments(filePath, lines);
    }

    // 检查成员注释
    if (config.checkMemberComments) {
      checkMemberComments(filePath, lines);
    }

    // 检查注释格式
    if (config.checkFormatting) {
      checkCommentFormatting(filePath, lines);
    }
  }

  // 检查类注释
  void checkClassComments(String filePath, List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('class ') ||
          line.startsWith('abstract class ') ||
          line.startsWith('enum ')) {
        // 跳过私有类（以下划线开头）
        if (line.contains('class _')) {
          continue;
        }
        // 检查类注释
        bool hasValidComment = false;
        for (int j = i - 1; j >= 0; j--) {
          final commentLine = lines[j].trim();
          if (commentLine.isEmpty) continue;
          if (commentLine.startsWith('///')) {
            hasValidComment = true;
            validComments++;
            break;
          }
          if (!commentLine.startsWith('///')) {
            break;
          }
        }
        if (!hasValidComment) {
          issues.add(
            LinterIssue(
              filePath: filePath,
              lineNumber: i + 1,
              issueType: 'Missing Class Comment',
              message: 'Class should have a documentation comment',
            ),
          );
        }
      }
    }
  }

  // 检查成员注释
  void checkMemberComments(String filePath, List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // 检查公共属性
      // 跳过缩进的代码（方法内部）和私有成员
      if ((line.startsWith('final ') ||
              line.startsWith('var ') ||
              line.startsWith('late ')) &&
          !line.startsWith('_') &&
          !lines[i].startsWith('  ') &&
          !lines[i].startsWith('\t')) {
        bool hasValidComment = false;
        for (int j = i - 1; j >= 0; j--) {
          final commentLine = lines[j].trim();
          if (commentLine.isEmpty) continue;
          if (commentLine.startsWith('///')) {
            hasValidComment = true;
            validComments++;
            break;
          }
          // 跳过注解（如 @override），继续向上查找
          if (commentLine.startsWith('@')) {
            continue;
          }
          if (!commentLine.startsWith('///')) {
            break;
          }
        }
        if (!hasValidComment) {
          issues.add(
            LinterIssue(
              filePath: filePath,
              lineNumber: i + 1,
              issueType: 'Missing Member Comment',
              message: 'Public member should have a documentation comment',
            ),
          );
        }
      }

      // 检查方法
      // 方法定义的特征：
      // 1. 以返回类型开头（大写字母开头或特定关键字）
      // 2. 不是控制流语句
      // 3. 不在方法内部（不以缩进开头）
      bool isMethod =
          (line.startsWith('void ') ||
              line.startsWith('Future<') ||
              line.startsWith('Stream<') ||
              (line.isNotEmpty &&
                  line[0] == line[0].toUpperCase() &&
                  line.contains('(') &&
                  line.contains(')'))) &&
          !line.startsWith('if ') &&
          !line.startsWith('for ') &&
          !line.startsWith('while ') &&
          !line.startsWith('switch ') &&
          !line.startsWith('catch ') &&
          !lines[i].startsWith('  ') && // 跳过缩进的代码（方法内部）
          !lines[i].startsWith('\t');
      if (isMethod) {
        bool hasValidComment = false;
        for (int j = i - 1; j >= 0; j--) {
          final commentLine = lines[j].trim();
          if (commentLine.isEmpty) continue;
          if (commentLine.startsWith('///')) {
            hasValidComment = true;
            validComments++;
            break;
          }
          // 跳过注解（如 @override），继续向上查找
          if (commentLine.startsWith('@')) {
            continue;
          }
          if (!commentLine.startsWith('///')) {
            break;
          }
        }
        if (!hasValidComment) {
          issues.add(
            LinterIssue(
              filePath: filePath,
              lineNumber: i + 1,
              issueType: 'Missing Method Comment',
              message: 'Method should have a documentation comment',
            ),
          );
        }
      }
    }
  }

  // 检查注释格式
  void checkCommentFormatting(String filePath, List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // 跳过缩进的代码（方法内部），// 注释在方法内部是正常的代码注释
      if (lines[i].startsWith('  ') || lines[i].startsWith('\t')) {
        continue;
      }

      // 检查是否使用///而非//
      if (line.startsWith('// ') && !line.startsWith('///')) {
        issues.add(
          LinterIssue(
            filePath: filePath,
            lineNumber: i + 1,
            issueType: 'Comment Format',
            message: 'Use /// for documentation comments instead of //',
          ),
        );
      }

      // 检查类注释标题格式
      if (line.startsWith('/// # ') || line.startsWith('/// ## ')) {
        validComments++;
      }
    }
  }

  // 输出报告
  void printReport() {
    print('\n=== Flutter Comment Linter Report ===');
    print('Valid comments found: $validComments');
    print('Issues found: ${issues.length}');
    print('==================================');

    if (issues.isNotEmpty) {
      print('\nIssues:');
      for (final issue in issues) {
        print(issue);
      }
    } else {
      print('\nNo issues found! All comments are properly formatted.');
    }
  }
}

void main() {
  // 读取配置文件
  LinterConfig config = LinterConfig();
  final configFile = File('tool/lint/comment_linter_config.json');
  if (configFile.existsSync()) {
    final configJson = jsonDecode(configFile.readAsStringSync());
    config = LinterConfig.fromJson(configJson);
  }

  // 创建检查器
  final linter = CommentLinter(config);

  // 扫描lib目录
  linter.scanDirectory('lib');

  // 输出报告
  linter.printReport();
}
