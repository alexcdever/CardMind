import 'dart:io';

String resolveRustLibraryPath({
  String? operatingSystem,
  String? currentDirectory,
}) {
  final os = operatingSystem ?? Platform.operatingSystem;
  if (os != 'macos') {
    throw UnsupportedError('当前仅支持 macOS 运行态动态库路径解析');
  }

  final rootDir = currentDirectory ?? Directory.current.path;
  final dylib = File(
    '$rootDir/build/native/macos/libcardmind_rust.dylib',
  ).absolute;
  if (!dylib.existsSync()) {
    throw StateError(
      'Rust runtime dylib not found at ${dylib.path}. Run `dart run tool/build.dart lib` first.',
    );
  }
  return dylib.path;
}
