import 'package:flutter/material.dart';

/// 搜索高亮文本组件
///
/// 用于在文本中高亮显示搜索关键词，支持自定义高亮样式和多个关键词匹配。
///
/// ## 功能特性
/// - 支持不区分大小写的关键词匹配
/// - 支持自定义高亮样式（背景色、字体颜色、字体粗细等）
/// - 支持多个关键词同时高亮
/// - 自动处理关键词重叠情况
///
/// ## 使用示例
/// ```dart
/// HighlightedText(
///   text: '这是一个示例文本，用于演示高亮功能',
///   highlight: '示例 高亮',
///   style: TextStyle(fontSize: 16),
///   highlightStyle: TextStyle(
///     backgroundColor: Colors.yellow,
///     fontWeight: FontWeight.bold,
///   ),
/// )
/// ```
///
/// ## 设计原理
/// - 使用正则表达式查找所有匹配项（不区分大小写）
/// - 将文本分割为多个 TextSpan，匹配项使用高亮样式
/// - 自动处理关键词在文本中的多个出现位置
class HighlightedText extends StatelessWidget {
  /// 创建搜索高亮文本组件
  ///
  /// [text] 要显示的完整文本
  /// [highlight] 要高亮的关键词（多个关键词用空格分隔）
  /// [style] 普通文本的样式（可选）
  /// [highlightStyle] 高亮文本的样式（可选，默认黄色背景+粗体）
  const HighlightedText({
    super.key,
    required this.text,
    required this.highlight,
    this.style,
    this.highlightStyle,
  });

  /// 要显示的完整文本
  final String text;

  /// 要高亮的关键词（多个关键词用空格分隔）
  final String highlight;

  /// 普通文本的样式
  final TextStyle? style;

  /// 高亮文本的样式
  final TextStyle? highlightStyle;

  /// 默认高亮样式（黄色背景 + 粗体）
  static const TextStyle _defaultHighlightStyle = TextStyle(
    backgroundColor: Colors.yellow,
    fontWeight: FontWeight.bold,
  );

  @override
  Widget build(BuildContext context) {
    // 如果没有关键词或关键词为空，直接显示原文
    if (highlight.isEmpty) {
      return Text(text, style: style);
    }

    // 构建富文本
    return RichText(text: _buildTextSpans());
  }

  /// 构建文本 span 列表
  ///
  /// 将文本分割为多个 TextSpan，匹配项使用高亮样式
  TextSpan _buildTextSpans() {
    // 将多个关键词分割为数组
    final keywords = highlight.split(' ').where((k) => k.isNotEmpty).toList();

    if (keywords.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    // 构建正则表达式模式（匹配任意一个关键词，不区分大小写）
    final pattern = _buildPattern(keywords);
    final regex = RegExp(pattern, caseSensitive: false);

    // 查找所有匹配项
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      // 没有匹配项，返回普通文本
      return TextSpan(text: text, style: style);
    }

    // 构建 TextSpan 列表
    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      // 添加匹配前的普通文本
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(text: text.substring(lastIndex, match.start), style: style),
        );
      }

      // 添加高亮文本
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: highlightStyle ?? _defaultHighlightStyle,
        ),
      );

      lastIndex = match.end;
    }

    // 添加最后一段普通文本
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: style));
    }

    // 合并为单个 TextSpan
    return TextSpan(children: spans, style: style);
  }

  /// 构建正则表达式模式
  ///
  /// 将多个关键词组合为一个正则表达式模式
  /// 例如：['示例', '高亮'] -> '(示例|高亮)'
  ///
  /// 对特殊字符进行转义，避免正则表达式语法错误
  String _buildPattern(List<String> keywords) {
    // 对每个关键词进行转义，然后使用 | 连接
    final escapedKeywords = keywords.map(RegExp.escape).join('|');

    return '($escapedKeywords)';
  }
}
