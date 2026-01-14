import 'dart:io';

void main() {
  final file = File('rust/examples/single_pool_flow_spec.rs');
  if (!file.existsSync()) {
    stderr.writeln('Error: File not found');
    exit(1);
  }

  String content = file.readAsStringSync();

  // 一次性替换所有模式
  content = content
      // 修复所有 ");" 模式为 " );"
      .replaceAllMapped(
        RegExp(r'([a-zA-Z]+)";'),
        (Match m) => '${m.group(1)} ");',
      )
      // 替换所有中文字符串为英文注释
      .replaceAll('新设备未加入', 'New device not joined')
      .replaceAll('加入成功', 'Joined successfully')
      .replaceAll('池中有', 'Pool has')
      .replaceAll('张卡片', 'cards')
      .replaceAll('个成员', 'members')
      .replaceAll('两台设备加入同一池', 'Two devices joined same pool')
      .replaceAll('可访问池内', 'Can access')
      .replaceAll('移除', 'removed')
      .replaceAll('自动收到更新', 'Automatically received update')
      .replaceAll(
        '完美解决旧模型的移除传播问题',
        'Perfectly solved removal propagation in old model',
      )
      .replaceAll('退出笔记空间时清空所有数据', 'Clear all data when leaving pool')
      .replaceAll('设备在', 'Device in')
      .replaceAll('删除所有卡片 Loro 文档', 'Deleted all card Loro docs')
      .replaceAll('删除 Pool 文档', 'Deleted Pool doc')
      .replaceAll('清空 SQLite 卡片表', 'Cleared SQLite cards table')
      .replaceAll('清空 SQLite 绑定表', 'Cleared SQLite bindings table')
      .replaceAll('删除密码', 'Deleted password')
      .replaceAll('数据清理完成', 'Data cleanup complete')
      .replaceAll('所有集成测试通过', 'All integration tests passed')
      // 移除全角符号
      .replaceAll('！', '!')
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll('：', ':')
      .replaceAll('，', ',')
      .replaceAll('；', ';')
      // 修复中文注释
      .replaceAll(
        RegExp(r'// .*[\u4e00-\u9fa5].*'),
        '// TODO: Translated comment',
      );

  file.writeAsStringSync(content);
  stdout.writeln('✓ Fixed all string and Chinese issues');
}
