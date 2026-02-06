import 'package:cardmind/models/device.dart';
import 'package:cardmind/services/device_discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_emit_events_on_device_online_offline', () async {
    final service = DeviceDiscoveryService();
    final events = <DeviceDiscoveryEvent>[];
    final sub = service.stateChanges.listen(events.add);

    final onlineService = service..handleDeviceOnline('peer-1', const ['addr']);
    await Future<void>.delayed(Duration.zero);

    onlineService.handleDeviceOffline('peer-1');
    await Future<void>.delayed(Duration.zero);

    expect(events.length, 2);
    expect(events.first.isOnline, isTrue);
    expect(events.last.isOnline, isFalse);

    await sub.cancel();
    service.dispose();
  });

  test('it_should_update_device_states_and_online_list', () {
    final service = DeviceDiscoveryService();

    final devices = <Device>[
      Device(
        id: 'peer-1',
        name: 'Device',
        type: DeviceType.laptop,
        status: DeviceStatus.offline,
        lastSeen: DateTime(2026, 1, 1),
        multiaddrs: const [],
      ),
    ];
    final updated = (service..handleDeviceOnline('peer-1', const ['addr']))
        .updateDeviceStates(devices);

    expect(updated.first.status, DeviceStatus.online);
    expect(updated.first.multiaddrs, ['addr']);

    final online = service.getOnlineDevices();
    expect(online, ['peer-1']);

    service.dispose();
  });

  test('it_should_reset_device_discovery_manager_singleton', () {
    final first = DeviceDiscoveryManager.instance;
    DeviceDiscoveryManager.reset();
    final second = DeviceDiscoveryManager.instance;

    expect(first, isNot(same(second)));
  });

  test('it_should_get_device_state_returns_latest', () {
    final service = DeviceDiscoveryService();

    final state = (service..handleDeviceOnline('peer-1', const ['addr']))
        .getDeviceState('peer-1');

    expect(state, isNotNull);
    expect(state!.isOnline, isTrue);
    service.dispose();
  });

  test('it_should_ignore_offline_for_unknown_peer', () async {
    final service = DeviceDiscoveryService();
    final events = <DeviceDiscoveryEvent>[];
    final sub = service.stateChanges.listen(events.add);

    service.handleDeviceOffline('unknown');
    await Future<void>.delayed(Duration.zero);

    expect(events, isEmpty);
    await sub.cancel();
    service.dispose();
  });

  test('it_should_dispose_clears_online_devices', () {
    final service = DeviceDiscoveryService();

    final onlineDevices =
        (service
              ..handleDeviceOnline('peer-1', const ['addr'])
              ..dispose())
            .getOnlineDevices();

    expect(onlineDevices, isEmpty);
  });
}
