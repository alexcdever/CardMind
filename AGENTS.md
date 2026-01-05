# CardMind Agent Guidelines

This file provides essential information for AI agents working on the CardMind codebase.

## Essential Commands

### Build & Quality Checks
```bash
# Build all platforms
dart tool/build_all.dart

# Build specific platform
dart tool/build_all.dart --android
dart tool/build_all.dart --linux

# Check code style (read-only)
dart tool/check_lint.dart

# Auto-fix code style
dart tool/fix_lint.dart

# Regenerate Flutter-Rust bridge
dart tool/generate_bridge.dart
```

### Testing
```bash
# Run all Flutter tests
flutter test

# Run all Rust tests
cd rust && cargo test

# Run single Rust test
cd rust && cargo test test_create_card

# Run all tests in an integration test file
cd rust && cargo test --test card_store_test

# Run tests with output
cd rust && cargo test -- --nocapture

# Run Rust clippy (lint)
cd rust && cargo clippy --all-targets --all-features

# Run cargo check
cd rust && cargo check
```

### Individual Component Commands
```bash
# Format Flutter/Dart code
dart format .

# Format Rust code
cd rust && cargo fmt

# Check Flutter format
dart format --set-exit-if-changed --output=none .

# Check Rust format
cd rust && cargo fmt -- --check
```

## Code Style Guidelines

### Dart/Flutter
- **Quotes**: Use single quotes by default (`'string'`)
- **Const**: Prefer `const` for constructors, literals, and declarations
- **Imports**: Group dart: first, then package: (no blank line between groups)
- **Widgets**: Always include `key` parameter in widget constructors
- **State**: Use Provider for state management with `ChangeNotifier`
- **Private members**: Prefix with underscore (`_cards`, `_isLoading`)
- **Error handling**: Use `try...on Exception catch (e)` pattern
- **Logging**: Use `debugPrint()` instead of `print()` in app code
- **Null handling**: Use `if (!mounted) return;` before async UI updates
- **Return types**: Use nullable returns (Future<T?>) for operations that can fail

Example Provider pattern:
```dart
Future<Card?> createCard(String title, String content) async {
  try {
    _clearError();
    final card = await _cardService.createCard(title, content);
    await loadCards();
    return card;
  } on Exception catch (e) {
    _setError(e.toString());
    return null;
  }
}
```

### Rust
- **Naming**: `snake_case` for functions/variables, `PascalCase` for types/structs
- **Error handling**: Return `Result<T>` with `CardMindError` enum
- **Documentation**: Use `///` for public APIs, `//!` for module docs
- **Examples**: Include Dart code examples in API docs
- **Global state**: Use `static Mutex<Option<Arc<Mutex<T>>>>` for singletons
- **Locking**: Lock pattern: `let store = get_store()?; let mut store = store.lock().unwrap();`
- **CRDT**: Always call `loro_doc.commit()` after modifications
- **IDs**: Use UUID v7 for all identifiers via `uuid::v7()`

Example API function:
```rust
/// Create a new card
///
/// # Arguments
///
/// * `title` - Card title
/// * `content` - Card content
pub fn create_card(title: String, content: String) -> Result<Card> {
    let store = get_store()?;
    let mut store = store.lock().unwrap();
    store.create_card(title, content)
}
```

### Data Layer Rules (Critical)
1. ✅ ALL writes go to Loro CRDT (never SQLite directly)
2. ✅ ALL reads come from SQLite (fast cached queries)
3. ✅ Loro commits trigger subscriptions → update SQLite
4. ✅ ALWAYS call `loro_doc.commit()` after modifications
5. ✅ ALWAYS persist Loro files after commits
6. ✅ Use soft delete: set `deleted = true` instead of physical deletion
7. ✅ Use UUID v7 for all IDs (time-ordered, conflict-free)
8. ✅ Each card = one LoroDoc file at `data/loro/<base64(uuid)>/`

## Testing Guidelines

### TDD Methodology
- Write tests FIRST: Red (fail) → Green (pass) → Refactor
- Test functions start with `test_` and describe what they test
- Include descriptive assertion messages
- Test coverage must exceed 80%

### Rust Tests
```rust
#[test]
#[serial]  // Use serial_test for tests modifying global state
fn test_create_card_api() {
    let _temp = init_test_store();  // Helper for setup
    let result = create_card("Test".to_string(), "Content".to_string());
    assert!(result.is_ok(), "Should create card successfully");
    cleanup_store();  // Helper for teardown
}
```

### Integration Tests
- Use `tempfile::TempDir` for file-based tests
- Test both happy path and error cases
- Verify Loro→SQLite sync on create/update/delete
- Test persistence across store instances

## File Organization

```
rust/src/
  api/           # flutter_rust_bridge exposed functions
  models/        # Data structures (Card, Error)
  p2p/           # P2P networking (libp2p)
  security/      # Keyring, password hashing
  store/         # CardStore, dual-layer logic
  utils/         # UUID v7, helpers

lib/
  bridge/api/    # Generated bridge APIs
  providers/     # State management (Provider)
  screens/       # UI screens
  services/      # Business logic layer
  widgets/       # Reusable widgets
```

## Common Patterns

### Bridge Function Generation
After modifying Rust APIs, run:
```bash
dart tool/generate_bridge.dart
```

### Performance Targets
- Card creation: < 50ms (achieved: 2.7ms)
- Card update: < 50ms (achieved: 4.6ms)
- 1000 cards load: < 1s (achieved: 329ms)
- SQLite query: < 10ms (achieved: < 4ms)

## Quality Gates

Before committing, ensure:
```bash
# All checks pass
dart tool/check_lint.dart  # Exits 0 if OK

# Or manually verify:
flutter analyze          # Must pass
cd rust && cargo check   # Must pass
cd rust && cargo clippy  # Zero warnings
```

## Notes
- Never edit generated files: `*.g.dart`, `*.freezed.dart`, `frb_generated.dart`
- Use `// ignore_for_file: avoid_print` only in tool scripts
- Chinese comments are acceptable in code (bilingual project)
- Documentation lives in code (Rust doc comments), not markdown
- Run `cd rust && cargo doc --open` to view API documentation
