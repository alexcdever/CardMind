import 'package:cardmind/bridge/third_party/cardmind_rust/api/sync.dart' as api;
import 'package:flutter/foundation.dart';

/// SyncProvider manages the state of P2P synchronization
class SyncProvider extends ChangeNotifier {
  int _onlineDevices = 0;
  int _syncingDevices = 0;
  int _offlineDevices = 0;
  String? _localPeerId;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  int get onlineDevices => _onlineDevices;
  int get syncingDevices => _syncingDevices;
  int get offlineDevices => _offlineDevices;
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

      await refreshStatus();
    } on Exception catch (e) {
      _setError(e.toString());
      _isInitialized = false;
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh sync status from the service
  Future<void> refreshStatus() async {
    if (!_isInitialized) return;

    try {
      _clearError();

      final status = await api.getSyncStatus();
      _onlineDevices = status.onlineDevices;
      _syncingDevices = status.syncingDevices;
      _offlineDevices = status.offlineDevices;

      notifyListeners();
    } on Exception catch (e) {
      _setError(e.toString());
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

      await refreshStatus();
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

  /// Cleanup sync service
  ///
  /// Call this when disposing the provider or reinitializing
  void cleanup() {
    try {
      _clearError();

      api.cleanupSyncService();

      _isInitialized = false;
      _localPeerId = null;
      _onlineDevices = 0;
      _syncingDevices = 0;
      _offlineDevices = 0;

      notifyListeners();
    } on Exception catch (e) {
      _setError(e.toString());
    }
  }

  @override
  void dispose() {
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
