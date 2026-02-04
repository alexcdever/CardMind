import 'package:cardmind/bridge/models/pool.dart';
import 'package:cardmind/bridge/third_party/cardmind_rust/api/device_config.dart'
    as device_api;
import 'package:cardmind/bridge/third_party/cardmind_rust/api/identity.dart'
    as identity_api;
import 'package:cardmind/bridge/third_party/cardmind_rust/api/pool.dart'
    as pool_api;
import 'package:flutter/foundation.dart';

/// PoolProvider manages the state of data pools
class PoolProvider extends ChangeNotifier {
  List<Pool> _joinedPools = [];
  List<String> _residentPools = [];
  bool _isLoading = false;
  String? _error;
  Pool? _currentPool;

  List<Pool> get joinedPools => _joinedPools;
  List<String> get residentPools => _residentPools;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  /// Check if user has joined any pool (single pool constraint)
  bool get isJoined => _currentPool != null;

  /// Get current pool ID if user has joined a pool
  String? get currentPoolId => _currentPool?.poolId;

  /// Get current pool if user has joined a pool
  Pool? get currentPool => _currentPool;

  /// Initialize the PoolStore
  Future<void> initialize(String storagePath) async {
    try {
      _setLoading(true);
      _clearError();
      await pool_api.initPoolStore(path: storagePath);
      await loadPools();
      await loadResidentPools();
    } on Exception catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Load all joined pools
  Future<void> loadPools() async {
    try {
      _setLoading(true);
      _clearError();
      _joinedPools = await pool_api.getAllPools();
      // Update current pool based on single pool constraint
      if (_joinedPools.isNotEmpty) {
        _currentPool = _joinedPools.first;
      } else {
        _currentPool = null;
      }
      notifyListeners();
    } on Exception catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Load resident pools
  Future<void> loadResidentPools() async {
    try {
      _clearError();
      _residentPools = await device_api.getResidentPools();
      notifyListeners();
    } on Exception catch (e) {
      _setError(e.toString());
    }
  }

  /// Create a new pool
  ///
  /// Returns the created pool if successful, null otherwise
  Future<Pool?> createPool(String name, String password) async {
    try {
      _clearError();
      final pool = await pool_api.createPool(name: name, password: password);
      await loadPools();
      return pool;
    } on Exception catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Join an existing pool
  ///
  /// Returns true if successful
  Future<bool> joinPool(String poolId, String password) async {
    try {
      _clearError();
      final success = await pool_api.verifyPoolPassword(
        poolId: poolId,
        password: password,
      );

      if (success) {
        final peerId = identity_api.getPeerId();
        await pool_api.addPoolMember(
          poolId: poolId,
          deviceId: peerId,
          deviceName: 'My Device',
        );
        await loadPools();
      }

      return success;
    } on Exception catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Leave a pool
  ///
  /// Returns true if successful
  Future<bool> leavePool(String poolId) async {
    try {
      _clearError();
      final peerId = identity_api.getPeerId();
      await pool_api.removePoolMember(poolId: poolId, deviceId: peerId);
      await loadPools();
      // Clear current pool after leaving
      if (_currentPool?.poolId == poolId) {
        _currentPool = null;
      }
      return true;
    } on Exception catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Update a pool
  ///
  /// Returns true if successful
  Future<bool> updatePool(String poolId, {String? name}) async {
    try {
      _clearError();
      if (name != null) {
        await pool_api.updatePool(poolId: poolId, name: name);
      }
      await loadPools();
      return true;
    } on Exception catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Delete a pool
  ///
  /// Returns true if successful
  Future<bool> deletePool(String poolId) async {
    try {
      _clearError();
      await pool_api.deletePool(poolId: poolId);
      await loadPools();
      return true;
    } on Exception catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Add pool to resident pools
  ///
  /// Returns true if successful
  Future<bool> addToResidentPools(String poolId) async {
    try {
      _clearError();
      await device_api.setResidentPool(poolId: poolId, isResident: true);
      _residentPools = await device_api.getResidentPools();
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Remove pool from resident pools
  ///
  /// Returns true if successful
  Future<bool> removeFromResidentPools(String poolId) async {
    try {
      _clearError();
      await device_api.setResidentPool(poolId: poolId, isResident: false);
      _residentPools = await device_api.getResidentPools();
      notifyListeners();
      return true;
    } on Exception catch (e) {
      _setError(e.toString());
      return false;
    }
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
