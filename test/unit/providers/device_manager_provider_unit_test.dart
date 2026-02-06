import 'package:cardmind/models/device.dart';
import 'package:cardmind/models/pairing_request.dart';
import 'package:cardmind/providers/device_manager_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_update_page_state', () {
    final provider = DeviceManagerProvider();

    expect((provider..setLoading()).pageState, PageState.loading);

    expect((provider..setLoaded()).pageState, PageState.loaded);

    expect((provider..setNotInPool()).pageState, PageState.notInPool);

    final errorProvider = provider..setError('error');
    expect(errorProvider.pageState, PageState.error);
    expect(errorProvider.errorMessage, 'error');
  });

  test('it_should_update_pairing_state_flow', () {
    final provider = PairingProvider();

    expect((provider..startScanning()).state, PairingState.scanning);

    final waitingProvider = provider..qrCodeScanned('peer-1', 'Device');
    expect(waitingProvider.state, PairingState.waitingVerify);
    expect(waitingProvider.deviceId, 'peer-1');

    expect((provider..startVerifying()).state, PairingState.verifying);

    expect((provider..verificationSuccess()).state, PairingState.success);

    final failedProvider = provider..verificationFailed('fail');
    expect(failedProvider.state, PairingState.failed);
    expect(failedProvider.errorMessage, 'fail');

    expect((provider..reset()).state, PairingState.idle);
  });

  test('it_should_manage_pairing_requests', () {
    final provider = PairingRequestsProvider();
    final request = PairingRequest(
      requestId: 'req-1',
      deviceId: 'peer-1',
      deviceName: 'Device',
      deviceType: DeviceType.phone,
      verificationCode: '123456',
      timestamp: DateTime.now(),
    );

    final addedProvider = provider..addRequest(request);
    expect(addedProvider.requests.length, 1);
    expect(addedProvider.getRequest('req-1'), isNotNull);

    expect((provider..removeRequest('req-1')).requests, isEmpty);

    final expired = PairingRequest(
      requestId: 'req-2',
      deviceId: 'peer-2',
      deviceName: 'Device',
      deviceType: DeviceType.tablet,
      verificationCode: '654321',
      timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
    );
    final expiredProvider = provider
      ..addRequest(expired)
      ..cleanupExpired();
    expect(expiredProvider.requests, isEmpty);
  });

  test('it_should_clear_pairing_requests', () {
    final provider = PairingRequestsProvider();
    final request = PairingRequest(
      requestId: 'req-3',
      deviceId: 'peer-3',
      deviceName: 'Device',
      deviceType: DeviceType.phone,
      verificationCode: '123456',
      timestamp: DateTime.now(),
    );

    final addedProvider = provider..addRequest(request);
    expect(addedProvider.requests, isNotEmpty);

    expect((provider..clear()).requests, isEmpty);
  });

  test('it_should_get_request_returns_null_when_missing', () {
    final provider = PairingRequestsProvider();

    expect(provider.getRequest('missing'), isNull);
  });
}
