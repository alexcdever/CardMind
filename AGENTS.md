# CardMind Repository Guidelines for AI Agents

## Project Context

CardMind: Flutter + Rust offline-first card notes app (MVP v1.0.0 done; P2P sync shipped; future: search/tags/import-export).

**Start every task by reading:**
- `TODO.md` - current work status
- `docs/architecture/system_design.md` - system architecture
- `docs/requirements/product_vision.md` - product vision
- Use `TodoWrite` to track work status

## Project Structure

```
lib/                    - Flutter UI/logic (providers, services, screens, widgets)
  bridge/              - Generated bridge code (NEVER EDIT manually)
    api/               - Generated API bindings
    models/            - Generated models
rust/                  - Rust core logic
  src/
    api/               - API layer (Flutter bridge functions)
    models/            - Data models
    store/             - Storage layer (Loro + SQLite)
    p2p/               - P2P networking (libp2p)
tool/                  - Build and development scripts
test/                  - Flutter tests
```

**Never edit generated files:** `*.g.dart`, `*.freezed.dart`, `frb_generated.dart`

## Build Commands

### Quick Lint & Format (Run before EVERY commit)

```bash
# Auto-fix everything (recommended before committing)
dart tool/fix_lint.dart

# Just check without fixing
dart tool/check_lint.dart

# Manual individual commands
dart format .                      # Format Dart code
cd rust && cargo fmt               # Format Rust code
flutter analyze                    # Flutter static analysis
cd rust && cargo check             # Rust compile check
cd rust && cargo clippy --all-targets --all-features  # Rust linting
```

### Testing

```bash
# Flutter tests
flutter test                       # Run all Flutter tests
flutter test test/widget_test.dart # Run single test file
flutter test --name "test name"    # Run tests matching name

# Rust tests
cd rust && cargo test              # Run all Rust tests
cd rust && cargo test test_name    # Run single test by name (substring match)
cd rust && cargo test --test sqlite_test  # Run specific test file
cd rust && cargo test --test sqlite_test test_add_and_get_card_pool_binding  # Run specific test in file

# Integration tests
cd rust && cargo test --test sync_integration_test  # P2P sync tests
cd rust && cargo test --test sqlite_test           # Database tests
```

### Building

```bash
# Generate bridge code (after Rust API changes)
dart tool/generate_bridge.dart

# Build for specific platforms
dart tool/build_all.dart                    # Build all platforms
dart tool/build_all.dart --android         # Android only
dart tool/build_all.dart --linux --debug   # Linux debug build
dart tool/build_all.dart --clean           # Clean build artifacts
```

### Full Quality Check

```bash
# Complete verification before PR
cd rust && cargo test                    # All Rust tests
flutter test                             # All Flutter tests
dart tool/check_lint.dart                # All linting checks
cd rust && cargo doc --open              # Generate Rust docs
```

## Architecture Rules (NEVER Break These)

1. **Dual-Layer Architecture:**
   - ALL writes go to Loro CRDT (truth source)
   - ALL reads come from SQLite cache
   - After any mutation: `loro_doc.commit()` → persist Loro → subscriptions update SQLite
   - NEVER write SQLite directly (except in subscription callbacks)

2. **Card Storage:**
   - Each card = separate LoroDoc at `data/loro/<base64(uuid)>/`
   - Use UUID v7 for time-sorting
   - Soft deletes only (`deleted: bool` flag)

3. **Thread Safety:**
   - API layer uses thread-local storage for SQLite
   - Share stores via `Arc<Mutex<T>>` in async contexts
   - Never share SQLite connections across threads

## Code Style Guidelines

### Dart / Flutter

**Imports:**
```dart
// CORRECT - No blank lines between dart: and package:
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// File imports after packages
import '../providers/card_provider.dart';

// NEVER use: import '../bridge/frb_generated.dart' directly
```

**Widget Patterns:**
```dart
// ALWAYS include key parameter, use const constructors
const MyWidget({Key? key}) : super(key: key);

// Guard async operations
if (!mounted) return;
setState(() { /* ... */ });

// Use debugPrint() not print()
debugPrint('Error: $error');
```

**Type Safety:**
```dart
// Prefer final and const over var
final String title = 'Hello';
const int maxCards = 100;

// Avoid dynamic
// WRONG: var result = api.call();
// RIGHT: final Card result = await api.getCard(id);

// Use type annotations for public APIs
Future<List<Card>> getAllCards() async { ... }
```

**Naming:**
- `camelCase` for variables, functions, parameters
- `PascalCase` for classes, enums, typedefs
- `SCREAMING_SNAKE_CASE` for constants
- Private members start with `_`

**Error Handling:**
```dart
try {
  final card = await api.getCard(id);
  return card;
} catch (e) {
  debugPrint('Failed to load card: $e');
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('加载失败: $e')),
  );
}
```

### Rust

**Naming:**
- `snake_case` for functions, variables, modules
- `PascalCase` for types (structs, enums, traits)
- `SCREAMING_SNAKE_CASE` for constants
- Methods: `snake_case`

**Error Handling (MANDATORY):**
```rust
// Always use Result<T, CardMindError>
pub fn create_card(title: String) -> Result<Card, CardMindError> {
    // ...
}

// Use ? operator
let store = get_store()?;
let mut store = store.lock().unwrap();

// Pattern match don't unwrap
match result {
    Ok(card) => card,
    Err(e) => {
        error!("创建卡片失败: {:?}", e);
        return Err(e);
    }
}
```

**Documentation:**
```rust
/// Creates a new card with the given title and content
///
/// # Arguments
/// * `title` - Card title (max 256 chars)
/// * `content` - Markdown content
///
/// # Returns
/// * `Ok(Card)` - Newly created card
/// * `Err(CardMindError)` - If creation fails
///
/// # Examples
/// ```
/// let card = create_card("Note".to_string(), "Content".to_string())?;
/// ```
pub fn create_card(title: String, content: String) -> Result<Card> { ... }
```

**Types:**
- Prefer strong typing over primitives
- Use `Uuid` type, not String for IDs
- Use `chrono::DateTime` for timestamps
- Wrap primitive types in newtypes when meaningful

**Module Organization:**
```rust
// Inside rust/src/
mod models {     // Data structures
    pub mod card;
    pub mod pool;
    pub mod device_config;
}

mod store {      // Storage operations
    pub mod card_store;
    pub mod pool_store;
}

mod api {        // Flutter bridge APIs
    pub mod card;
    pub mod pool;
}

mod p2p {        // Networking
    pub mod network;
    pub mod sync;
}
```

**Clippy Rules (from clippy.toml):**
- Max function lines: 100
- Max cognitive complexity: 30
- Allow single-char names: up to 4
- Doc-valid-idents: `["CardMind", "SQLite", "Loro", "CRDT", "UUID"]`

## Testing Requirements (MANDATORY)

**TDD Required:**
1. Write test first (Red)
2. Write minimal code to pass (Green)
3. Refactor (Refactor)

**Coverage:**
- >80% test coverage for all new code
- Cover happy path AND error paths
- Integration tests for critical paths

**Test Organization:**
```rust
// Unit tests in same file
#[cfg(test)]
mod tests {
    #[test]
    fn test_feature_x_works() { /* ... */ }
    
    #[test]
    #[should_panic(expected = "error message")]
    fn test_feature_x_fails_with_invalid_input() { /* ... */ }
}

// Integration tests in tests/ directory
// tests/integration_test.rs
#[tokio::test]
async fn test_full_sync_flow() { /* ... */ }
```

## Commit & PR Guidelines

**Conventional Commits:**
```
feat(p2p): add device discovery via mDNS
fix: resolve SQLite locking issue in CardStore
refactor: simplify sync filter logic
test: add test for pool membership edge cases
docs: update API documentation for card creation
chore: update dependencies
style: format code
```

**PR Requirements:**
- Link to issue/scope
- Tests passing (`cargo test` + `flutter test`)
- Coverage >80%
- `cargo clippy` clean
- `flutter analyze` clean
- Screenshots for UI changes
- Update docs if needed

## Quick Command Reference

```bash
# Before starting work
dart tool/check_lint.dart              # Verify clean state
git pull                               # Get latest changes

# Development loop
dart tool/fix_lint.dart                # Auto-fix issues
flutter test                           # Run Flutter tests
cd rust && cargo test                  # Run Rust tests

# Bridge changes
dart tool/generate_bridge.dart         # After Rust API changes

# Before commit
dart tool/check_lint.dart              # Final verification
git status                             # Review changes

# Build for release
dart tool/build_all.dart --clean       # Clean build
dart tool/build_all.dart               # Release build
```

## Security & Data Rules

- Keep secrets out of repo (.env, credentials.json)
- Use system Keychain/KeePass for passwords
- Never log sensitive data
- Preserve offline-first assumptions
- Never bypass CRDT/Loro persistence flow

## Documentation Standards

**Use docs as source of truth:**
- Design/architecture docs → What/Why
- Code + `cargo doc --open` → How

**Key docs to reference:**
- `README.md` - Project overview
- `docs/architecture/system_design.md` - Architecture
- `docs/requirements/product_vision.md` - Product vision
- `TODO.md` - Current tasks
- `docs/roadmap.md` - Milestones
- `docs/implementation/testing_guide.md` - Testing
- `tool/BUILD_GUIDE.md` - Build details
- `docs/implementation/logging.md` - Logging

## Skills & Sub-agents

**Available skills (in `~/.codex/skills/`):**
- `skill-creator` - Create new skills
- `skill-installer` - Install skills from repos

**When using skills:**
1. Open SKILL.md (only what's needed)
2. Follow provided workflow
3. Prefer included scripts/templates
4. Keep context minimal

**Agent delegation:**
- Use `frontend-ui-ux-engineer` for UI-heavy tasks
- Use `oracle` for architecture decisions
- Use `librarian` for external library research
- Use `explore` for codebase pattern mining

---

**Last Updated**: Generated from analysis of analysis_options.yaml, clippy.toml, and tool scripts
**Purpose**: Guide for AI agents working in this repository
**Rule**: When in doubt, check docs → ask user → follow existing patterns