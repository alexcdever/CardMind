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

      // TODO: Uncomment when bridge code is generated
      // _localPeerId = await api.initSyncService(
      //   storagePath: storagePath,
      //   listenAddr: listenAddr,
      // );

      // Mock initialization for now
      _localPeerId = 'mock-peer-id-${DateTime.now().millisecondsSinceEpoch}';
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

      // TODO: Uncomment when bridge code is generated
      // final status = await api.getSyncStatus();
      // _onlineDevices = status.onlineDevices;
      // _syncingDevices = status.syncingDevices;
      // _offlineDevices = status.offlineDevices;

      // Mock status for now
      _onlineDevices = 0;
      _syncingDevices = 0;
      _offlineDevices = 0;

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

      // TODO: Uncomment when bridge code is generated
      // await api.syncPool(poolId: poolId);

      // Mock sync for now
      await Future<void>.delayed(const Duration(milliseconds: 500));

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

      // TODO: Uncomment when bridge code is generated
      // return await api.getLocalPeerId();

      // Mock peer ID for now
      return _localPeerId;
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

      // TODO: Uncomment when bridge code is generated
      // api.cleanupSyncService();

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
