import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Copy Rust Framework build phase rebuilds ios simulator dylib', () async {
    final podfile = File('ios/Podfile').readAsStringSync();

    expect(
      podfile,
      contains('cargo build --release --target "\$RUST_TARGET"'),
    );
    expect(
      podfile,
      contains('RUST_TARGET="aarch64-apple-ios-sim"'),
    );
    expect(
      podfile,
      contains('RUST_TARGET="aarch64-apple-ios"'),
    );
  });
}
