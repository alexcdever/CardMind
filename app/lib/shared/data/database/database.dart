// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// 定义卡片表的数据结构
@DataClassName('CardData')
class Cards extends Table {
  // 自增主键
  IntColumn get id => integer().autoIncrement()();
  // 卡片标题
  TextColumn get title => text()();
  // 卡片内容
  TextColumn get content => text()();
  // 创建时间
  DateTimeColumn get createdAt => dateTime()();
  // 更新时间
  DateTimeColumn get updatedAt => dateTime()();
}

// 数据库类，使用 drift ORM 框架
@DriftDatabase(tables: [Cards])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // 获取所有卡片，按创建时间倒序排列
  Future<List<CardData>> getAllCards() =>
      (select(cards)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  
  // 搜索卡片，支持标题和内容的模糊匹配
  Future<List<CardData>> searchCards(String query) {
    final queryLower = query.toLowerCase();
    final searchPattern = '%$queryLower%';
    return customSelect(
      'SELECT * FROM cards WHERE LOWER(title) LIKE ? OR LOWER(content) LIKE ? ORDER BY created_at DESC',
      variables: [Variable.withString(searchPattern), Variable.withString(searchPattern)],
      readsFrom: {cards},
    ).map((row) => CardData(
      id: row.read<int>('id'),
      title: row.read<String>('title'),
      content: row.read<String>('content'),
      createdAt: row.read<DateTime>('created_at'),
      updatedAt: row.read<DateTime>('updated_at'),
    )).get();
  }

  // 根据 ID 获取单个卡片
  Future<CardData> getCard(int id) =>
      (select(cards)..where((card) => card.id.equals(id)))
          .getSingle();

  // 插入新卡片
  Future<int> insertCard(CardsCompanion card) =>
      into(cards).insert(card);

  // 更新现有卡片
  Future<bool> updateCard(CardsCompanion card) =>
      update(cards).replace(card);

  // 删除卡片
  Future<int> deleteCard(int id) =>
      (delete(cards)..where((card) => card.id.equals(id)))
          .go();
}

// 创建数据库连接
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // 获取应用文档目录
    final dbFolder = await getApplicationDocumentsDirectory();
    // 创建数据库文件
    final file = File(p.join(dbFolder.path, 'cardmind.db'));
    // 返回数据库连接
    return NativeDatabase.createInBackground(file);
  });
}
