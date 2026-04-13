import 'package:cardmind/features/shared/runtime/rust_library_path.dart';

String resolveRustLibraryPathForTests({
  String? operatingSystem,
  String? currentDirectory,
}) {
  final path = resolveRustLibraryPath(
    operatingSystem: operatingSystem,
    currentDirectory: currentDirectory,
  );
  if (path == null) {
    throw StateError('测试运行态仅支持 macOS Rust 动态库加载');
  }
  return path;
}
