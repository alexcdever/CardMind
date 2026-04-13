String resolveIosRustDylibPath({
  required String projectDir,
  required String platformName,
}) {
  final rootDir = projectDir.endsWith('/ios')
      ? projectDir.substring(0, projectDir.length - 4)
      : projectDir;
  final targetDir = platformName == 'iphonesimulator'
      ? 'aarch64-apple-ios-sim'
      : 'aarch64-apple-ios';
  return '$rootDir/rust/target/$targetDir/release/libcardmind_rust.dylib';
}
