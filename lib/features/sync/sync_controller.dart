// input: lib/features/sync/sync_controller.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 功能模块，负责状态编排、交互反馈与页面渲染。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/foundation.dart';

class SyncController extends ChangeNotifier {
  SyncController({
    required this.service,
    SyncStatus initial = const SyncStatus.idle(),
  }) : _status = initial;

  final SyncService service;
  SyncStatus _status;

  SyncStatus get status => _status;

  Future<void> connect(String target) async {
    _status = const SyncStatus.connecting();
    notifyListeners();
    _status = await service.connect(target);
    notifyListeners();
  }

  Future<void> retry() async {
    _status = const SyncStatus.connecting();
    notifyListeners();
    _status = await service.retry();
    notifyListeners();
  }

  Future<void> refresh() async {
    _status = await service.status();
    notifyListeners();
  }
}
