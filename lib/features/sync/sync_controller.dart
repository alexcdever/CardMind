// input: 接收 connect/retry/refresh 调用并依赖 SyncService 返回结果。
// output: 更新内部 SyncStatus 并 notifyListeners() 广播状态变化。
// pos: 同步流程控制器，负责调用服务层并驱动同步状态机。修改本文件需同步更新文件头与所属 DIR.md。
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
