import 'dart:io';

import 'package:cardmind/features/shared/runtime/rust_library_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns absolute runtime dylib path for macOS', () async {
    final tempRoot = await Directory.systemTemp.createTemp(
      'cardmind-runtime-lib-',
    );
    final dylib = File(
      '${tempRoot.path}/build/native/macos/libcardmind_rust.dylib',
    )..createSync(recursive: true);

    final path = resolveRustLibraryPath(
      operatingSystem: 'macos',
      currentDirectory: tempRoot.path,
    );

    expect(path, dylib.absolute.path);
  });

  test(
    'prefers app bundle frameworks dylib when launched from macOS app',
    () async {
      final tempRoot = await Directory.systemTemp.createTemp(
        'cardmind-app-bundle-runtime-',
      );
      final dylib = File(
        '${tempRoot.path}/cardmind.app/Contents/Frameworks/libcardmind_rust.dylib',
      )..createSync(recursive: true);

      final path = resolveRustLibraryPath(
        operatingSystem: 'macos',
        currentDirectory: '${tempRoot.path}/container/data',
        executablePath: '${tempRoot.path}/cardmind.app/Contents/MacOS/cardmind',
      );

      expect(path, dylib.absolute.path);
    },
  );

  test('throws actionable error when runtime dylib is missing', () {
    expect(
      () => resolveRustLibraryPath(
        operatingSystem: 'macos',
        currentDirectory: '/tmp/cardmind-missing',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('build/native/macos/libcardmind_rust.dylib'),
            contains('dart run tool/build.dart lib'),
          ),
        ),
      ),
    );
  });

  test('returns null on non-macOS platforms', () {
    final path = resolveRustLibraryPath(
      operatingSystem: 'linux',
      currentDirectory: '/tmp/cardmind',
    );

    expect(path, isNull);
  });
}
