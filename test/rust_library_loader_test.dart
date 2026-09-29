import 'package:cardmind/bridge/rust_library_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveBundledRustLibraryPath', () {
    test('macOS 且 Contents/Frameworks 下 dylib 存在 → 返回该绝对路径', () {
      const exe = '/Applications/cardmind.app/Contents/MacOS/cardmind';
      const expected =
          '/Applications/cardmind.app/Contents/Frameworks/libcardmind_backend.dylib';
      String? probed;

      final path = resolveBundledRustLibraryPath(
        executablePath: exe,
        operatingSystem: 'macos',
        exists: (candidate) {
          probed = candidate;
          return true;
        },
      );

      expect(probed, expected);
      expect(path, expected);
    });

    test('macOS 且 dylib 不存在 → null', () {
      const exe = '/Applications/cardmind.app/Contents/MacOS/cardmind';
      var probedCount = 0;

      final path = resolveBundledRustLibraryPath(
        executablePath: exe,
        operatingSystem: 'macos',
        exists: (_) {
          probedCount++;
          return false;
        },
      );

      expect(path, isNull);
      expect(probedCount, 1);
    });

    test('Windows 且 exe 同目录 dll 存在 → 返回该绝对路径', () {
      const exe = r'C:\app\cardmind.exe';
      const expected = r'C:\app\cardmind_backend.dll';
      String? probed;

      final path = resolveBundledRustLibraryPath(
        executablePath: exe,
        operatingSystem: 'windows',
        exists: (candidate) {
          probed = candidate;
          return true;
        },
      );

      expect(probed, expected);
      expect(path, expected);
    });

    test('Windows 且 dll 不存在 → null', () {
      final path = resolveBundledRustLibraryPath(
        executablePath: r'C:\app\cardmind.exe',
        operatingSystem: 'windows',
        exists: (_) => false,
      );

      expect(path, isNull);
    });

    test('Linux 且 <exe>/../lib/lib<stem>.so 存在 → 返回该绝对路径', () {
      const exe = '/opt/cardmind/cardmind';
      const expected = '/opt/cardmind/lib/libcardmind_backend.so';
      String? probed;

      final path = resolveBundledRustLibraryPath(
        executablePath: exe,
        operatingSystem: 'linux',
        exists: (candidate) {
          probed = candidate;
          return true;
        },
      );

      expect(probed, expected);
      expect(path, expected);
    });

    test('Linux 且 so 不存在 → null', () {
      final path = resolveBundledRustLibraryPath(
        executablePath: '/opt/cardmind/cardmind',
        operatingSystem: 'linux',
        exists: (_) => false,
      );

      expect(path, isNull);
    });

    test('未知平台 → null，且不探测文件系统', () {
      var probedCount = 0;

      final path = resolveBundledRustLibraryPath(
        executablePath: '/whatever/cardmind',
        operatingSystem: 'fuchsia',
        exists: (_) {
          probedCount++;
          return true;
        },
      );

      expect(path, isNull);
      expect(probedCount, 0);
    });
  });
}
