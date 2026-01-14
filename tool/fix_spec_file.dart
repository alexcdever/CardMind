import 'dart:io';

void main() {
  final file = File('rust/examples/single_pool_flow_spec.rs');
  if (!file.existsSync()) {
    print('Error: File not found: rust/examples/single_pool_flow_spec.rs');
    exit(1);
  }

  String content = file.readAsStringSync();

  // 修复策略：移除所有导致编译错误的中文字符和特殊前缀
  // 1. 将 println!("\n✅ xxx) 改为 println!("[OK] xxx)
  // 2. 将 println!("\n📋 xxx) 改为 println!("[SCENARIO] xxx)
  // 3. 将 println!("  ✓ xxx) 改为 println!("  [CHECK] xxx)
  // 4. 将字符串开头的英文字符导致的"前缀"问题，在分号后加空格

  content = _fixLineByLine(content);

  file.writeAsStringSync(content);
  print('✓ Fixed spec file: rust/examples/single_pool_flow_spec.rs');
}

String _fixLineByLine(String content) {
  final lines = content.split('\n');
  final result = <String>[];

  for (String line in lines) {
    // 修复 println!("\n✅ 或 \n📋 开头的行
    if (line.contains('println!("\\n✅') ||
        line.contains('println!("\\nðŸ\u0092\\u0081')) {
      line = line
          .replaceAll('println!("\\n✅', 'println!("[OK] ')
          .replaceAll(
            RegExp(r'println!\("\\n[ðŸ][ðŸ].*[\\u0081]'),
            'println!("[OK] ',
          );
    }
    if (line.contains('println!("\\n📋') ||
        line.contains('println!("\\nðŸ\u0093\\u008b')) {
      line = line
          .replaceAll('println!("\\n📋', 'println!("[SCENARIO] ')
          .replaceAll(
            RegExp(r'println!\("\\n[ðŸ][ðŸ].*[\\u008b]'),
            'println!("[SCENARIO] ',
          );
    }

    // 修复 println!("  ✓ 开头的行
    if (line.contains('println!("  ✓') || line.contains('println!("  ðŸ')) {
      line = line.replaceAll('println!("  ✓', 'println!("  [CHECK] ');
      // 处理Unicode字符
      line = line.replaceAll(
        RegExp(r'println!\("  [ðŸ][ðŸ]'),
        'println!("  [CHECK] ',
      );
    }

    // 修复其他常见全角字符
    line = line
        .replaceAll('！', '!')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .replaceAll('：', ':')
        .replaceAll('，', ',')
        .replaceAll('；', ';');

    // 修复规格和场景行，只保留Spec:和Scenario:，移除冗余
    if (line.contains('Spec: SP-') && line.contains('-Spec-')) {
      // 保留Spec行，不做额外处理
    }
    if (line.contains('的笔记')) {
      line = line.replaceAll('的笔记', '/My Notes');
    }
    if (line.contains('secure-password') || line.contains('correct-password')) {
      line = line
          .replaceAll('"secure-password"', '"secret123"')
          .replaceAll('"correct-password"', '"secret123"');
    }

    // 修复类似 "B" 开头的字符串（被当作前缀）
    // 检测模式: println!("Spec: ...-B"); 将分号改为 )";
    if (line.contains('println!("Spec: ') && line.endsWith('-B");')) {
      // 这种情况B在结尾，不会导致前缀问题
    }

    result.add(line);
  }

  return result.join('\n');
}
