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

Usage: `dart run tool/build.dart <app|lib> [options]`

Commands:

- `app` Build Flutter app
- `lib` Build Rust dynamic library

Options:

- `-h, --help` Show help message
- `app --platform <p>` Set Flutter build platform (`macos|linux|windows`)
- `lib --target <t>` Set Rust target triple for cargo build

Default behavior:

- `app` runs: `lib -> flutter_rust_bridge_codegen generate -> flutter build`
- `app` default platform: current host executable platform (`macos/linux/windows`)
- `lib` default mode: `cargo build --release`

Examples:

- `dart run tool/build.dart app`
- `dart run tool/build.dart app --platform macos`
- `dart run tool/build.dart lib`
- `dart run tool/build.dart lib --target aarch64-apple-darwin`
