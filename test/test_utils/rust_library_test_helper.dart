import 'package:cardmind/features/shared/runtime/rust_library_path.dart';

String resolveRustLibraryPathForTests({
  String? operatingSystem,
  String? currentDirectory,
}) {
  return resolveRustLibraryPath(
    operatingSystem: operatingSystem,
    currentDirectory: currentDirectory,
  );
}
