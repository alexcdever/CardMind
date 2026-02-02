# Mobile Device Manager Implementation Guide

## 1. QR Code Data Format

### QR Code JSON Structure

The QR code SHALL contain the following JSON structure:

```json
{
  "version": "1.0",
  "type": "pairing",
  "deviceId": "uuid-v7",
  "deviceName": "我的手机",
  "deviceType": "phone",
  "timestamp": 1234567890,
  "poolId": "pool-uuid"
}
```

### Field Specifications

- **version**: String, format "1.0", indicates QR code format version
- **type**: String, must be "pairing" for device pairing
- **deviceId**: String, UUID v7 format, unique device identifier
- **deviceName**: String, max 32 characters, current device name
- **deviceType**: String, one of "phone", "laptop", "tablet"
- **timestamp**: Integer, Unix timestamp in seconds
- **poolId**: String, UUID format, data pool identifier

### QR Code Generation

Use `qr_flutter` package with the following configuration:

```dart
import 'package:qr_flutter/qr_flutter.dart';

QrImageView(
  data: jsonEncode(qrData),
  version: QrVersions.auto,
  size: 240.0,
  errorCorrectionLevel: QrErrorCorrectLevel.M,
  backgroundColor: Colors.white,
  foregroundColor: Colors.black,
)
```

**Configuration Details:**
- Error correction level: Medium (M) - balances data capacity and error recovery
- Version: Auto - automatically selects optimal QR code version
- Size: 240x240 pixels
- Colors: Black foreground on white background

### QR Code Scanning

Use `mobile_scanner` package for scanning:

```dart
import 'package:mobile_scanner/mobile_scanner.dart';

MobileScanner(
  controller: MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  ),
  onDetect: (capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _handleQRCodeScanned(barcode.rawValue!);
      }
    }
  },
)
```

### QR Code Validation

After scanning, validate the QR code data:

```dart
bool validateQRCode(Map<String, dynamic> data, String currentDeviceId) {
  // Check required fields
  if (!data.containsKey('version') ||
      !data.containsKey('type') ||
      !data.containsKey('deviceId') ||
      !data.containsKey('timestamp')) {
    return false;
  }

  // Verify type
  if (data['type'] != 'pairing') {
    return false;
  }

  // Check timestamp (must be within 10 minutes)
  final timestamp = data['timestamp'] as int;
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if ((now - timestamp).abs() > 600) {
    return false;
  }

  // Prevent self-pairing
  if (data['deviceId'] == currentDeviceId) {
    return false;
  }

  return true;
}
```

## 2. Verification Code System

### Verification Code Generation

Generate a secure 6-digit verification code:

```dart
import 'dart:math';

String generateVerificationCode() {
  final random = Random.secure();
  final code = random.nextInt(1000000).toString().padLeft(6, '0');
  return code;
}
```

**Security Considerations:**
- Use `Random.secure()` for cryptographically secure random numbers
- Always pad to 6 digits (e.g., "000123" not "123")
- Generate new code for each pairing request
- Store with 5-minute expiration

### Verification Code Storage

Store verification codes in memory with expiration:

```dart
class VerificationCodeManager {
  final Map<String, VerificationCodeEntry> _codes = {};

  void storeCode(String requestId, String code) {
    _codes[requestId] = VerificationCodeEntry(
      code: code,
      expiresAt: DateTime.now().add(Duration(minutes: 5)),
    );
  }

  bool verifyCode(String requestId, String inputCode) {
    final entry = _codes[requestId];
    if (entry == null) return false;

    // Check expiration
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _codes.remove(requestId);
      return false;
    }

    // Verify code
    final isValid = entry.code == inputCode;
    if (isValid) {
      _codes.remove(requestId); // Remove after successful verification
    }

    return isValid;
  }

  void cleanup() {
    final now = DateTime.now();
    _codes.removeWhere((_, entry) => now.isAfter(entry.expiresAt));
  }
}

class VerificationCodeEntry {
  final String code;
  final DateTime expiresAt;

  VerificationCodeEntry({required this.code, required this.expiresAt});
}
```

### Verification Code Input Component

Implement auto-advance input fields:

```dart
class VerificationCodeInput extends StatefulWidget {
  final Function(String) onComplete;

  @override
  _VerificationCodeInputState createState() => _VerificationCodeInputState();
}

class _VerificationCodeInputState extends State<VerificationCodeInput> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty) {
      // Move to next field
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // All fields filled, trigger completion
        final code = _controllers.map((c) => c.text).join();
        widget.onComplete(code);
      }
    }
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      // Move to previous field
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        return Container(
          width: 48,
          height: 56,
          margin: EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: _controllers[index].text.isNotEmpty,
              fillColor: Color(0xFFF0F8FF),
            ),
            onChanged: (value) => _onChanged(index, value),
            onTap: () {
              // Clear field on tap for easy re-entry
              _controllers[index].clear();
            },
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}
```

## 3. State Management with Riverpod

### Provider Structure

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Device list provider
final pairedDevicesProvider = StreamProvider<List<Device>>((ref) {
  return deviceRepository.watchPairedDevices();
});

// Current device provider
final currentDeviceProvider = StreamProvider<Device>((ref) {
  return deviceRepository.watchCurrentDevice();
});

// Pool membership provider
final hasJoinedPoolProvider = StreamProvider<bool>((ref) {
  return deviceRepository.watchPoolMembership();
});

// Page state provider
final deviceManagerStateProvider =
    StateNotifierProvider<DeviceManagerNotifier, DeviceManagerState>((ref) {
  return DeviceManagerNotifier();
});

// Pairing state provider
final pairingStateProvider =
    StateNotifierProvider<PairingNotifier, PairingState>((ref) {
  return PairingNotifier();
});
```

### State Classes

```dart
// Page state
enum PageState {
  loading,
  loaded,
  error,
  notInPool,
}

class DeviceManagerState {
  final PageState pageState;
  final String? errorMessage;

  DeviceManagerState({
    required this.pageState,
    this.errorMessage,
  });

  DeviceManagerState copyWith({
    PageState? pageState,
    String? errorMessage,
  }) {
    return DeviceManagerState(
      pageState: pageState ?? this.pageState,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// Pairing state
enum PairingState {
  idle,
  scanning,
  waitingVerify,
  verifying,
  success,
  failed,
}

class PairingStateData {
  final PairingState state;
  final String? deviceId;
  final String? deviceName;
  final String? errorMessage;

  PairingStateData({
    required this.state,
    this.deviceId,
    this.deviceName,
    this.errorMessage,
  });
}

// Verification state
enum VerificationState {
  input,
  verifying,
  success,
  failed,
  expired,
}
```

### State Notifiers

```dart
class DeviceManagerNotifier extends StateNotifier<DeviceManagerState> {
  DeviceManagerNotifier() : super(DeviceManagerState(pageState: PageState.loading));

  void setLoaded() {
    state = state.copyWith(pageState: PageState.loaded);
  }

  void setError(String message) {
    state = state.copyWith(
      pageState: PageState.error,
      errorMessage: message,
    );
  }

  void setNotInPool() {
    state = state.copyWith(pageState: PageState.notInPool);
  }
}

class PairingNotifier extends StateNotifier<PairingStateData> {
  PairingNotifier() : super(PairingStateData(state: PairingState.idle));

  void startScanning() {
    state = PairingStateData(state: PairingState.scanning);
  }

  void qrCodeScanned(String deviceId, String deviceName) {
    state = PairingStateData(
      state: PairingState.waitingVerify,
      deviceId: deviceId,
      deviceName: deviceName,
    );
  }

  void startVerifying() {
    state = state.copyWith(state: PairingState.verifying);
  }

  void verificationSuccess() {
    state = PairingStateData(state: PairingState.success);
  }

  void verificationFailed(String error) {
    state = PairingStateData(
      state: PairingState.failed,
      errorMessage: error,
    );
  }

  void reset() {
    state = PairingStateData(state: PairingState.idle);
  }
}
```

## 4. Camera Resource Management

### Camera Controller Lifecycle

```dart
class QRCodeScannerWidget extends StatefulWidget {
  @override
  _QRCodeScannerWidgetState createState() => _QRCodeScannerWidgetState();
}

class _QRCodeScannerWidgetState extends State<QRCodeScannerWidget>
    with AutomaticKeepAliveClientMixin {
  MobileScannerController? _controller;
  bool _isInitialized = false;

  @override
  bool get wantKeepAlive => false; // Don't keep alive to save resources

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
        // Use 720p for balance between quality and performance
        formats: [BarcodeFormat.qrCode],
      );

      await _controller!.start();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      // Handle camera initialization error
      if (mounted) {
        _showError('相机启动失败');
      }
    }
  }

  @override
  void dispose() {
    // Always dispose camera controller
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (!_isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return MobileScanner(
      controller: _controller!,
      onDetect: _handleBarcode,
    );
  }

  void _handleBarcode(BarcodeCapture capture) {
    // Stop scanning after first successful scan
    _controller?.stop();

    // Process QR code
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      _processQRCode(barcode.rawValue!);
    }
  }
}
```

### Camera Permission Handling

```dart
import 'package:permission_handler/permission_handler.dart';

class CameraPermissionHandler {
  static Future<CameraPermissionStatus> checkPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return CameraPermissionStatus.granted;
    } else if (status.isDenied) {
      return CameraPermissionStatus.denied;
    } else if (status.isPermanentlyDenied) {
      return CameraPermissionStatus.permanentlyDenied;
    } else {
      return CameraPermissionStatus.notRequested;
    }
  }

  static Future<bool> requestPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}

enum CameraPermissionStatus {
  notRequested,
  granted,
  denied,
  permanentlyDenied,
}
```

## 5. Device List Sorting and Time Formatting

### Device Sorting Logic

```dart
List<Device> sortDevices(List<Device> devices) {
  final sorted = List<Device>.from(devices);

  sorted.sort((a, b) {
    // Online devices first
    if (a.status == DeviceStatus.online && b.status != DeviceStatus.online) {
      return -1;
    }
    if (a.status != DeviceStatus.online && b.status == DeviceStatus.online) {
      return 1;
    }

    // Within same status, sort by last seen time (descending)
    return b.lastSeen.compareTo(a.lastSeen);
  });

  return sorted;
}
```

### Time Formatting Utility

```dart
String formatLastSeen(DateTime lastSeen) {
  final now = DateTime.now();
  final difference = now.difference(lastSeen);

  if (difference.inMinutes < 1) {
    return '刚刚';
  } else if (difference.inHours < 1) {
    return '${difference.inMinutes} 分钟前';
  } else if (difference.inDays < 1) {
    return '${difference.inHours} 小时前';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} 天前';
  } else {
    // Format as "yyyy-MM-dd HH:mm"
    return '${lastSeen.year}-${lastSeen.month.toString().padLeft(2, '0')}-${lastSeen.day.toString().padLeft(2, '0')} '
           '${lastSeen.hour.toString().padLeft(2, '0')}:${lastSeen.minute.toString().padLeft(2, '0')}';
  }
}
```

## 6. Performance Optimization

### QR Code Caching

```dart
class QRCodeCache {
  static final Map<String, Uint8List> _cache = {};

  static Future<Uint8List?> get(String deviceId) async {
    return _cache[deviceId];
  }

  static Future<void> set(String deviceId, Uint8List imageData) async {
    _cache[deviceId] = imageData;
  }

  static void clear() {
    _cache.clear();
  }
}

// Usage in QR code widget
class CachedQRCode extends StatelessWidget {
  final String deviceId;
  final Map<String, dynamic> qrData;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: QRCodeCache.get(deviceId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!);
        }

        return RepaintBoundary(
          child: QrImageView(
            data: jsonEncode(qrData),
            version: QrVersions.auto,
            size: 240.0,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        );
      },
    );
  }
}
```

### List Performance Optimization

```dart
class DeviceList extends StatelessWidget {
  final List<Device> devices;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: devices.length,
      // Use itemExtent for better performance if items have fixed height
      // itemExtent: 80.0,
      itemBuilder: (context, index) {
        final device = devices[index];
        return DeviceListItem(
          key: ValueKey(device.id), // Use key for efficient updates
          device: device,
        );
      },
    );
  }
}

// Use const constructors where possible
class DeviceListItem extends StatelessWidget {
  final Device device;

  const DeviceListItem({
    Key? key,
    required this.device,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary( // Isolate repaints
      child: Container(
        // ... widget tree
      ),
    );
  }
}
```

## 7. Platform-Specific Configuration

### iOS Configuration (Info.plist)

Add camera permission description:

```xml
<key>NSCameraUsageDescription</key>
<string>需要使用相机扫描二维码以配对设备</string>
```

### Android Configuration (AndroidManifest.xml)

Add camera permission:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

### Platform-Specific UI Adaptations

```dart
Widget buildPlatformDialog(BuildContext context, Widget child) {
  if (Platform.isIOS) {
    return CupertinoAlertDialog(
      content: child,
    );
  } else {
    return AlertDialog(
      content: child,
    );
  }
}

Widget buildPlatformButton(String text, VoidCallback onPressed) {
  if (Platform.isIOS) {
    return CupertinoButton(
      onPressed: onPressed,
      child: Text(text),
    );
  } else {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(text),
    );
  }
}
```

## 8. Error Logging

### Logging Strategy

```dart
import 'package:logger/logger.dart';

class DeviceManagerLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  static void logPairingRequest(String deviceId, String deviceName) {
    _logger.i('Pairing request sent to device: $deviceName ($deviceId)');
  }

  static void logPairingReceived(String deviceId, String deviceName) {
    _logger.i('Pairing request received from device: $deviceName ($deviceId)');
  }

  static void logVerificationGenerated(String code) {
    _logger.d('Verification code generated: $code');
  }

  static void logVerificationSuccess(String deviceId) {
    _logger.i('Verification successful for device: $deviceId');
  }

  static void logVerificationFailed(String deviceId, String reason) {
    _logger.w('Verification failed for device: $deviceId, reason: $reason');
  }

  static void logQRCodeScanned(String deviceId) {
    _logger.i('QR code scanned successfully: $deviceId');
  }

  static void logQRCodeScanFailed(String error) {
    _logger.e('QR code scan failed: $error');
  }

  static void logCameraInitSuccess() {
    _logger.i('Camera initialized successfully');
  }

  static void logCameraInitFailed(String error) {
    _logger.e('Camera initialization failed: $error');
  }

  static void logNetworkError(String operation, String error) {
    _logger.e('Network error during $operation: $error');
  }
}
```

## 9. Testing Utilities

### Mock Data Generators

```dart
class MockDeviceGenerator {
  static Device createMockDevice({
    String? id,
    String? name,
    DeviceType? type,
    DeviceStatus? status,
    DateTime? lastSeen,
  }) {
    return Device(
      id: id ?? 'device-${Random().nextInt(1000)}',
      name: name ?? 'Test Device ${Random().nextInt(100)}',
      type: type ?? DeviceType.phone,
      status: status ?? DeviceStatus.online,
      lastSeen: lastSeen ?? DateTime.now(),
    );
  }

  static List<Device> createMockDeviceList(int count) {
    return List.generate(count, (index) {
      final isOnline = index < count ~/ 2;
      return createMockDevice(
        name: 'Device $index',
        status: isOnline ? DeviceStatus.online : DeviceStatus.offline,
        lastSeen: DateTime.now().subtract(Duration(hours: index)),
      );
    });
  }
}

class MockPairingRequest {
  static PairingRequest create({
    String? requestId,
    String? deviceId,
    String? deviceName,
  }) {
    return PairingRequest(
      requestId: requestId ?? 'request-${Random().nextInt(1000)}',
      deviceId: deviceId ?? 'device-${Random().nextInt(1000)}',
      deviceName: deviceName ?? 'Test Device',
      deviceType: DeviceType.phone,
      verificationCode: generateVerificationCode(),
      timestamp: DateTime.now(),
    );
  }
}
```

### Widget Test Helpers

```dart
class DeviceManagerTestHelpers {
  static Widget wrapWithProviders(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  static Future<void> enterVerificationCode(
    WidgetTester tester,
    String code,
  ) async {
    for (int i = 0; i < 6; i++) {
      await tester.enterText(
        find.byType(TextField).at(i),
        code[i],
      );
    }
    await tester.pump();
  }

  static Future<void> tapButton(
    WidgetTester tester,
    String buttonText,
  ) async {
    await tester.tap(find.text(buttonText));
    await tester.pumpAndSettle();
  }
}
```

## 10. Accessibility Implementation

### Semantic Labels

```dart
class AccessibleDeviceCard extends StatelessWidget {
  final Device device;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '设备：${device.name}，类型：${_getDeviceTypeLabel(device.type)}，'
             '状态：${device.status == DeviceStatus.online ? "在线" : "离线"}',
      button: false,
      child: Container(
        // ... widget tree
      ),
    );
  }

  String _getDeviceTypeLabel(DeviceType type) {
    switch (type) {
      case DeviceType.phone:
        return '手机';
      case DeviceType.laptop:
        return '笔记本电脑';
      case DeviceType.tablet:
        return '平板电脑';
    }
  }
}

class AccessibleButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: true,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          constraints: BoxConstraints(minWidth: 48, minHeight: 48),
          child: child,
        ),
      ),
    );
  }
}
```

### Color Contrast Utilities

```dart
class ColorContrastChecker {
  // Calculate relative luminance
  static double _luminance(Color color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;

    final rLum = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4);
    final gLum = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4);
    final bLum = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4);

    return 0.2126 * rLum + 0.7152 * gLum + 0.0722 * bLum;
  }

  // Calculate contrast ratio
  static double contrastRatio(Color color1, Color color2) {
    final lum1 = _luminance(color1);
    final lum2 = _luminance(color2);

    final lighter = max(lum1, lum2);
    final darker = min(lum1, lum2);

    return (lighter + 0.05) / (darker + 0.05);
  }

  // Check if contrast meets WCAG AA standard (4.5:1 for text)
  static bool meetsWCAGAA(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= 4.5;
  }

  // Check if contrast meets WCAG AA standard for large text (3:1)
  static bool meetsWCAGAALarge(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= 3.0;
  }
}
```
