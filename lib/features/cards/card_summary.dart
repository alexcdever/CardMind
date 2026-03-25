/// # 卡片摘要
///
/// 卡片列表展示的数据模型，包含卡片的基本信息。
///
/// ## 用途
/// - 用于卡片列表展示，避免加载完整卡片内容。
/// - 支持软删除标记。
library card_summary;

/// 卡片摘要数据类。
///
/// 不可变对象，用于卡片列表展示，只包含卡片的基本信息（ID、标题、删除状态）。
class CardSummary {
  /// 创建卡片摘要。
  ///
  /// [id] 卡片唯一标识符。
  /// [title] 卡片标题。
  /// [deleted] 是否已删除。
  const CardSummary({
    required this.id,
    required this.title,
    required this.deleted,
  });

  /// 卡片唯一标识符。
  final String id;

  /// 卡片标题。
  final String title;

  /// 是否已删除（软删除标记）。
  final bool deleted;
}
