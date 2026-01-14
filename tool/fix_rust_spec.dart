import 'dart:io';

void main() {
  final file = File('rust/examples/single_pool_flow_spec.rs');
  if (!file.existsSync()) {
    stderr.writeln(
      'Error: File not found: rust/examples/single_pool_flow_spec.rs',
    );
    exit(1);
  }

  String content = file.readAsStringSync();

  // 逐行处理，修复所有问题
  final lines = content.split('\n');
  final fixedLines = <String>[];

  for (String line in lines) {
    String fixedLine = line;

    // 1. 修复println!宏开头的换行符问题
    // 将 println!("\n[ 改为 println!("
    if (fixedLine.contains('println!("\\n') &&
        !fixedLine.contains('println!("\\n\\"')) {
      fixedLine = fixedLine.replaceAll('println!("\\n', 'println!("');
    }

    // 2. 移除或替换所有中文字符和特殊符号
    fixedLine = fixedLine
        .replaceAll('✅', '[OK]')
        .replaceAll('📋', '[SCENARIO]')
        .replaceAll('✓', '[CHECK]')
        .replaceAll('！', '!')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('：', ':')
        .replaceAll('，', ',')
        .replaceAll('；', ';')
        .replaceAll('的笔记', ' Notes')
        .replaceAll('新设备，未初始化', 'new device, uninitialized')
        .replaceAll('初始化(创建新池)', 'initialize (create new pool)')
        .replaceAll('池创建成功', 'pool created successfully')
        .replaceAll('成功加入', 'joined successfully')
        .replaceAll('所有规格场景', 'all spec scenarios');

    // 3. 对类似 "B" 结尾的字符串，确保前面有空格或正确闭合
    // 修复后: println!("Spec: ...-B "); 而不是 println!("Spec: ...-B");
    if (fixedLine.contains('println!("Spec: SP-') &&
        fixedLine.endsWith('-B");')) {
      fixedLine = '${fixedLine.substring(0, fixedLine.length - 3)} ");';
    }
    if (fixedLine.contains('println!("Spec: SP-') &&
        fixedLine.endsWith('-C");')) {
      fixedLine = '${fixedLine.substring(0, fixedLine.length - 3)} ");';
    }
    if (fixedLine.contains('println!("Spec: SP-') &&
        fixedLine.endsWith('-A");')) {
      fixedLine = '${fixedLine.substring(0, fixedLine.length - 3)} ");';
    }

    // 4. 修复variable/identifier后缺少空格的问题
    // 例如: "pool"); => " pool");
    if (fixedLine.contains(
      'println!("  [CHECK] Device not joined any pool")',
    )) {
      fixedLine = fixedLine.replaceAll('any pool");', 'any pool");');
      // 这已经正确了
    }

    // 5. 如果行包含中文注释，删除注释部分保留结构
    if (fixedLine.trim().startsWith('// ') && _hasChinese(fixedLine)) {
      // 保留//但移除中文
      fixedLine = fixedLine.replaceAll(RegExp(r'// .*'), '//');
    }

    // 6. 如果整行都是中文注释，转换为英文或空白注释
    if (_isAllChinese(fixedLine)) {
      fixedLine = '// TODO: Translated comment';
    }

    fixedLines.add(fixedLine);
  }

  file.writeAsStringSync(fixedLines.join('\n'));
  stdout.writeln('✓ Fixed spec file: rust/examples/single_pool_flow_spec.rs');
}

bool _hasChinese(String line) {
  return RegExp(r'[\u4e00-\u9fa5]').hasMatch(line);
}

bool _isAllChinese(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('//')) return false;
  final afterComment = trimmed.substring(2).trim();
  if (afterComment.isEmpty) return false;
  // 简化为只检查是否包含中文字符
  return RegExp(r'[\u4e00-\u9fa5]').hasMatch(afterComment);
}
