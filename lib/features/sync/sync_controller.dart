/// # 同步控制器
///
/// 负责同步流程的控制和状态管理。
/// 调用服务层并驱动同步状态机。
///
/// ## 外部依赖
/// - 依赖 [SyncService] 提供同步业务逻辑。
/// - 依赖 [SyncStatus] 提供同步状态模型。
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/foundation.dart';

/// 同步流程控制器。
///
/// 通过 [ChangeNotifier] 模式管理同步状态，
/// 提供连接、重试、刷新等操作接口。
class SyncController extends ChangeNotifier {
  /// 创建同步控制器。
  ///
  /// [service] - 同步服务实例。
  /// [initial] - 初始同步状态，默认为空闲状态。
  SyncController({
    required this.service,
    SyncStatus initial = const SyncStatus.idle(),
  }) : _status = initial;

  /// 同步服务实例。
  final SyncService service;

  /// 当前同步状态。
  SyncStatus _status;

  /// 获取当前同步状态。
  SyncStatus get status => _status;

  /// 建立同步连接。
  Future<void> connect(String target) async {
    await _runWithConnecting(() => service.connect(target));
  }

  /// 重试同步操作。
  Future<void> retry() async {
    await _runWithConnecting(() => service.retry());
  }

  /// 重新建立同步连接。
  Future<void> reconnect(String target) async {
    await _runWithConnecting(() => service.reconnect(target));
  }

  /// 在连接状态下执行操作。
  Future<void> _runWithConnecting(Future<SyncStatus> Function() action) async {
    _status = const SyncStatus.connecting();
    notifyListeners();
    _status = await action();
    notifyListeners();
  }

  /// 刷新同步状态。
  Future<void> refresh() async {
    _status = await service.status();
    notifyListeners();
  }
}
