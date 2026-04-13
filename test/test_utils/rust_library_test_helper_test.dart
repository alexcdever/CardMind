import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'rust_library_test_helper.dart';

void main() {
  test(
    'test helper resolves runtime dylib through shared runtime entry',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'cardmind-test-runtime-',
      );
      final dylibFile = File(
        '${tempRoot.path}/build/native/macos/libcardmind_rust.dylib',
      );
      dylibFile.createSync(recursive: true);

      final path = resolveRustLibraryPathForTests(
        operatingSystem: 'macos',
        currentDirectory: tempRoot.path,
      );

      expect(path, endsWith('build/native/macos/libcardmind_rust.dylib'));
    },
  );

  test('test helper throws actionable error on non-macOS platforms', () {
    expect(
      () => resolveRustLibraryPathForTests(
        operatingSystem: 'linux',
        currentDirectory: '/tmp/cardmind',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('仅支持 macOS'),
        ),
      ),
    );
  });
}
