import 'dart:async';

import 'package:cardmind/bridge/third_party/cardmind_rust/api/sync.dart' as api;
import 'package:cardmind/models/sync_status.dart' as model;
import 'package:flutter/foundation.dart';

/// SyncProvider manages the state of P2P synchronization
///
/// 使用 Stream-based 架构，订阅 Rust 后端的同步状态流
class SyncProvider extends ChangeNotifier {
  model.SyncStatus _status = model.SyncStatus.notYetSynced();
  String? _localPeerId;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<api.SyncStatus>? _statusSubscription;
  Timer? _debounceTimer;

  model.SyncStatus get status => _status;
  String? get localPeerId => _localPeerId;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  /// Initialize the P2P sync service
  ///
  /// [storagePath] - Storage root directory path
  /// [listenAddr] - P2P listen address (e.g., "/ip4/0.0.0.0/tcp/0")
  Future<void> initialize(String storagePath, String listenAddr) async {
    try {
      _setLoading(true);
      _clearError();

      _localPeerId = await api.initSyncService(
        storagePath: storagePath,
        listenAddr: listenAddr,
      );
      _isInitialized = true;

      // 订阅同步状态流
      _subscribeToStatusStream();
    } on Exception catch (e) {
      _setError(e.toString());
      _isInitialized = false;
    } finally {
      _setLoading(false);
    }
  }

  /// 订阅同步状态流
  void _subscribeToStatusStream() {
    _statusSubscription?.cancel();
    _debounceTimer?.cancel();

    try {
      final stream = api.getSyncStatusStream();

      // 应用 Stream.distinct() 去重
      final distinctStream = stream.distinct((prev, next) {
        // 比较状态是否真正变化
        return prev.state == next.state &&
            prev.lastSyncTime == next.lastSyncTime &&
            prev.errorMessage == next.errorMessage;
      });

      _statusSubscription = distinctStream.listen(
        (apiStatus) {
          // syncing→synced 立即更新，其他状态防抖 300ms
          final shouldUpdateImmediately = apiStatus.state == api.SyncState.synced &&
              _status.state == model.SyncState.syncing;

          if (shouldUpdateImmediately) {
            _debounceTimer?.cancel();
            _updateStatus(apiStatus);
          } else {
            // 防抖：取消之前的定时器，设置新的 300ms 延迟
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
              _updateStatus(apiStatus);
            });
          }
        },
        onError: (error) {
          _setError(error.toString());
        },
      );
    } on Exception catch (e) {
      _setError('Failed to subscribe to status stream: ${e.toString()}');
    }
  }

  /// 更新状态并通知监听器
  void _updateStatus(api.SyncStatus apiStatus) {
    _status = _convertApiStatusToModel(apiStatus);
    notifyListeners();
  }

  /// 将 API SyncStatus 转换为 Model SyncStatus
  model.SyncStatus _convertApiStatusToModel(api.SyncStatus apiStatus) {
    switch (apiStatus.state) {
      case api.SyncState.notYetSynced:
        return model.SyncStatus.notYetSynced();
      case api.SyncState.syncing:
        final lastSyncTime = apiStatus.lastSyncTime != null
            ? DateTime.fromMillisecondsSinceEpoch(apiStatus.lastSyncTime!)
            : null;
        return model.SyncStatus.syncing(lastSyncTime: lastSyncTime);
      case api.SyncState.synced:
        final lastSyncTime = apiStatus.lastSyncTime != null
            ? DateTime.fromMillisecondsSinceEpoch(apiStatus.lastSyncTime!)
            : DateTime.now();
        return model.SyncStatus.synced(lastSyncTime: lastSyncTime);
      case api.SyncState.failed:
        final lastSyncTime = apiStatus.lastSyncTime != null
            ? DateTime.fromMillisecondsSinceEpoch(apiStatus.lastSyncTime!)
            : null;
        return model.SyncStatus.failed(
          errorMessage: apiStatus.errorMessage ?? 'Unknown error',
          lastSyncTime: lastSyncTime,
        );
    }
  }

  /// Manually sync a data pool
  ///
  /// [poolId] - The ID of the pool to sync
  ///
  /// Returns true if sync was initiated successfully
  Future<bool> syncPool(String poolId) async {
    if (!_isInitialized) {
      _setError('Sync service not initialized');
      return false;
    }

    try {
      _clearError();

      await api.syncPool(poolId: poolId);

      return true;
    } on Exception catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Get the local peer ID
  ///
  /// Returns the peer ID if service is initialized, null otherwise
  Future<String?> getLocalPeerId() async {
    if (!_isInitialized) return null;

    try {
      _clearError();

      return await api.getLocalPeerId();
    } on Exception catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Retry sync after failure
  Future<void> retrySync() async {
    if (!_isInitialized) {
      _setError('Sync service not initialized');
      return;
    }

    try {
      _clearError();
      await api.retrySync();
    } on Exception catch (e) {
      _setError(e.toString());
    }
  }

  /// Cleanup sync service
  ///
  /// Call this when disposing the provider or reinitializing
  void cleanup() {
    try {
      _clearError();

      // 取消订阅和定时器
      _statusSubscription?.cancel();
      _statusSubscription = null;
      _debounceTimer?.cancel();
      _debounceTimer = null;

      api.cleanupSyncService();

      _isInitialized = false;
      _localPeerId = null;
      _status = model.SyncStatus.notYetSynced();

      notifyListeners();
    } on Exception catch (e) {
      _setError(e.toString());
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _debounceTimer?.cancel();
    cleanup();
    super.dispose();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
