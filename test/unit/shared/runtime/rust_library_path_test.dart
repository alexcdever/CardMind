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

  test('throws unsupported error on non-macOS platforms', () {
    expect(
      () => resolveRustLibraryPath(
        operatingSystem: 'linux',
        currentDirectory: '/tmp/cardmind',
      ),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          contains('当前仅支持 macOS'),
        ),
      ),
    );
  });
}
