// input: 接收卡片 ApiClient，执行 load/create/delete/restore 命令。
// output: 基于 Rust Query API 返回的列表更新 items，并在动作完成后刷新查询结果。
// pos: 卡片列表控制器，负责编排卡片查询刷新与后端动作调用。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/card_summary.dart';
import 'package:flutter/foundation.dart';

class CardsController extends ChangeNotifier {
  CardsController({required CardApiClient apiClient}) : _apiClient = apiClient;

  final CardApiClient _apiClient;

  List<CardSummary> _items = const <CardSummary>[];
  List<CardSummary> get items => _items;

  Future<void> load({String query = ''}) async {
    _items = await _apiClient.listCardSummaries(
      query: query,
      includeDeleted: query.isEmpty,
    );
    notifyListeners();
  }

  Future<void> create(String id, String title, String body) async {
    await _apiClient.createCardNote(id: id, title: title, body: body);
    await load();
  }

  Future<void> delete(String id) async {
    await _apiClient.deleteCardNote(id: id);
    await load();
  }

  Future<void> restore(String id) async {
    await _apiClient.restoreCardNote(id: id);
    await load();
  }
}
