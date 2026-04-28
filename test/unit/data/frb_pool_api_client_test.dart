import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'frb client throws actionable error when endpoint and appDataDir are both missing',
    () async {
      final client = FrbPoolApiClient(nickname: 'tester', os: 'macos');

      await expectLater(
        client.createPool(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('endpointId or appDataDir'),
          ),
        ),
      );
    },
  );

  test('frb client createInvite requires runtime network', () async {
    final client = FrbPoolApiClient(nickname: 'tester', os: 'macos');

    await expectLater(
      client.createInvite('pool-1'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('runtime network'),
        ),
      ),
    );
  });
}
