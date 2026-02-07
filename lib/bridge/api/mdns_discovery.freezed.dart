// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mdns_discovery.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DiscoveredDevice {
  String get peerId => throw _privateConstructorUsedError;
  String get deviceName => throw _privateConstructorUsedError;
  List<String> get multiaddrs => throw _privateConstructorUsedError;
  bool get isOnline => throw _privateConstructorUsedError;
  int get lastSeen => throw _privateConstructorUsedError;

  /// Create a copy of DiscoveredDevice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DiscoveredDeviceCopyWith<DiscoveredDevice> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DiscoveredDeviceCopyWith<$Res> {
  factory $DiscoveredDeviceCopyWith(
    DiscoveredDevice value,
    $Res Function(DiscoveredDevice) then,
  ) = _$DiscoveredDeviceCopyWithImpl<$Res, DiscoveredDevice>;
  @useResult
  $Res call({
    String peerId,
    String deviceName,
    List<String> multiaddrs,
    bool isOnline,
    int lastSeen,
  });
}

/// @nodoc
class _$DiscoveredDeviceCopyWithImpl<$Res, $Val extends DiscoveredDevice>
    implements $DiscoveredDeviceCopyWith<$Res> {
  _$DiscoveredDeviceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DiscoveredDevice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? peerId = null,
    Object? deviceName = null,
    Object? multiaddrs = null,
    Object? isOnline = null,
    Object? lastSeen = null,
  }) {
    return _then(
      _value.copyWith(
            peerId: null == peerId
                ? _value.peerId
                : peerId // ignore: cast_nullable_to_non_nullable
                      as String,
            deviceName: null == deviceName
                ? _value.deviceName
                : deviceName // ignore: cast_nullable_to_non_nullable
                      as String,
            multiaddrs: null == multiaddrs
                ? _value.multiaddrs
                : multiaddrs // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            isOnline: null == isOnline
                ? _value.isOnline
                : isOnline // ignore: cast_nullable_to_non_nullable
                      as bool,
            lastSeen: null == lastSeen
                ? _value.lastSeen
                : lastSeen // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DiscoveredDeviceImplCopyWith<$Res>
    implements $DiscoveredDeviceCopyWith<$Res> {
  factory _$$DiscoveredDeviceImplCopyWith(
    _$DiscoveredDeviceImpl value,
    $Res Function(_$DiscoveredDeviceImpl) then,
  ) = __$$DiscoveredDeviceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String peerId,
    String deviceName,
    List<String> multiaddrs,
    bool isOnline,
    int lastSeen,
  });
}

/// @nodoc
class __$$DiscoveredDeviceImplCopyWithImpl<$Res>
    extends _$DiscoveredDeviceCopyWithImpl<$Res, _$DiscoveredDeviceImpl>
    implements _$$DiscoveredDeviceImplCopyWith<$Res> {
  __$$DiscoveredDeviceImplCopyWithImpl(
    _$DiscoveredDeviceImpl _value,
    $Res Function(_$DiscoveredDeviceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DiscoveredDevice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? peerId = null,
    Object? deviceName = null,
    Object? multiaddrs = null,
    Object? isOnline = null,
    Object? lastSeen = null,
  }) {
    return _then(
      _$DiscoveredDeviceImpl(
        peerId: null == peerId
            ? _value.peerId
            : peerId // ignore: cast_nullable_to_non_nullable
                  as String,
        deviceName: null == deviceName
            ? _value.deviceName
            : deviceName // ignore: cast_nullable_to_non_nullable
                  as String,
        multiaddrs: null == multiaddrs
            ? _value._multiaddrs
            : multiaddrs // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        isOnline: null == isOnline
            ? _value.isOnline
            : isOnline // ignore: cast_nullable_to_non_nullable
                  as bool,
        lastSeen: null == lastSeen
            ? _value.lastSeen
            : lastSeen // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$DiscoveredDeviceImpl implements _DiscoveredDevice {
  const _$DiscoveredDeviceImpl({
    required this.peerId,
    required this.deviceName,
    required final List<String> multiaddrs,
    required this.isOnline,
    required this.lastSeen,
  }) : _multiaddrs = multiaddrs;

  @override
  final String peerId;
  @override
  final String deviceName;
  final List<String> _multiaddrs;
  @override
  List<String> get multiaddrs {
    if (_multiaddrs is EqualUnmodifiableListView) return _multiaddrs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_multiaddrs);
  }

  @override
  final bool isOnline;
  @override
  final int lastSeen;

  @override
  String toString() {
    return 'DiscoveredDevice(peerId: $peerId, deviceName: $deviceName, multiaddrs: $multiaddrs, isOnline: $isOnline, lastSeen: $lastSeen)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DiscoveredDeviceImpl &&
            (identical(other.peerId, peerId) || other.peerId == peerId) &&
            (identical(other.deviceName, deviceName) ||
                other.deviceName == deviceName) &&
            const DeepCollectionEquality().equals(
              other._multiaddrs,
              _multiaddrs,
            ) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.lastSeen, lastSeen) ||
                other.lastSeen == lastSeen));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    peerId,
    deviceName,
    const DeepCollectionEquality().hash(_multiaddrs),
    isOnline,
    lastSeen,
  );

  /// Create a copy of DiscoveredDevice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DiscoveredDeviceImplCopyWith<_$DiscoveredDeviceImpl> get copyWith =>
      __$$DiscoveredDeviceImplCopyWithImpl<_$DiscoveredDeviceImpl>(
        this,
        _$identity,
      );
}

abstract class _DiscoveredDevice implements DiscoveredDevice {
  const factory _DiscoveredDevice({
    required final String peerId,
    required final String deviceName,
    required final List<String> multiaddrs,
    required final bool isOnline,
    required final int lastSeen,
  }) = _$DiscoveredDeviceImpl;

  @override
  String get peerId;
  @override
  String get deviceName;
  @override
  List<String> get multiaddrs;
  @override
  bool get isOnline;
  @override
  int get lastSeen;

  /// Create a copy of DiscoveredDevice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DiscoveredDeviceImplCopyWith<_$DiscoveredDeviceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
