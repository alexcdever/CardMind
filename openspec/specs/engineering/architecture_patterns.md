# Architecture Patterns

> **Purpose**: Define layer separation, dependency rules, and architectural patterns for CardMind Rust backend.

---

## 1. Layer Overview

### 1.1 Layer Structure

```
┌─────────────────────────────────────────┐
│         Flutter UI Layer                │
│  (screens, widgets, providers)          │
└──────────────────┬──────────────────────┘
                   │ Bridge Layer
┌──────────────────┴──────────────────────┐
│         Rust Business Layer             │
│  ┌────────────────────────────────────┐ │
│  │       Service Layer                │ │
│  │  (business logic, validation)      │ │
│  └──────────────┬─────────────────────┘ │
│                 │                        │
│  ┌──────────────┴─────────────────────┐ │
│  │      Repository Layer              │ │
│  │  (data access abstraction)         │ │
│  └──────────────┬─────────────────────┘ │
│                 │                        │
│  ┌──────────────┴─────────────────────┐ │
│  │       Store Layer                  │ │
│  │  (Loro CRDT + SQLite Cache)        │ │
│  └────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### 1.2 Dependency Direction

**Rule**: Dependencies flow downward only.

```
Flutter UI → Bridge → Service → Repository → Store
```

**Prohibited**:
- Store layer calling Service layer (upward dependency)
- Repository layer calling Service layer (upward dependency)
- Service layer directly accessing Store layer (cross-layer dependency)

---

## 2. Repository Layer

### 2.1 Responsibilities

**Core Responsibilities**:
- Isolate data source implementation details
- Provide unified data access interfaces
- Handle data persistence
- Manage data source lifecycle (init, shutdown)

**Not Responsible For**:
- Business rule validation (Service layer)
- Data format conversion (Bridge layer)
- UI logic (Flutter layer)

### 2.2 Interface Contract (Pseudo-code)

```rust
// Pseudo-code showing contract, not actual implementation
trait CardRepository {
    // Create card
    fn create(card: Card) -> Result<Card>;

    // Get by ID
    fn get(id: CardId) -> Result<Option<Card>>;

    // Update card
    fn update(card: Card) -> Result<Card>;

    // Delete card (soft delete)
    fn delete(id: CardId) -> Result<()>;

    // Restore card
    fn restore(id: CardId) -> Result<()>;

    // List query
    fn list(filter: Filter) -> Result<Vec<Card>>;

    // Count
    fn count(filter: Filter) -> Result<usize>;
}
```

### 2.3 Design Guarantees

1. **Idempotency**: All operations produce same result when repeated
2. **Explicit Errors**: Return specific error types, no panics
3. **Isolation**: Don't expose underlying storage details (CRDT, SQL)
4. **Testability**: All methods mockable for unit testing

---

## 3. Service Layer

### 3.1 Responsibilities

**Core Responsibilities**:
- Implement business rules and validation
- Coordinate multiple Repositories
- Handle transaction boundaries
- Provide domain logic encapsulation

**Not Responsible For**:
- Data storage details (Repository layer)
- Cross-language communication (Bridge layer)
- UI state management (Flutter layer)

### 3.2 Business Rules (Examples)

**Card Creation Rules**:
- `content` cannot be empty (at least one space)
- `title` is optional, but if provided, cannot be only whitespace
- Auto-generate UUID v7
- Auto-set `created_at` and `updated_at`

**Card Update Rules**:
- Card must exist (return `CardNotFound` error otherwise)
- `updated_at` must be >= original value after update
- Soft-deleted cards can be updated (editable after restore)

**Card Deletion Rules**:
- Use soft delete (`is_deleted = true`)
- Deleted cards still queryable (via `get_deleted_cards`)
- Deleted cards not in default list

**Pool Binding Rules (Single Pool Model)**:
- Device must have joined a pool (`DeviceConfig.pool_id` exists)
- Card ownership determined by `Pool.card_ids`, not Card document
- Bind/unbind = modify `Pool.card_ids` + `commit()`, subscription callback auto-maintains SQLite
- Leave pool = clear local cards + Pool document + reset `pool_id`

---

## 4. Bridge Layer

### 4.1 Responsibilities

**Core Responsibilities**:
- Type conversion between Dart and Rust
- Error propagation and serialization
- Thread safety (Flutter main thread ↔ Rust thread)

### 4.2 Type Mapping

**Rust → Dart Auto-Conversion**:

| Rust Type | Dart Type |
|-----------|-----------|
| `String` | `String` |
| `i64` | `int` |
| `bool` | `bool` |
| `Vec<T>` | `List<T>` |
| `Option<T>` | `T?` (nullable) |
| `Result<T, E>` | `Future<T>` (async) or `T` (sync) |

---

## 5. Dependency Rules

### 5.1 Dependency Injection

**Principle**: High-level modules depend on abstractions, not implementations.

```rust
// Service layer depends on Repository trait, not concrete implementation
pub struct CardService {
    repo: Box<dyn CardRepository>,
}

impl CardService {
    pub fn new(repo: Box<dyn CardRepository>) -> Self {
        Self { repo }
    }
}

// Concrete implementation injected at initialization
let repo = Box::new(LoroCardRepository::new());
let service = CardService::new(repo);
```

### 5.2 Prohibited Cross-Layer Access

**Prohibited**:
- Bridge layer directly calling Repository layer (skip Service layer)
- Service layer directly accessing Store layer (skip Repository layer)

**Enforced**:
- Repository layer not exposed to Bridge layer
- Store layer (Loro/SQLite) not exposed to Service layer

---

## 6. Common Anti-Patterns

### 6.1 Cross-Layer Access

```rust
// ❌ Bridge layer directly calling Repository
pub fn create_card(title: String, content: String) -> Result<Card> {
    let repo = CardRepository::new();
    repo.create(Card { title, content })
}

// ✅ Correct: Bridge → Service → Repository
pub fn create_card(title: String, content: String) -> Result<Card> {
    let service = CardService::new();
    service.create_card(title, content)
}
```

### 6.2 Business Logic Leakage

```rust
// ❌ Repository layer containing business validation
impl CardRepository {
    fn create(&self, card: Card) -> Result<Card> {
        if card.content.is_empty() {
            return Err(CardMindError::InvalidContent); // Business logic
        }
        // ...
    }
}

// ✅ Correct: Validation in Service layer
impl CardService {
    pub fn create_card(&self, title: String, content: String) -> Result<Card> {
        if content.is_empty() {
            return Err(CardMindError::InvalidContent);
        }
        self.repo.create(Card { title, content })
    }
}
```

---

## 7. Related Specs

- [System Design Principles](../architecture/system_design.md) - Architecture principles
- [Common Types](./common_types_spec.md) - Data type definitions
- [Sync Spec](./sync_spec.md) - Synchronization mechanism

---

**Last Updated**: 2026-01-15
