import 'package:path/path.dart' as p;

/// 打包产物内 Rust 动态库的文件名主干（对应 FRB `stem`）。
const String rustLibraryStem = 'cardmind_backend';

/// 解析打包应用内随包分发的 Rust 动态库绝对路径。
///
/// 背景：FRB 2.12.0 的默认加载器用 `Directory.current.uri.resolve(ioDirectory)`
/// 解析 `ioDirectory`（本项目为相对路径 `rust-backend/target/release/`），
/// 因此打包应用只有在进程工作目录恰好是项目根时才能加载成功。本函数改为按
/// [executablePath] 推导产物内的绝对路径，使启动不再依赖工作目录。
///
/// 按 [operatingSystem] 分派候选路径（与 `Platform.operatingSystem` 取值一致）：
///
/// | 平台 | 候选路径 |
/// |---|---|
/// | `macos` / `ios` | `<exe>/../../Frameworks/lib<stem>.dylib` |
/// | `windows` | `<exe 所在目录>/<stem>.dll` |
/// | `linux` | `<exe>/../lib/lib<stem>.so` |
/// | 其他 | 无候选，返回 null |
///
/// 候选文件存在（由注入的 [exists] 判定）则返回该绝对路径，否则返回 null。
/// 返回 null 时调用方**不得**传 `externalLibrary`，以便 FRB 回退到原有
/// `ioDirectory` 逻辑——这是测试与开发态不回归的关键。
///
/// [exists] 注入以便单元测试不触碰真实文件系统。
String? resolveBundledRustLibraryPath({
  required String executablePath,
  required String operatingSystem,
  required bool Function(String) exists,
}) {
  final candidate = _bundledLibraryCandidate(executablePath, operatingSystem);
  if (candidate == null) return null;
  return exists(candidate) ? candidate : null;
}

String? _bundledLibraryCandidate(
  String executablePath,
  String operatingSystem,
) {
  switch (operatingSystem) {
    case 'macos':
    case 'ios':
      return p.posix.normalize(
        p.posix.join(
          executablePath,
          '..',
          '..',
          'Frameworks',
          'lib$rustLibraryStem.dylib',
        ),
      );
    case 'windows':
      return p.windows.normalize(
        p.windows.join(
          p.windows.dirname(executablePath),
          '$rustLibraryStem.dll',
        ),
      );
    case 'linux':
      return p.posix.normalize(
        p.posix.join(executablePath, '..', 'lib', 'lib$rustLibraryStem.so'),
      );
    default:
      return null;
  }
}