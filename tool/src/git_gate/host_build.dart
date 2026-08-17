/// 跨平台 host runtime 库构建产物同步（纯 Dart，深度模块）。
///
/// 本模块替代 gate 内对 `tool/build.dart lib` 的调用：tool/build.dart 的
/// `_runLib`/`_cargoDylibPath` 硬编码查找
/// `rust-backend/target/release/libcardmind_backend.dylib` 并复制到 macOS 路径
/// `build/native/macos/libcardmind_rust.dylib`，Windows 下 cargo 产出的是
/// `cardmind_backend.dll`，因此 Windows 上 `dart tool/build.dart lib` 必失败。
///
/// 本模块只负责把 `cargo build --release` 的产物（host 动态库）同步到各平台
/// 运行态路径（真实文件复制）。外部步骤（cargo build 本身）仍由 runner 的
/// 3 分钟硬超时保护；本模块的同步是 Dart 进程内文件操作，不走 runner。
library;

import 'dart:io';

/// 受支持的 host 构建平台。
enum HostBuildPlatform { windows, macos, linux }

/// 检测当前 host 平台；仅支持 Windows/macOS/Linux，其它平台抛 UnsupportedError。
HostBuildPlatform detectHostPlatform() {
  if (Platform.isWindows) return HostBuildPlatform.windows;
  if (Platform.isMacOS) return HostBuildPlatform.macos;
  if (Platform.isLinux) return HostBuildPlatform.linux;
  throw UnsupportedError('仅支持 Windows/macOS/Linux host 平台，当前不受支持');
}

/// host runtime 库规格：cargo 产物相对路径 + 运行态目标相对路径。
class HostRuntimeSpec {
  const HostRuntimeSpec({
    required this.platform,
    required this.cargoSourceRel,
    required this.runtimeDestRel,
  });

  final HostBuildPlatform platform;

  /// cargo build --release 产物路径（相对仓库根，POSIX 风格）。
  final String cargoSourceRel;

  /// 运行态目标路径（相对仓库根，POSIX 风格）。
  final String runtimeDestRel;
}

/// 各平台 host runtime 库路径（crate name 为 `cardmind-backend`，
/// FRB stem 为 `cardmind_backend`，见 lib/src/rust/frb_generated.dart）。
HostRuntimeSpec hostRuntimeSpec(HostBuildPlatform platform) {
  switch (platform) {
    case HostBuildPlatform.windows:
      return const HostRuntimeSpec(
        platform: HostBuildPlatform.windows,
        cargoSourceRel: 'rust-backend/target/release/cardmind_backend.dll',
        runtimeDestRel: 'build/windows/x64/runner/Release/cardmind_backend.dll',
      );
    case HostBuildPlatform.macos:
      return const HostRuntimeSpec(
        platform: HostBuildPlatform.macos,
        cargoSourceRel: 'rust-backend/target/release/libcardmind_backend.dylib',
        runtimeDestRel: 'build/native/macos/libcardmind_backend.dylib',
      );
    case HostBuildPlatform.linux:
      return const HostRuntimeSpec(
        platform: HostBuildPlatform.linux,
        cargoSourceRel: 'rust-backend/target/release/libcardmind_backend.so',
        runtimeDestRel:
            'build/linux/x64/release/bundle/lib/libcardmind_backend.so',
      );
  }
}

/// 把 cargo 产物复制到运行态路径（真实文件操作）。
///
/// 路径拼接用 `repoRoot.replaceAll(r'\', '/') + '/' + rel`（Dart File 在
/// Windows 接受正斜杠）。返回 null 表示成功；失败返回含源绝对路径的错误串。
String? syncHostRuntimeLibrary(String repoRoot, HostBuildPlatform platform) {
  final spec = hostRuntimeSpec(platform);
  final root = repoRoot.replaceAll(r'\', '/');
  final srcAbs = '$root/${spec.cargoSourceRel}';
  final destAbs = '$root/${spec.runtimeDestRel}';
  final src = File(srcAbs);
  if (!src.existsSync()) {
    return 'cargo 产物不存在: $srcAbs';
  }
  try {
    final dest = File(destAbs);
    dest.parent.createSync(recursive: true);
    if (dest.existsSync()) {
      dest.deleteSync();
    }
    src.copySync(destAbs);
  } on FileSystemException catch (e) {
    return 'host runtime 库同步失败: ${e.message} ($srcAbs → $destAbs)';
  }
  return null;
}
