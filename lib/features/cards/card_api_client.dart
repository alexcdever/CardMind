/// # 卡片 API 客户端
///
/// 提供卡片操作的 API 客户端抽象和实现。
///
/// ## 外部依赖
/// - 依赖 [frb] 提供的 Rust FFI 桥接 API。
library card_api_client;

import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/features/cards/card_summary.dart';

/// 卡片 API 客户端抽象类。
///
/// 定义卡片操作的接口，包括创建、更新、删除、恢复和查询。
abstract class CardApiClient {
  /// 创建卡片笔记。
  ///
  /// [id] - 卡片标识。
  /// [title] - 卡片标题。
  /// [body] - 卡片正文。
  /// [poolId] - 可选的数据池标识。
  Future<String> createCardNote({
    required String id,
    required String title,
    required String body,
    String? poolId,
  });

  /// 更新卡片笔记。
  ///
  /// [id] - 卡片标识。
  /// [title] - 新的标题。
  /// [body] - 新的正文。
  Future<void> updateCardNote({
    required String id,
    required String title,
    required String body,
  });

  /// 软删除卡片笔记。
  ///
  /// [id] - 要删除的卡片标识。
  Future<void> deleteCardNote({required String id});

  /// 恢复已软删除的卡片笔记。
  ///
  /// [id] - 要恢复的卡片标识。
  Future<void> restoreCardNote({required String id});

  /// 获取卡片详情。
  ///
  /// [id] - 卡片标识。
  Future<CardDetailData> getCardDetail({required String id});

  /// 获取卡片摘要列表。
  ///
  /// [query] - 搜索查询字符串。
  /// [poolId] - 可选的数据池标识。
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
  });
}

/// 卡片详情数据。
///
/// 包含卡片的完整信息。
class CardDetailData {
  /// 创建卡片详情数据。
  ///
  /// [id] 卡片 ID。
  /// [title] 卡片标题。
  /// [body] 卡片内容。
  /// [deleted] 是否已删除。
  const CardDetailData({
    required this.id,
    required this.title,
    required this.body,
    required this.deleted,
  });

  /// 卡片 ID。
  final String id;

  /// 卡片标题。
  final String title;

  /// 卡片内容。
  final String body;

  /// 是否已删除。
  final bool deleted;
}

/// 通过 Rust FRB 桥接的卡片 API 客户端实现。
///
/// 通过 Flutter Rust Bridge 与 Rust 后端通信。
class FrbCardApiClient implements CardApiClient {
  /// 创建 FRB 卡片 API 客户端。
  const FrbCardApiClient();

  @override
  Future<String> createCardNote({
    required String id,
    required String title,
    required String body,
    String? poolId,
  }) async {
    final dto = poolId == null
        ? await frb.createCardNote(title: title, content: body)
        : await frb.createCardNoteInPool(
            poolId: poolId,
            title: title,
            content: body,
          );
    return dto.id;
  }

  @override
  Future<void> updateCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    await frb.updateCardNote(cardId: id, title: title, content: body);
  }

  @override
  Future<void> deleteCardNote({required String id}) async {
    await frb.deleteCardNote(cardId: id);
  }

  @override
  Future<void> restoreCardNote({required String id}) async {
    await frb.restoreCardNote(cardId: id);
  }

  @override
  Future<CardDetailData> getCardDetail({required String id}) async {
    final dto = await frb.getCardNoteDetail(cardId: id);
    return CardDetailData(
      id: dto.id,
      title: dto.title,
      body: dto.content,
      deleted: dto.deleted,
    );
  }

  @override
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
  }) async {
    final notes = await frb.queryCardNotes(
      query: query,
      poolId: poolId,
      includeDeleted: false,
    );
    return notes
        .map(
          (note) => CardSummary(
            id: note.id,
            title: note.title,
            deleted: note.deleted,
          ),
        )
        .toList(growable: false);
  }
}
