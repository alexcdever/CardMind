/// # 卡片控制器
///
/// 负责卡片列表的状态管理和与后端 API 的交互编排。
///
/// ## 外部依赖
/// - 依赖 [CardApiClient] 提供后端调用能力。
library cards_controller;

import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/card_summary.dart';
import 'package:flutter/foundation.dart';

/// 卡片列表控制器。
///
/// 管理卡片列表的状态，提供加载、创建、保存、删除和恢复卡片的功能。
/// 继承自 [ChangeNotifier]，支持状态变更通知。
class CardsController extends ChangeNotifier {
  /// 创建卡片控制器。
  ///
  /// [apiClient] 用于与后端通信的 API 客户端。
  CardsController({required CardApiClient apiClient}) : _apiClient = apiClient;

  /// API 客户端。
  final CardApiClient _apiClient;

  /// 内部存储的卡片列表。
  List<CardSummary> _items = const <CardSummary>[];

  /// 获取当前卡片列表。
  List<CardSummary> get items => _items;

  /// 加载卡片列表。
  ///
  /// [query] 搜索关键词，默认为空字符串，表示加载所有卡片。
  Future<void> load({String query = ''}) async {
    _items = await _apiClient.listCardSummaries(query: query);
    notifyListeners();
  }

  /// 创建新卡片草稿。
  ///
  /// [id] 卡片 ID。
  /// [title] 卡片标题。
  /// [body] 卡片内容。
  ///
  /// 返回创建的卡片 ID。
  Future<String> createDraft(String id, String title, String body) async {
    final createdId = await _apiClient.createCardNote(
      id: id,
      title: title,
      body: body,
    );
    await load();
    return createdId;
  }

  /// 保存现有卡片。
  ///
  /// [id] 卡片 ID，必须非空。
  /// [title] 卡片标题。
  /// [body] 卡片内容。
  ///
  /// 如果 [id] 为 null，则抛出 [StateError]。
  Future<void> save(String? id, String title, String body) async {
    if (id == null) {
      throw StateError(
        'save requires an existing card id or explicit create path',
      );
    }
    await _apiClient.updateCardNote(id: id, title: title, body: body);
    await load();
  }

  /// 删除卡片。
  ///
  /// [id] 要删除的卡片 ID。
  Future<void> delete(String id) async {
    await _apiClient.deleteCardNote(id: id);
    await load();
  }

  /// 恢复已删除的卡片。
  ///
  /// [id] 要恢复的卡片 ID。
  Future<void> restore(String id) async {
    await _apiClient.restoreCardNote(id: id);
    await load();
  }

  /// 获取卡片详情。
  ///
  /// [id] 卡片 ID。
  ///
  /// 返回包含完整信息的 [CardDetailData]。
  Future<CardDetailData> getCardDetail(String id) {
    return _apiClient.getCardDetail(id: id);
  }
}
