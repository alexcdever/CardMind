import 'dart:io';

enum HostPlatform { macos, windows, linux, other }

enum BuildPlatform { android, linux, windows, macos, ios }

HostPlatform detectHostPlatform() {
  if (Platform.isMacOS) {
    return HostPlatform.macos;
  }
  if (Platform.isWindows) {
    return HostPlatform.windows;
  }
  if (Platform.isLinux) {
    return HostPlatform.linux;
  }
  return HostPlatform.other;
}

Set<BuildPlatform> resolveDefaultPlatforms(HostPlatform host) {
  switch (host) {
    case HostPlatform.macos:
      return {BuildPlatform.android, BuildPlatform.ios, BuildPlatform.macos};
    case HostPlatform.windows:
      return {BuildPlatform.windows};
    case HostPlatform.linux:
      return {BuildPlatform.linux};
    case HostPlatform.other:
      return {};
  }
}

Set<BuildPlatform>? parsePlatforms(
  List<String> args,
  HostPlatform host,
) {
  final platforms = <BuildPlatform>{};

  for (final arg in args) {
    switch (arg) {
      case '--android':
        platforms.add(BuildPlatform.android);
        break;
      case '--linux':
        platforms.add(BuildPlatform.linux);
        break;
      case '--windows':
        platforms.add(BuildPlatform.windows);
        break;
      case '--macos':
        platforms.add(BuildPlatform.macos);
        break;
      case '--ios':
        platforms.add(BuildPlatform.ios);
        break;
      default:
        return null;
    }
  }

  if (platforms.isEmpty) {
    platforms.addAll(resolveDefaultPlatforms(host));
  }

  return platforms;
}
