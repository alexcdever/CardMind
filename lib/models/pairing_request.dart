import 'package:cardmind/models/device.dart';

/// Pairing request model for device pairing flow
///
/// Represents a pairing request between two devices with verification code.
class PairingRequest {
  /// Unique request identifier
  final String requestId;

  /// Remote device ID (PeerId)
  final String deviceId;

  /// Remote device name
  final String deviceName;

  /// Remote device type
  final DeviceType deviceType;

  /// 6-digit verification code
  final String verificationCode;

  /// Request timestamp
  final DateTime timestamp;

  /// Request expiration time (5 minutes from timestamp)
  DateTime get expiresAt => timestamp.add(const Duration(minutes: 5));

  /// Check if request has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Time remaining until expiration
  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) {
      return Duration.zero;
    }
    return expiresAt.difference(now);
  }

  const PairingRequest({
    required this.requestId,
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.verificationCode,
    required this.timestamp,
  });

  /// Create a copy with updated fields
  PairingRequest copyWith({
    String? requestId,
    String? deviceId,
    String? deviceName,
    DeviceType? deviceType,
    String? verificationCode,
    DateTime? timestamp,
  }) {
    return PairingRequest(
      requestId: requestId ?? this.requestId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      verificationCode: verificationCode ?? this.verificationCode,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceType': deviceType.name,
      'verificationCode': verificationCode,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON
  factory PairingRequest.fromJson(Map<String, dynamic> json) {
    return PairingRequest(
      requestId: json['requestId'] as String,
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      deviceType: DeviceType.values.firstWhere(
        (e) => e.name == json['deviceType'],
        orElse: () => DeviceType.laptop,
      ),
      verificationCode: json['verificationCode'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PairingRequest &&
        other.requestId == requestId &&
        other.deviceId == deviceId &&
        other.deviceName == deviceName &&
        other.deviceType == deviceType &&
        other.verificationCode == verificationCode &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(
      requestId,
      deviceId,
      deviceName,
      deviceType,
      verificationCode,
      timestamp,
    );
  }

  @override
  String toString() {
    return 'PairingRequest(requestId: $requestId, deviceId: $deviceId, '
        'deviceName: $deviceName, deviceType: $deviceType, '
        'verificationCode: $verificationCode, timestamp: $timestamp)';
  }
}
