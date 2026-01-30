import '../bridge/models/card.dart';

/// Card API Interface
///
/// 抽象接口，用于卡片 API 操作
/// 允许在测试中使用 mock 实现
abstract class CardApiInterface {
  /// 创建新卡片
  ///
  /// [title] - 卡片标题
  /// [content] - 卡片内容（Markdown 格式）
  ///
  /// 返回创建的卡片
  Future<Card> createCard({required String title, required String content});

  /// 更新卡片
  ///
  /// [id] - 卡片 ID
  /// [title] - 新标题（可选）
  /// [content] - 新内容（可选）
  Future<void> updateCard({required String id, String? title, String? content});

  /// 删除卡片（软删除）
  ///
  /// [id] - 卡片 ID
  Future<void> deleteCard({required String id});

  /// 根据 ID 获取卡片
  ///
  /// [id] - 卡片 ID
  ///
  /// 返回卡片，如果不存在则抛出异常
  Future<Card> getCardById({required String id});

  /// 获取所有活跃卡片（不包括已删除的）
  ///
  /// 返回卡片列表，按创建时间排序（最新的在前）
  Future<List<Card>> getActiveCards();

  /// 获取所有卡片（包括已删除的）
  ///
  /// 返回卡片列表，按创建时间排序（最新的在前）
  Future<List<Card>> getAllCards();
}
