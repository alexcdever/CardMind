# ADR-0002: Dual-Layer Architecture
# ADR-0002：双层架构

**Status**: Accepted  
**Date**: 2024-12-31  
**Deciders**: CardMind Team

---

## Context | 上下文

CardMind's data layer must balance two core requirements:
1. **Distributed Sync**: Multi-device P2P sync, offline editing, automatic conflict resolution
2. **Query Performance**: Fast queries, index optimization, full-text search

---

## Decision | 决策

**Adopt Dual-Layer Architecture**:

```
┌─────────────────────────────────────────┐
│           Application Layer (Flutter)   │
└─────────────────┬───────────────────────┘
                  │
         ┌────────┴─────────┐
         │                  │
         ▼                  ▼
┌─────────────────┐  ┌─────────────────┐
│  Write Layer    │  │  Read Layer     │
│  Loro CRDT      │──│  SQLite         │
└─────────────────┘  └─────────────────┘
         │                  ▲
         │                  │
         └──────Subscribe──┘
```

**Core Principles**:
- ALL writes → Loro CRDT (source of truth)
- ALL reads → SQLite (query cache)
- Subscription-driven: Loro commit → callback → SQLite update

### Requirement: Write Path

The system SHALL route all write operations through the Loro CRDT layer.

#### Scenario: Create card
- GIVEN a user action to create a card
- WHEN the system processes the request
- THEN the data SHALL be written to Loro CRDT
- AND the Loro document SHALL be committed
- AND the subscription callback SHALL update SQLite

#### Scenario: Update card
- GIVEN a user action to update a card
- WHEN the system processes the request
- THEN the Loro document SHALL be modified
- AND the document SHALL be committed
- AND SQLite SHALL be updated via subscription

### Requirement: Read Path

The system SHALL route all read operations through the SQLite cache.

#### Scenario: Query cards list
- GIVEN a request to list all cards
- WHEN the system processes the request
- THEN the query SHALL execute against SQLite
- AND return results from the cache
- AND never query Loro directly

#### Scenario: Search cards
- GIVEN a search query for card content
- WHEN the system processes the request
- THEN the FTS5 full-text search SHALL execute on SQLite
- AND return matching card IDs

---

## Technical Details | 技术细节

### Loro CRDT Layer (Write) | Loro CRDT 层（写入）

**Responsibilities**:
- Receive all write operations
- Ensure data consistency
- Support distributed editing
- Automatic conflict resolution
- File persistence
- Trigger change notifications

### SQLite Layer (Read)

**Responsibilities**:
- Respond to all query requests
- Provide fast list queries
- Support full-text search (FTS5)
- Enable indexing and sorting
- Mirror Loro data via subscriptions

---

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| Loro only | Poor query performance, no full-text search |
| SQLite only | No CRDT sync, no conflict resolution |
| Redis cache | No persistence guarantee, no CRDT |

---

**Related Documents**: [System Design](../../docs/architecture/system_design.md)
