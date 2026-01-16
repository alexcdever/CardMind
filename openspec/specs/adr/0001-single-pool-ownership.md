# ADR-0001: Single Pool Ownership Model

**Status**: Accepted  
**Date**: 2026-01-09  
**Deciders**: @alexc

---

## Context

CardMind is designed for **individual users** with multiple devices:
- Personal note-taking across devices (phone, tablet, computer)
- P2P decentralized sync without central servers
- Offline-first, data completely self-owned

### Problem Background

**Previous Design** allowed cards to belong to multiple pools:
```rust
Card {
    id: String,
    pool_ids: Vec<String>,  // Card could belong to multiple pools
}

DeviceConfig {
    joined_pools: Vec<String>,
    resident_pools: Vec<String>,
}
```

### Issues Identified

1. **Removal propagation fails**: When a device removes a card from a pool, devices that only joined that pool never receive the removal event because SyncFilter excludes cards not belonging to their pools.

2. **Over-engineering**: Multiple pools don't align with the "personal notes" use case. One user = one note space = one pool.

3. **Complexity**: Managing pool relationships, switches, and sync filters adds unnecessary complexity.

---

## Decision

**Adopt Single Pool Ownership Model**:
- Each **card** belongs to exactly **one** pool
- Each **device** can join **multiple** pools (for syncing with others)
- Each device has exactly **one resident pool** (where new cards are created)

### Requirement: Card Pool Association

A card SHALL belong to exactly one pool at any given time.

#### Scenario: Create card in resident pool
- GIVEN a device has a resident pool set
- WHEN a user creates a new card
- THEN the card SHALL automatically belong to the resident pool
- AND the card SHALL be added to the pool's card list

#### Scenario: Remove card from pool
- GIVEN a card belongs to a pool
- WHEN a device removes the card from the pool
- THEN the removal event SHALL propagate to all devices in that pool
- AND all devices SHALL receive the removal notification

### Requirement: Device Pool Membership

A device MAY join multiple pools for syncing purposes.

#### Scenario: Join first pool
- GIVEN a device has no joined pools
- WHEN a user joins a pool with a valid password
- THEN the device SHALL add the pool to its joined_pools list
- AND sync SHALL begin for that pool

#### Scenario: Reject joining second pool when already joined
- GIVEN a device has already joined a pool
- WHEN a user attempts to join a second pool
- THEN the system SHALL reject the request
- AND return an error indicating single-pool constraint violation

---

## Alternatives Considered

| Alternative | Why Rejected |
|-------------|--------------|
| Multiple pool membership per device | Complex sync semantics, removal propagation issues |
| Cards belonging to multiple pools | Data duplication, sync complexity |
| No pool concept at all | Can't support privacy isolation between users |

---

## Consequences

### Benefits
- Simple mental model: one user = one pool
- Reliable sync semantics (removals always propagate)
- Reduced implementation complexity

### Drawbacks
- Users cannot categorize notes into multiple pools
- Switching between "contexts" requires leaving/joining pools

---

**Related Specs**: SP-SPM-001 (Single Pool Model Core)  
**Related Documents**: [System Design](../../docs/architecture/system_design.md)
