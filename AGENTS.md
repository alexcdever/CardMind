# CardMind AI Agent Guide

## Project Context

**CardMind** = Flutter + Rust offline-first card notes app
- MVP v1.0.0 done
- Currently: Phase 6R - Single Pool Model Refactoring (Spec Coding)
- **Core**: Dual-layer (Loro CRDT → SQLite), P2P sync via libp2p

## Start Here

Read these **before every task**:
1. `TODO.md` - Current work status
2. `docs/architecture/system_design.md` - Architecture
3. `docs/requirements/product_vision.md` - Product vision

## Critical Commands

### Testing (Single Test Focus)
```bash
# Flutter single test named "test name"
flutter test --name "test name"

# Rust single test by name (substring match)
cd rust && cargo test test_name

# Rust specific test file
cd rust && cargo test --test sqlite_test

# Rust specific test within file
cd rust && cargo test --test sqlite_test test_add_and_get_card_pool_binding

# Spec Coding examples
cd rust && cargo test --example single_pool_flow_spec
```

### Lint & Format (Run before EVERY commit)
```bash
# Auto-fix everything (RECOMMENDED)
dart tool/fix_lint.dart

# Or manual commands
dart format .                      # Flutter format
cd rust && cargo fmt               # Rust format
flutter analyze                    # Dart analysis
cd rust && cargo clippy --all-targets --all-features  # Rust lint
```

### Build
```bash
dart tool/generate_bridge.dart      # After Rust API changes
dart tool/build_all.dart           # Build all platforms
dart tool/build_all.dart --android # Android only
```

## Architecture Rules (NEVER BREAK)

**Dual-Layer Architecture:**
1. ALL writes → Loro CRDT (truth source)
2. ALL reads → SQLite cache
3. Mutation flow: `loro_doc.commit()` → persist Loro → subscriptions → SQLite
4. NEVER write SQLite directly (except subscription callbacks)

**Card Storage:**
- Each card = separate LoroDoc at `data/loro/<base64(uuid)>/`
- Use UUID v7 for time-sorting
- Soft deletes only (`deleted: bool`)

**Thread Safety:**
- API layer: thread-local SQLite storage
- Async: share stores via `Arc<Mutex<T>>`
- Never share SQLite connections across threads

**Spec Coding:**
- Tests = Specifications = Documentation
- Test naming: `it_should_do_something()`
- Run examples: `cargo test --example`

## Code Style

### Dart/Flutter
```dart
// Imports: dart:, package:, files (no blank lines between dart: and package:)
import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/card_provider.dart';

// Widgets: const constructor + key parameter
const MyWidget({Key? key}) : super(key: key);

// Async: always guard with mounted check
if (!mounted) return;
setState(() { /* ... */ });

// Use debugPrint() not print()
debugPrint('Error: $error');

// Type annotations for public APIs
Future<List<Card>> getAllCards() async { ... }
```

### Rust
```rust
// Naming: snake_case functions, PascalCase types
pub fn create_card(title: String) -> Result<Card, CardMindError> { ... }

// Errors: always Result<T, CardMindError>, use ? operator
let store = get_store()?;

// Documentation: include Args, Returns, Examples
/// Creates a new card
///
/// # Arguments
/// * `title` - Card title (max 256 chars)

// Clippy limits (from rust/clippy.toml)
// - Max function lines: 100
// - Max cognitive complexity: 30
// - Single-char names: up to 4 allowed
```

## Testing Requirements

**TDD Required (Red → Green → Refactor)**
- Coverage >80% for new code
- Test happy path AND error paths
- Integration tests for critical paths

**Test Commands:**
```bash
# All tests
cd rust && cargo test
flutter test

# Spec validation (NEW 2026-01-14)
dart tool/fix_lint.dart --spec-check
```

## Commit & PR

**Conventional Commits:**
```
feat(p2p): add device discovery via mDNS
fix: resolve SQLite locking issue
refactor: simplify sync filter logic
test: add test for pool edge cases
docs: update API documentation
chore: update dependencies
style: format code
```

**PR Requirements:**
- Tests passing (`cargo test` + `flutter test`)
- Coverage >80%
- `cargo clippy` clean (0 warnings)
- `flutter analyze` clean (0 errors)
- Screenshots for UI changes

## Quick Reference

| Task | Command |
|------|---------|
| **Fix all lint** | `dart tool/fix_lint.dart` |
| **Format only** | `dart format . && cd rust && cargo fmt` |
| **Check only** | `dart tool/check_lint.dart` |
| **Run single test** | `cd rust && cargo test test_name` |
| **Spec examples** | `cd rust && cargo test --example single_pool_flow_spec` |
| **Generate bridge** | `dart tool/generate_bridge.dart` |
| **Full build** | `dart tool/build_all.dart` |
| **Check before commit** | `dart tool/check_lint.dart && cd rust && cargo test && flutter test` |

## Key Files

**Specs:**
- `specs/README.md` - Spec Coding center
- `specs/SPEC_CODING_GUIDE.md` - Implementation guide

**Architecture:**
- `docs/architecture/system_design.md` - Core architecture
- `docs/architecture/data_contract.md` - Data models
- `docs/architecture/sync_mechanism.md` - P2P sync

**Current Focus:**
- Phase 6R: Single Pool Model Refactoring
- Removing multi-pool support
- Simplifying DeviceConfig to single `pool_id: Option<String>`

---

**Last Updated**: 2026-01-14  
**Purpose**: Essential guide for AI agents working in CardMind  
**Rule**: When in doubt → check docs → ask user → follow patterns