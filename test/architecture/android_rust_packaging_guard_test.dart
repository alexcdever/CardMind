// input: 读取 Android 构建脚本源码文本，检查 Rust Android so 构建与 jniLibs 打包约束是否存在。
// output: 断言 Android app 必须显式生成并打包 libcardmind_rust.so，防止移动端再次因缺少 native library 启动失败。
// pos: 覆盖 Android Rust 打包主路径的源码守卫测试。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:flutter_test/flutter_test.dart';

import '../support/source_guard.dart';

void main() {
  test('android app build must package rust so for arm64 emulator path', () {
    final appGradle = readSource('android/app/build.gradle.kts');

    expectSourceContains(
      appGradle,
      'rustBuildAndroidArm64',
      fileLabel: 'android/app/build.gradle.kts',
      requirementLabel: 'define rust Android arm64 build task',
    );
    expectSourceContains(
      appGradle,
      'mergeDebugJniLibFolders',
      fileLabel: 'android/app/build.gradle.kts',
      requirementLabel: 'wire rust so generation before debug jni merge',
    );
    expectSourceContains(
      appGradle,
      'src/main/jniLibs/arm64-v8a/libcardmind_rust.so',
      fileLabel: 'android/app/build.gradle.kts',
      requirementLabel: 'copy rust arm64 so into Android jniLibs path',
    );
    expectSourceContains(
      appGradle,
      'aarch64-linux-android',
      fileLabel: 'android/app/build.gradle.kts',
      requirementLabel: 'build Rust for Android arm64 target',
    );
  });
}
