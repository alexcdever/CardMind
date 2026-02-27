# cardmind

A new Flutter project.

## Documentation Standard

- [Fractal Documentation Standard](docs/standards/documentation.md)

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Build CLI

- Rust 动态库：`dart run tool/build.dart lib [--target <triple>]`
- App：`dart run tool/build.dart app [--platform <platform>]`
- `app` 固定顺序：`lib -> flutter_rust_bridge_codegen generate -> flutter build`
- 不传 `--platform` 时默认构建当前系统可执行平台（macos/linux/windows）
