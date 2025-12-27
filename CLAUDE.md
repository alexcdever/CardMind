# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CardMind is a card-based note-taking application with offline-first design and P2P sync capabilities. The project uses Flutter for UI, Rust for core business logic, Loro CRDT as the source of truth, and SQLite as a query cache layer.

**Current Status**: Planning phase - documentation complete, implementation pending.

## Core Architecture

### Dual-Layer Data Architecture

The application uses an innovative dual-layer data architecture:

1. **Loro CRDT (Source of Truth)**:
   - All write operations go through Loro
   - File-based persistence (loro_doc.loro)
   - Provides automatic conflict resolution via CRDT
   - Subscription mechanism triggers updates to SQLite

2. **SQLite (Query Cache Layer)**:
   - Read-only cache synchronized from Loro via subscriptions
   - Optimized for fast queries, listing, and full-text search
   - Never written to directly by application code
   - Can be rebuilt from Loro at any time

### Data Flow

```
Write Path:
User Action → Loro Document → loro.commit() → Subscription Callback → Update SQLite → Persist Loro to File

Read Path:
User Query → SQLite Cache → Fast Response

Sync Path (Phase 2):
Device A Loro → Export Updates → P2P (libp2p) → Import Updates → Device B Loro → Update SQLite
```

## Technology Stack

- **Frontend**: Flutter 3.x (Dart)
- **Business Logic**: Rust
- **CRDT Engine**: Loro (file persistence)
- **Cache Layer**: SQLite with rusqlite
- **Bridge**: flutter_rust_bridge
- **P2P Sync**: libp2p (Phase 2)
- **ID Generation**: UUID v7 (time-ordered, conflict-free)

## Development Commands

**Note**: This project is currently in the planning phase. Once implementation begins, commands will be added here. Based on the documentation, expected commands include:

### Rust Development
```bash
# Run Rust tests
cd rust && cargo test

# Run Rust tests with coverage
cd rust && cargo tarpaulin --out Xml

# Build Rust library
cd rust && cargo build

# Run specific test
cd rust && cargo test test_name
```

### Flutter Development
```bash
# Generate bridge code
flutter_rust_bridge_codegen generate

# Run Flutter app
flutter run

# Run Flutter tests
flutter test

# Build for specific platform
flutter build apk          # Android
flutter build ios          # iOS
flutter build windows      # Windows
flutter build macos        # macOS
flutter build linux        # Linux
```

### Code Generation
```bash
# Generate Rust-Dart bridge (will be defined in generate_bridge.sh)
./generate_bridge.sh
```

### Static Analysis (Run Before Committing)
```bash
# Dart/Flutter static analysis
flutter analyze

# Rust static analysis
cd rust && cargo check
cd rust && cargo clippy --all-targets --all-features

# Both should pass with zero warnings before committing
```

## Development Workflow

### Before Requesting Code Review or AI Assistance
1. **Run static checks first**:
   ```bash
   flutter analyze  # Must pass
   cargo check      # Must pass
   cargo clippy     # Should have zero warnings
   ```

2. **Run relevant tests**:
   ```bash
   cargo test                    # Run all Rust tests
   cargo test test_name          # Run specific test
   flutter test                  # Run all Flutter tests
   ```

3. **Only seek help if**:
   - Static checks fail with unclear errors
   - Tests fail unexpectedly
   - Need architectural guidance

### When Requesting Code Changes from AI
- Share the exact error message from `cargo check`, `clippy`, or `flutter analyze`
- Specify which test is failing and include the test output
- Prefer targeted fixes over general "improvements"

### Flutter-Rust Bridge Communication

The project uses `flutter_rust_bridge` to connect Dart and Rust. Key patterns:

**Rust side (api/card.rs)**:
```rust
// Expose functions with simple types
#[flutter_rust_bridge::frb(sync)]
pub fn create_card(title: String, content: String) -> Result<Card, CardMindError> {
    // Implementation
}
```

**Dart side (services/card_service.dart)**:
```dart
// Wrapper around generated bridge code
class CardService {
  Future<Card> createCard(String title, String content) async {
    return await api.createCard(title: title, content: content);
  }
}
```

**Bridge files are auto-generated** - never edit them manually:
- `lib/bridge/bridge_generated.dart`
- `rust/src/frb_generated.rs`
- These files are excluded in `.claudeignore`

## Key Design Principles

### 1. Loro is the Single Source of Truth
- **ALL write operations** must go through Loro
- Never write directly to SQLite - it's read-only
- SQLite is automatically updated via Loro's subscription mechanism
- Data consistency is guaranteed by Loro CRDT

### 2. Test-Driven Development (TDD)
- **Always** write tests before implementation
- Follow Red-Green-Refactor cycle:
  1. **Red**: Write failing test
  2. **Green**: Write minimal code to pass
  3. **Refactor**: Improve code while keeping tests green
- Target: >80% test coverage for all new code
- Integration tests must cover core data flows (Loro ↔ SQLite sync)

### 3. Subscription-Based Sync
The Loro-to-SQLite sync is implemented via subscription callbacks:
```rust
// When Loro document is modified and committed:
loro_doc.commit() → triggers subscription → sync_to_sqlite(event)
```
Any changes to the data layer must respect this flow.

### 4. UUID v7 for IDs
- Use `Uuid::now_v7()` for all card IDs
- Time-ordered property enables chronological sorting
- Distributed generation without conflicts
- Perfect for CRDT scenarios

## Critical Implementation Notes

### Working with Card Data

1. **Creating Cards**:
   - Generate UUID v7 ID
   - Insert into Loro LoroMap structure
   - Call `loro_doc.commit()` to trigger sync
   - Persist Loro file to disk
   - SQLite updates automatically via subscription

2. **Reading Cards**:
   - Always read from SQLite cache (fast)
   - Use appropriate indexes for queries
   - Loro is for writes, SQLite is for reads

3. **Updating Cards**:
   - Modify Loro document
   - Call `loro_doc.commit()`
   - SQLite updates automatically
   - Persist Loro file

4. **Deleting Cards**:
   - Delete from Loro document
   - Call `loro_doc.commit()`
   - SQLite updates automatically

### Data Consistency

- If SQLite becomes corrupted, rebuild from Loro (full_sync_to_sqlite)
- SQLite is disposable - Loro file is the only critical data
- Backup strategy: only backup loro_doc.loro (SQLite can be regenerated)

### Error Handling

- Use `thiserror` for error types
- Always use `Result<T, CardMindError>` return types
- Implement proper error propagation with `?` operator
- Log errors with `tracing` crate

### Performance Targets

- Card creation: <50ms
- SQLite list query: <10ms (1000 cards)
- Loro commit: <50ms
- Loro-to-SQLite sync: <5ms per record
- App launch: <2 seconds
- List loading: <1 second (1000 cards)

## Project Structure

### Rust Layer (rust/src/)
```
rust/src/
├── lib.rs                 # Library entry point
├── api/                   # Flutter-exposed API
│   ├── mod.rs
│   └── card.rs           # Card CRUD APIs
├── store/                 # Data storage layer
│   ├── mod.rs
│   ├── card_store.rs     # Loro + SQLite manager
│   └── subscription.rs   # Loro subscription mechanism
├── models/                # Data models
│   ├── mod.rs
│   └── card.rs
└── utils/
    └── uuid_v7.rs        # UUID v7 generation
```

### Flutter Layer (lib/)
```
lib/
├── main.dart
├── models/               # Dart data models
│   └── card.dart
├── services/             # Rust API wrappers
│   └── card_service.dart
├── providers/            # State management (Provider)
│   └── card_provider.dart
├── screens/              # UI screens
│   ├── home/
│   ├── card_editor/
│   └── settings/
├── widgets/              # Reusable widgets
└── bridge/               # Rust bridge (auto-generated)
    └── bridge_generated.dart
```

## Development Phases

### Phase 1: MVP (Current Target)
- Card CRUD operations
- Loro CRDT integration with file persistence
- SQLite cache layer with subscription sync
- Basic Flutter UI with Markdown support

### Phase 2: P2P Sync
- libp2p integration
- Device discovery (mDNS/DHT)
- CRDT-based synchronization
- Automatic conflict resolution

### Phase 3: Enhancement
- Full-text search (SQLite FTS5)
- Performance optimization
- Tag system (optional)
- Import/Export functionality

## Testing Strategy

### Unit Tests
- Test individual functions in isolation
- Mock external dependencies
- Focus on business logic correctness

### Integration Tests
- **Critical**: Test Loro-to-SQLite sync mechanism
- Test complete CRUD flows
- Verify data consistency between layers

### Example Test Pattern
```rust
#[test]
fn test_card_creation_syncs_to_sqlite() {
    let mut store = CardStore::new_in_memory().unwrap();

    // Create card (writes to Loro)
    let card = store.create_card("Title", "Content").unwrap();

    // Verify SQLite was updated via subscription
    let cards = store.get_all_cards().unwrap();
    assert_eq!(cards.len(), 1);
    assert_eq!(cards[0].id, card.id);
}
```

## Important Constraints

1. **Never bypass Loro for writes** - all modifications must go through Loro's CRDT
2. **SQLite is read-only from app perspective** - only subscription callbacks write to it
3. **Always commit Loro changes** - `loro_doc.commit()` must be called to trigger subscriptions
4. **Persist after commits** - save Loro file to disk after modifications
5. **Use UUID v7** - not v4, v5, or other versions
6. **Follow TDD** - write tests before implementation
7. **Keep test coverage >80%** - this is a hard requirement

## Common Pitfalls to Avoid

1. Writing directly to SQLite (breaks architecture)
2. Forgetting to call `loro_doc.commit()` (subscriptions won't trigger)
3. Using UUID v4 instead of UUID v7 (loses time-ordering)
4. Not persisting Loro file after modifications
5. Reading from Loro for queries (use SQLite instead)
6. Implementing features not in the roadmap (scope creep)

## References

See the comprehensive documentation in [docs/](docs/):
- [PRD.md](docs/PRD.md) - Product requirements and features
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Detailed technical architecture
- [DATABASE.md](docs/DATABASE.md) - Database design and data flow
- [ROADMAP.md](docs/ROADMAP.md) - Development phases and timeline
- [API.md](docs/API.md) - API interface definitions
- [TESTING_GUIDE.md](docs/TESTING_GUIDE.md) - TDD guide and testing strategy
- [LOGGING.md](docs/LOGGING.md) - Logging best practices
