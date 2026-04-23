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
}
