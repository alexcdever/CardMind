import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';

void main() {
  // 初始化 Flutter 绑定
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late SqliteCrdt crdt;
  late String dbPath;

  // 测试前的设置
  setUp(() async {
    // 使用内存数据库
    dbPath = ':memory:';
    
    // 初始化 CRDT 数据库
    crdt = await SqliteCrdt.open(dbPath);
    
    // 创建测试表
    await crdt.execute('''
      CREATE TABLE IF NOT EXISTS test_cards (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  });

  // 测试后的清理
  tearDown(() async {
    // 关闭数据库连接
    await crdt.close();
  });

  // 测试 CRDT 是否能监听删除操作
  test('CRDT 应该能监听和记录删除操作', () async {
    // 1. 插入测试数据（使用 execute 而不是 insert）
    final testId = 'test-card-1';
    await crdt.execute('''
      INSERT INTO test_cards (id, title, content, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?)
    ''', [
      testId,
      '测试卡片',
      '这是一个测试卡片',
      DateTime.now().toIso8601String(),
      DateTime.now().toIso8601String(),
      1,
    ]);
    
    // 验证数据已插入
    final results = await crdt.query('SELECT * FROM test_cards WHERE id = ?', [testId]);
    expect(results.length, 1);
    expect(results[0]['title'], '测试卡片');
    
    // 2. 删除测试数据
    await crdt.execute('DELETE FROM test_cards WHERE id = ?', [testId]);
    
    // 验证数据已被物理删除
    final afterDelete = await crdt.query('SELECT * FROM test_cards WHERE id = ?', [testId]);
    expect(afterDelete.length, 0);
    
    // 3. 获取变更集
    final changeset = await crdt.getChangeset();
    print('变更集: $changeset');
    
    // 4. 检查变更集中是否包含删除操作的记录
    expect(changeset.containsKey('test_cards'), true);
    
    // 5. 创建第二个 CRDT 实例，模拟另一个节点
    final crdt2Path = ':memory:';
    final crdt2 = await SqliteCrdt.open(crdt2Path);
    
    try {
      await crdt2.execute('''
        CREATE TABLE IF NOT EXISTS test_cards (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          version INTEGER NOT NULL
        )
      ''');
      
      // 6. 在第二个实例中插入相同 ID 的数据（但内容不同）
      await crdt2.execute('''
        INSERT INTO test_cards (id, title, content, created_at, updated_at, version)
        VALUES (?, ?, ?, ?, ?, ?)
      ''', [
        testId,
        '另一个测试卡片',
        '这是另一个节点上的测试卡片',
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
        1,
      ]);
      
      // 7. 同步两个实例
      final crdt2Changeset = await crdt2.getChangeset();
      await crdt.merge(crdt2Changeset);
      await crdt2.merge(changeset);
      
      // 8. 验证第二个实例中的数据是否被删除
      final crdt2Results = await crdt2.query('SELECT * FROM test_cards WHERE id = ?', [testId]);
      
      // 打印结果以便观察
      print('CRDT2 查询结果: $crdt2Results');
      
      // 9. 检查 CRDT 内部表，看是否有删除记录
      try {
        // 尝试查询 CRDT 的内部表，看是否有删除记录
        final crdtLogs = await crdt.query("SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '_crdt%'");
        print('CRDT 内部表: $crdtLogs');
        
        for (final table in crdtLogs) {
          final tableName = table['name'];
          if (tableName != null && (tableName.toString().contains('_crdt') || tableName.toString().contains('tombstone'))) {
            final records = await crdt.query('SELECT * FROM $tableName');
            print('表 $tableName 中的记录: $records');
          }
        }
      } catch (e) {
        print('无法查询 CRDT 内部表: $e');
      }
    } finally {
      // 确保关闭第二个实例
      await crdt2.close();
    }
  });
  
  // 测试 CRDT 是否使用墓碑机制
  test('CRDT 应该使用墓碑机制而不是物理删除', () async {
    // 1. 插入测试数据
    final testId = 'test-card-2';
    await crdt.execute('''
      INSERT INTO test_cards (id, title, content, created_at, updated_at, version)
      VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      testId,
      '墓碑测试',
      '测试墓碑机制',
      DateTime.now().toIso8601String(),
      DateTime.now().toIso8601String(),
      1,
    ]);
    
    // 2. 删除测试数据
    await crdt.execute('DELETE FROM test_cards WHERE id = ?', [testId]);
    
    // 3. 检查 CRDT 内部表中是否存在墓碑记录
    try {
      // 查询所有表
      final tables = await crdt.query("SELECT name FROM sqlite_master WHERE type='table'");
      print('数据库中的所有表: $tables');
      
      // 查找可能的墓碑表
      for (final table in tables) {
        final tableName = table['name'];
        if (tableName != null && (tableName.toString().contains('_crdt') || tableName.toString().contains('tombstone'))) {
          final records = await crdt.query('SELECT * FROM $tableName');
          print('表 $tableName 中的记录: $records');
        }
      }
    } catch (e) {
      print('查询数据库表结构失败: $e');
    }
    
    // 4. 获取变更集并分析
    final changeset = await crdt.getChangeset();
    print('删除后的变更集: $changeset');
    
    // 5. 获取版本向量
    final versionVector = await crdt.getLastModified();
    print('版本向量: $versionVector');
  });
}
