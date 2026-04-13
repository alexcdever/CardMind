import 'package:cardmind/features/shared/runtime/ios_rust_framework_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns simulator dylib path for iOS simulator sdk', () {
    final path = resolveIosRustDylibPath(
      projectDir: '/workspace/CardMind/ios',
      platformName: 'iphonesimulator',
    );

    expect(
      path,
      '/workspace/CardMind/rust/target/aarch64-apple-ios-sim/release/libcardmind_rust.dylib',
    );
  });

  test('returns device dylib path for iPhoneOS sdk', () {
    final path = resolveIosRustDylibPath(
      projectDir: '/workspace/CardMind/ios',
      platformName: 'iphoneos',
    );

    expect(
      path,
      '/workspace/CardMind/rust/target/aarch64-apple-ios/release/libcardmind_rust.dylib',
    );
  });
}
