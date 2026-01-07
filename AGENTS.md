# Repository Guidelines

## Project Structure & Key Paths
- Flutter app lives in `lib/` with providers, services, screens, and widgets; integration tests in `test/`.
- Rust core is under `rust/` (APIs in `rust/src/api/`, store logic in `rust/src/store/`, models in `rust/src/models/`).
- Generated bridge code stays in `lib/bridge/api/`; do not edit `*.g.dart`, `*.freezed.dart`, or `frb_generated.dart`.
- Tooling and build scripts are in `tool/`; platform-specific Flutter runners sit in `android/`, `ios/`, `macos/`, `linux/`, and `windows/`.

## Build, Test, and Development Commands
- `dart tool/build_all.dart [--android|--linux]`: Build all targets or a specific platform.
- `flutter test`: Run Flutter tests.
- `cd rust && cargo test` (or `cargo test -- --nocapture`): Run Rust tests with optional verbose output.
- `cd rust && cargo check` and `cargo clippy --all-targets --all-features`: Validate Rust code health.
- `dart tool/check_lint.dart` (read-only) or `dart tool/fix_lint.dart`: Check or auto-fix Dart style.
- Formatters: `dart format .` and `cd rust && cargo fmt`.

## Coding Style & Naming Conventions
- Dart: single quotes by default, prefer `const`, include `key` in widget constructors, use Provider with `ChangeNotifier`, guard async UI updates with `if (!mounted) return;`, log via `debugPrint()`.
- Rust: `snake_case` for functions/variables, `PascalCase` for types, public APIs documented with `///`, errors via `Result<T, CardMindError>`.
- Imports: `dart:` then `package:` (no blank line); Rust modules follow existing folder layout.

## Testing Guidelines
- Test functions use `test_` prefixes in Rust (add `#[serial]` when touching global state) and descriptive names in Flutter.
- Aim for >80% coverage; include clear assertion messages and cover happy/error paths.
- Use `tempfile::TempDir` for file-based Rust integration tests and verify Loro→SQLite sync after writes.

## Commit & Pull Request Guidelines
- Follow conventional commits seen in history (e.g., `feat: ...`, `docs: ...`, scoped forms like `feat(p2p): ...`).
- PRs should describe scope, link issues, include test evidence, and note platform impact; add screenshots for UI changes.

## Security & Data Rules
- Data layer: write via Loro CRDT, read from SQLite; always call `loro_doc.commit()` after mutations and persist Loro files; use soft deletes and UUID v7 IDs; each card lives in `data/loro/<base64(uuid)>/`.
- Keep secrets out of the repo; prefer `.env`/secure storage when needed.
