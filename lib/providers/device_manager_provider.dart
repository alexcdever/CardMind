import 'package:flutter/foundation.dart';
import 'package:cardmind/models/device.dart';
import 'package:cardmind/models/pairing_request.dart';

// ============================================================================
// Page State Management
// ============================================================================

/// Page state enumeration
enum PageState {
  /// Loading initial data
  loading,

  /// Data loaded successfully
  loaded,

  /// Error occurred
  error,

  /// User has not joined any data pool
  notInPool,
}

/// Device manager page state provider
class DeviceManagerProvider extends ChangeNotifier {
  PageState _pageState = PageState.loading;
  String? _errorMessage;

  PageState get pageState => _pageState;
  String? get errorMessage => _errorMessage;

  void setLoaded() {
    _pageState = PageState.loaded;
    _errorMessage = null;
    notifyListeners();
  }

  void setError(String message) {
    _pageState = PageState.error;
    _errorMessage = message;
    notifyListeners();
  }

  void setNotInPool() {
    _pageState = PageState.notInPool;
    _errorMessage = null;
    notifyListeners();
  }

  void setLoading() {
    _pageState = PageState.loading;
    _errorMessage = null;
    notifyListeners();
  }
}

// ============================================================================
// Pairing State Management
// ============================================================================

/// Pairing state enumeration
enum PairingState {
  /// No pairing in progress
  idle,

  /// Scanning QR code
  scanning,

  /// Waiting for verification code input
  waitingVerify,

  /// Verifying code
  verifying,

  /// Pairing successful
  success,

  /// Pairing failed
  failed,
}

/// Pairing state provider
class PairingProvider extends ChangeNotifier {
  PairingState _state = PairingState.idle;
  String? _deviceId;
  String? _deviceName;
  String? _errorMessage;

  PairingState get state => _state;
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;
  String? get errorMessage => _errorMessage;

  void startScanning() {
    _state = PairingState.scanning;
    _deviceId = null;
    _deviceName = null;
    _errorMessage = null;
    notifyListeners();
  }

  void qrCodeScanned(String deviceId, String deviceName) {
    _state = PairingState.waitingVerify;
    _deviceId = deviceId;
    _deviceName = deviceName;
    _errorMessage = null;
    notifyListeners();
  }

  void startVerifying() {
    _state = PairingState.verifying;
    notifyListeners();
  }

  void verificationSuccess() {
    _state = PairingState.success;
    _errorMessage = null;
    notifyListeners();
  }

  void verificationFailed(String error) {
    _state = PairingState.failed;
    _errorMessage = error;
    notifyListeners();
  }

  void reset() {
    _state = PairingState.idle;
    _deviceId = null;
    _deviceName = null;
    _errorMessage = null;
    notifyListeners();
  }
}

// ============================================================================
// Verification State Management
// ============================================================================

/// Verification state enumeration
enum VerificationState {
  /// User is inputting code
  input,

  /// Verifying code with server
  verifying,

  /// Verification successful
  success,

  /// Verification failed
  failed,

  /// Verification code expired
  expired,
}

// ============================================================================
// Pairing Request Management
// ============================================================================

/// Active pairing requests provider
///
/// Manages currently active pairing requests
class PairingRequestsProvider extends ChangeNotifier {
  final List<PairingRequest> _requests = [];

  List<PairingRequest> get requests => List.unmodifiable(_requests);

  /// Add a new pairing request
  void addRequest(PairingRequest request) {
    _requests.add(request);
    notifyListeners();
  }

  /// Remove a pairing request by ID
  void removeRequest(String requestId) {
    _requests.removeWhere((r) => r.requestId == requestId);
    notifyListeners();
  }

  /// Get a request by ID
  PairingRequest? getRequest(String requestId) {
    try {
      return _requests.firstWhere((r) => r.requestId == requestId);
    } catch (e) {
      return null;
    }
  }

  /// Remove expired requests
  void cleanupExpired() {
    _requests.removeWhere((r) => r.isExpired);
    notifyListeners();
  }

  /// Clear all requests
  void clear() {
    _requests.clear();
    notifyListeners();
  }
}
