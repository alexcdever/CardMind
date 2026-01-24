# CardMind Project Specification

> This document defines CardMind's project context, tech stack, and conventions for OpenSpec.

## Project Overview

**CardMind** is an offline-first card note-taking application with P2P sync capabilities.

| Aspect | Details |
|--------|---------|
| **Platform** | Flutter + Rust |
| **Architecture** | Dual-layer (Loro CRDT + SQLite) |
| **Current Phase** | Phase 6R: Spec Coding Refactoring |
| **Status** | MVP v1.0.0 completed |

## Tech Stack

### Frontend
- **Framework**: Flutter 3.x (Dart)
- **State Management**: Provider
- **UI**: Material 3 + Custom design system

### Backend
- **Language**: Rust
- **CRDT Engine**: Loro 1.3.1
- **Cache**: SQLite (rusqlite with FTS5)
- **Bridge**: flutter_rust_bridge
- **P2P**: libp2p (Phase 2)

### Key Technologies
- **ID Format**: UUID v7 (time-ordered)
- **Password Security**: bcrypt + Keyring
- **Peer Discovery**: mDNS

---

## Code Standards

### Rust

| Pattern | Convention | Example |
|---------|------------|---------|
| Functions | `snake_case` | `create_card()` |
| Types | `PascalCase` | `CardStore`, `DeviceConfig` |
| Constants | `SCREAMING_SNAKE_CASE` | `MAX_CARD_LENGTH` |
| Error handling | `Result<T, CardMindError>` with `?` operator | `let card = create_card()?;` |
| Documentation | Full doc comments with examples | `/// Creates a new card` |

**Documentation Example:**
```rust
/// Creates a new card
///
/// # Arguments
/// * `title` - Card title (max 256 chars)
/// * `content` - Card content (Markdown)
///
/// # Returns
/// The created Card
///
/// # Example
/// ```rust
/// let card = create_card("Hello".to_string(), "# Content".to_string())?;
/// ```
```

### Dart/Flutter

| Pattern | Convention | Example |
|---------|------------|---------|
| Functions/Variables | `snake_case` | `create_card()` |
| Classes/Types | `PascalCase` | `CardProvider` |
| Constants | `kCamelCase` | `kMaxCardLength` |
| Widgets | `const` constructors with `Key?` parameter | `MyWidget({Key? key}) : super(key: key);` |
| Async | Always `mounted` check before `setState` | `if (!mounted) return;` |
| Logging | Use provided `logger` instance | `logger.i("Operation completed");` |

**Documentation Example:**
```dart
/// Creates a new card
///
/// Arguments:
/// - [title] - Card title (max 256 chars)
/// - [content] - Card content (Markdown)
///
/// Returns: Created Card
///
/// Example:
/// ```dart
/// final card = await createCard(title: 'Hello', content: '# Content');
/// ```
```

---

## Git Workflow

### Branch Strategy

| Branch | Purpose | Naming |
|--------|---------|--------|
| `master` | Stable releases | - |
| `develop` | Development branch | - |
| `feature/*` | New features | `feature/add-search` |
| `bugfix/*` | Bug fixes | `bugfix/fix-crash` |
| `refactor/*` | Code refactoring | `refactor/pool-model` |

### Commit Convention

```
<type>(<scope>): <subject>

<body (optional)>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring (no behavior change)
- `test`: Test-related
- `docs`: Documentation update
- `chore`: Build/tool/dependency changes
- `style`: Code formatting (no logic change)

**Examples:**
```
feat(p2p): add device discovery via mDNS
fix: resolve SQLite locking issue
refactor: simplify sync filter logic
test: add test for pool edge cases
docs: update API documentation
chore: update dependencies
style: format code
```

### PR Requirements

- [ ] All tests passing (`cargo test` + `flutter test`)
- [ ] Spec coverage: 100% (`dart tool/specs_tool.dart`)
- [ ] Coverage >80%
- [ ] `cargo clippy` clean (0 warnings)
- [ ] `flutter analyze` clean (0 errors)

---

## Testing Requirements

### Coverage
- **Minimum**: >80% for new code
- **Happy path**: Must be tested
- **Error paths**: Must be tested

### Spec Coding (Test = Spec = Documentation)

**Naming Style:**
```rust
// Rust
test("it_should_do_something_when_condition") { ... }

// Dart
test('it_should_do_something_when_condition', () { ... });
```

**Test Location:**
| Test Type | Location |
|-----------|----------|
| Unit tests | `rust/src/*/mod.rs` or `rust/src/*/tests.rs` |
| Integration tests | `rust/tests/` |
| Flutter tests | `flutter test/` |
| Spec tests | `rust/tests/sp_*_spec.rs` |

---

## Data Architecture

```
ALL writes → Loro CRDT (source of truth)
ALL reads → SQLite (query cache)

Flow: User Action → Loro commit → Subscription → SQLite update
```

### Thread Safety
- **API layer**: Thread-local SQLite storage
- **Sharing**: Use `Arc<Mutex<T>>` for async sharing
- **Never**: Share SQLite connections across threads

---

## Naming Conventions

| Pattern | Convention | Example |
|---------|------------|---------|
| Spec IDs | `SP-XXX-XXX` | `SP-SPM-001`, `SP-SYNC-006` |
| Test names | `it_should_xxx_when_yyy()` | `it_should_create_card_with_uuid()` |
| ADRs | `ADR-XXXX` | `ADR-0001`, `ADR-0005` |
| Change IDs | `kebab-case, verb-led` | `add-mdns-toggle`, `refactor-pool-model` |

---

## File Locations

| Content | Location |
|---------|----------|
| **Specs (OpenSpec)** | `openspec/specs/` |
| **Change Proposals** | `openspec/changes/` |
| **ADRs** | `docs/adr/` |
| **Architecture Principles** | `docs/architecture/` |
| **Product Vision** | `docs/requirements/` |
| **User Guide** | `docs/user_guide.md` |
| **UI/UX Design** | `docs/interaction/` |

---

## Communication Protocol

### When Creating Specs
1. Use OpenSpec `### Requirement:` format
2. Include `#### Scenario:` blocks with GIVEN/WHEN/THEN
3. Reference related specs by ID

### When Proposing Changes
1. Use `/openspec:proposal <feature>` or natural language
2. Include acceptance criteria in scenarios
3. Break into implementable tasks

### When Implementing
1. Read `openspec/specs/` for current truth
2. Check `openspec/changes/` for active proposals
3. Update specs via the change workflow

### Task Tracking
- **Use OpenSpec changes**: `openspec/changes/<change>/tasks.md`
- **For backlog items**: GitHub Issues
- **For tracking**: `openspec list` to see active changes

---

## Quick Commands

```bash
# Run tests
cd rust && cargo test                    # Rust tests
flutter test                             # Flutter tests

# Spec validation
dart tool/specs_tool.dart                # Check spec coverage

# Lint & Format
dart tool/fix_lint.dart                  # Auto-fix everything
dart format .                            # Dart format
cd rust && cargo fmt                     # Rust format

# Build
dart tool/generate_bridge.dart           # Regenerate Flutter-Rust bridge
dart tool/build_all.dart                 # Build all platforms

# OpenSpec
openspec list                            # List active changes
openspec validate <change> --strict      # Validate change
```

---

## Documentation Guidelines

### Document Design Philosophy

| Type | Purpose | Lifecycle |
|------|---------|-----------|
| **Requirements** | Business intent (why and what) | Long (months) |
| **Interaction** | User perception (how users feel) | Medium |
| **Architecture** | Technical contracts (system organization) | Long |
| **Code** | Implementation details | Short (auto-generated) |

### Core Principles

1. **Docs don't contain code**
   - Define contracts and interfaces
   - Describe design principles
   - Use pseudo-code to show signatures only
   - Point to `cargo doc` for implementation

2. **Keep specs as truth**
   - OpenSpec specs define "what" and "why"
   - Code implements "how"
   - Tests verify compliance

### Document Locations

| Content | Location |
|---------|----------|
| **Product Vision** | `docs/requirements/product_vision.md` |
| **User Guide** | `docs/user_guide.md` |
| **UI/UX Design** | `docs/interaction/` |
| **Architecture Principles** | `docs/architecture/` |
| **Specs (What)** | `openspec/specs/` |
| **ADRs (Why)** | `docs/adr/` |
| **Change Proposals** | `openspec/changes/` |

---

**Last Updated**: 2026-01-15
