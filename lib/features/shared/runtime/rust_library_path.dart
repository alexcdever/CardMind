import 'dart:io';

String? resolveRustLibraryPath({
  String? operatingSystem,
  String? currentDirectory,
  String? executablePath,
}) {
  final os = operatingSystem ?? Platform.operatingSystem;
  if (os != 'macos') {
    return null;
  }

  final executable = File(
    executablePath ?? Platform.resolvedExecutable,
  ).absolute;
  final frameworksDylib = File(
    '${executable.parent.parent.path}/Frameworks/libcardmind_rust.dylib',
  ).absolute;
  if (frameworksDylib.existsSync()) {
    return frameworksDylib.path;
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
