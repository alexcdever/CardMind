import java.io.ByteArrayOutputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val rustAndroidTarget = "aarch64-linux-android"
val rustProjectDir = rootProject.file("../rust")
val rustJniLibDir = project.file("src/main/jniLibs/arm64-v8a")
val rustJniLibSoPath = project.file("src/main/jniLibs/arm64-v8a/libcardmind_rust.so")
val rustAndroidSo = rustProjectDir.resolve(
    "target/$rustAndroidTarget/release/libcardmind_rust.so"
)

fun resolveAndroidNdkToolchainBin(): String {
    val sdkRoot = System.getenv("ANDROID_SDK_ROOT")
        ?: System.getenv("ANDROID_HOME")
        ?: error("ANDROID_SDK_ROOT or ANDROID_HOME is required for Android Rust build")
    val ndkVersion = android.ndkVersion
    val hostTag = "darwin-x86_64"
    val toolchainBin = file(
        "$sdkRoot/ndk/$ndkVersion/toolchains/llvm/prebuilt/$hostTag/bin"
    )
    check(toolchainBin.exists()) {
        "Android NDK toolchain not found at ${toolchainBin.path}"
    }
    return toolchainBin.absolutePath
}

tasks.register("rustBuildAndroidArm64") {
    group = "build"
    description = "Build Rust Android arm64 shared library and copy it into jniLibs"

    inputs.dir(rustProjectDir)
    outputs.file(rustJniLibSoPath)

    doLast {
        val toolchainBin = resolveAndroidNdkToolchainBin()
        val env = mapOf(
            "CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER" to
                "$toolchainBin/aarch64-linux-android24-clang",
            "CC_aarch64_linux_android" to
                "$toolchainBin/aarch64-linux-android24-clang",
            "AR_aarch64_linux_android" to "$toolchainBin/llvm-ar",
            "CARGO_BUILD_JOBS" to "1",
        )

        val stdout = ByteArrayOutputStream()
        val result = exec {
            workingDir = rustProjectDir
            commandLine("cargo", "build", "--release", "--target", rustAndroidTarget)
            environment(env)
            standardOutput = stdout
            errorOutput = stdout
            isIgnoreExitValue = true
        }
        check(result.exitValue == 0) {
            "Rust Android build failed:\n${stdout.toString(Charsets.UTF_8)}"
        }
        check(rustAndroidSo.exists()) {
            "Rust Android shared library not found at ${rustAndroidSo.path}"
        }

        rustJniLibDir.mkdirs()
        rustAndroidSo.copyTo(
            rustJniLibSoPath,
            overwrite = true,
        )
    }
}

tasks.matching {
    it.name == "mergeDebugJniLibFolders" ||
        it.name == "mergeProfileJniLibFolders" ||
        it.name == "mergeReleaseJniLibFolders"
}.configureEach {
    dependsOn("rustBuildAndroidArm64")
}

android {
    namespace = "com.example.cardmind"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.cardmind"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
