import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('macOS project metadata and Rust bundle integration are committed', () {
    expect(Directory('macos').existsSync(), isTrue);
    expect(
      _read('macos/Runner/Configs/AppInfo.xcconfig'),
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.cardmind.v2'),
    );
    expect(
      _read('macos/Runner.xcodeproj/project.pbxproj'),
      contains('macos_assemble.sh'),
    );
    expect(
      _read('macos/Runner.xcodeproj/project.pbxproj'),
      contains('libcardmind_backend.dylib'),
    );
    expect(
      _read('macos/Runner.xcodeproj/project.pbxproj'),
      contains('install_name_tool -id @rpath/libcardmind_backend.dylib'),
    );
    expect(
      _read('macos/Runner/Release.entitlements'),
      contains('com.apple.security.network.client'),
    );
    expect(
      _read('rust-backend/Cargo.toml'),
      contains('[profile.release]'),
    );
    expect(_read('rust-backend/Cargo.toml'), contains('strip = "none"'));
    final buildScript = _read('tool/build.dart');
    expect(buildScript, contains('libcardmind_backend.dylib'));
    expect(buildScript, contains('Contents/Frameworks'));
    expect(buildScript, isNot(contains('libcardmind_rust.dylib')));
  });
}
