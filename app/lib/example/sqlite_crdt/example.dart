import 'package:sqlite_crdt/sqlite_crdt.dart';

Future<void> main() async {
  // 创建或加载数据库
  final crdt = await SqliteCrdt.openInMemory(
    version: 1,
    onCreate: (db, version) async {
      // 创建表
      await db.execute('''
        CREATE TABLE users (
          id INTEGER NOT NULL,
          name TEXT,
          PRIMARY KEY (id)
        )
      ''');
    },
  );

  // 向数据库插入一条记录
  await crdt.execute('''
    INSERT INTO users (id, name)
    VALUES (?1, ?2)
  ''', [1, 'John Doe']);

  // 删除记录
  await crdt.execute('DELETE FROM users WHERE id = ?1', [1]);

  // 合并远程数据集
  await crdt.merge({
    'users': [
      {
        'id': 2,
        'name': 'Jane Doe',
        'hlc': Hlc.now(generateNodeId()),
      },
    ],
  });

  // 查询是简单的SQL语句，但需要注意：
  // 1. CRDT列：hlc、modified、is_deleted
  // 2. Doe先生会出现在结果中且is_deleted=1
  final result = await crdt.query('SELECT * FROM users');
  printRecords('SELECT * FROM users', result);

  // 更好的查询可能是
  final betterResult =
      await crdt.query('SELECT id, name FROM users WHERE is_deleted = 0');
  printRecords('SELECT id, name FROM users WHERE is_deleted = 0', betterResult);

  // 也可以监听特定查询结果，但请注意
  // 这可能会影响性能，因为每次数据库变更都会重新执行监听查询
  crdt.watch('SELECT id, name FROM users WHERE is_deleted = 0').listen((e) =>
      printRecords(
          'Watch: SELECT id, name FROM users WHERE is_deleted = 0', e));

  // 更新数据库
  await crdt.execute('''
    UPDATE users SET name = ?1
    WHERE id = ?2
  ''', ['Jane Doe 👍', 2]);

  // 因为记录只是被标记为删除，撤销删除很简单
  await crdt.execute('''
    UPDATE users SET is_deleted = ?1
    WHERE id = ?2
  ''', [1, 1]);

  // 在事务中执行多个写入操作，使它们具有相同的时间戳
  await crdt.transaction((txn) async {
    // 确保使用事务对象(txn)
    // 在此处使用[crdt]会导致死锁
    await txn.execute('''
      INSERT INTO users (id, name)
      VALUES (?1, ?2)
    ''', [3, 'Uncle Doe']);
    await txn.execute('''
      INSERT INTO users (id, name)
      VALUES (?1, ?2)
    ''', [4, 'Grandma Doe']);
  });
  final timestamps =
      await crdt.query('SELECT id, hlc, modified FROM users WHERE id > 2');
  printRecords('SELECT id, hlc, modified FROM users WHERE id > 2', timestamps);

  // 创建变更集以与其他节点同步
  final changeset = await crdt.getChangeset();
  print('> Changeset size: ${changeset.recordCount} records');
  changeset.forEach((key, value) {
    print(key);
    for (var e in value) {
      print('  $e');
    }
  });
}

void printRecords(String title, List<Map<String, Object?>> records) {
  print('> $title');
  records.forEach(print);
}
