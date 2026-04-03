import 'dart:io';
import 'dart:convert';

/// Rust代码注释检查配置类
class RustLinterConfig {
  final bool checkModuleComments;
  final bool checkStructComments;
  final bool checkFunctionComments;
  final bool checkFormatting;
  final List<String> excludePaths;

  RustLinterConfig({
    this.checkModuleComments = true,
    this.checkStructComments = true,
    this.checkFunctionComments = true,
    this.checkFormatting = true,
    this.excludePaths = const [],
  });

  factory RustLinterConfig.fromJson(Map<String, dynamic> json) {
    return RustLinterConfig(
      checkModuleComments: json['checkModuleComments'] ?? true,
      checkStructComments: json['checkStructComments'] ?? true,
      checkFunctionComments: json['checkFunctionComments'] ?? true,
      checkFormatting: json['checkFormatting'] ?? true,
      excludePaths: List<String>.from(json['excludePaths'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkModuleComments': checkModuleComments,
      'checkStructComments': checkStructComments,
      'checkFunctionComments': checkFunctionComments,
      'checkFormatting': checkFormatting,
      'excludePaths': excludePaths,
    };
  }
}

/// Rust注释检查问题类
class RustLinterIssue {
  final String filePath;
  final int lineNumber;
  final String issueType;
  final String message;

  RustLinterIssue({
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

/// Rust代码注释检查器
class RustCommentLinter {
  final RustLinterConfig config;
  final List<RustLinterIssue> issues = [];
  int validComments = 0;

  RustCommentLinter(this.config);

  /// 扫描目录
  void scanDirectory(String directoryPath) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      stderr.writeln('Directory not found: $directoryPath');
      return;
    }

    final files = directory.listSync(recursive: true, followLinks: false);
    for (final file in files) {
      if (file is File && file.path.endsWith('.rs')) {
        /// 检查是否在排除路径中
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

  /// 检查文件
  void checkFile(String filePath) {
    final file = File(filePath);
    final lines = file.readAsLinesSync();

    /// 检查模块注释
    if (config.checkModuleComments) {
      checkModuleComments(filePath, lines);
    }

    /// 检查结构体注释
    if (config.checkStructComments) {
      checkStructComments(filePath, lines);
    }

    /// 检查函数注释
    if (config.checkFunctionComments) {
      checkFunctionComments(filePath, lines);
    }

    /// 检查注释格式
    if (config.checkFormatting) {
      checkCommentFormatting(filePath, lines);
    }
  }

  /// 检查模块注释
  void checkModuleComments(String filePath, List<String> lines) {
    /// 检查文件开头的模块注释
    bool hasModuleComment = false;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('//! # ')) {
        hasModuleComment = true;
        validComments++;
        break;
      }
      if (!line.startsWith('//!') && line.isNotEmpty) {
        break;
      }
    }
    if (!hasModuleComment) {
      issues.add(
        RustLinterIssue(
          filePath: filePath,
          lineNumber: 1,
          issueType: 'Missing Module Comment',
          message:
              'Module should have a valid documentation comment with //! # title',
        ),
      );
    }
  }

  /// 检查结构体注释
  void checkStructComments(String filePath, List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('pub struct ') || line.startsWith('struct ')) {
        /// 检查结构体注释
        bool hasValidComment = false;
        for (int j = i - 1; j >= 0; j--) {
          final commentLine = lines[j].trim();
          if (commentLine.isEmpty) continue;
          if (commentLine.startsWith('///')) {
            hasValidComment = true;
            validComments++;
            break;
          }

          /// 跳过属性宏（如 #[derive(...)]），继续向上查找
          if (commentLine.startsWith('#[')) {
            continue;
          }

          /// 遇到非注释、非属性的行，停止查找
          break;
        }
        if (!hasValidComment) {
          issues.add(
            RustLinterIssue(
              filePath: filePath,
              lineNumber: i + 1,
              issueType: 'Missing Struct Comment',
              message: 'Struct should have a documentation comment',
            ),
          );
        }
      }
    }
  }

  /// 检查函数注释
  void checkFunctionComments(String filePath, List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      /// 检查函数定义（排除闭包和异步块中的代码）
      if ((line.startsWith('pub fn ') || line.startsWith('fn ')) &&
          line.contains('(') &&
          line.contains(')') &&
          !line.contains('= ') &&
          /// 排除变量赋值中的闭包
          !line.contains('async fn') &&
          /// 暂时排除async fn，因为可能误判
          !line.contains('-> impl ')) {
        /// 排除返回impl的函数
        /// 检查函数注释
        bool hasValidComment = false;
        bool isTestFunction = false;
        for (int j = i - 1; j >= 0; j--) {
          final commentLine = lines[j].trim();
          if (commentLine.isEmpty) continue;
          if (commentLine.startsWith('///')) {
            hasValidComment = true;
            validComments++;
            break;
          }

          /// 跳过属性宏（如 #[inline]、#[must_use] 等），继续向上查找
          if (commentLine.startsWith('#[')) {
            /// 检查是否是测试函数
            if (commentLine.startsWith('#[test')) {
              isTestFunction = true;
              break;
            }
            continue;
          }

          /// 遇到非注释、非属性的行，停止查找
          break;
        }

        /// 跳过测试函数
        if (isTestFunction) {
          continue;
        }
        if (!hasValidComment) {
          issues.add(
            RustLinterIssue(
              filePath: filePath,
              lineNumber: i + 1,
              issueType: 'Missing Function Comment',
              message: 'Function should have a documentation comment',
            ),
          );
        }
      }
    }
  }

  /// 检查注释格式
  void checkCommentFormatting(String filePath, List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      /// 检查模块注释格式
      if (line.startsWith('//! # ') || line.startsWith('//! ## ')) {
        validComments++;
      }

      /// 检查函数注释格式
      if (line.startsWith('/// # ')) {
        validComments++;
      }
    }
  }

  /// 输出报告
  void printReport() {
    stdout.writeln('\n=== Rust Comment Linter Report ===');
    stdout.writeln('Valid comments found: $validComments');
    stdout.writeln('Issues found: ${issues.length}');
    stdout.writeln('==================================');

    if (issues.isNotEmpty) {
      stdout.writeln('\nIssues:');
      for (final issue in issues) {
        stdout.writeln(issue);
      }
    } else {
      stdout.writeln('\nNo issues found! All comments are properly formatted.');
    }
  }
}

/// 主函数
void main() {
  /// 读取配置文件
  RustLinterConfig config = RustLinterConfig();
  final configFile = File('tool/lint/rust_comment_linter_config.json');
  if (configFile.existsSync()) {
    final configJson = jsonDecode(configFile.readAsStringSync());
    config = RustLinterConfig.fromJson(configJson);
  }

  /// 创建检查器
  final linter = RustCommentLinter(config);

  /// 扫描rust目录
  linter.scanDirectory('rust');

  /// 输出报告
  linter.printReport();
}
