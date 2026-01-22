# ADR-0003: Technology Constraints

**Status**: Accepted  
**Date**: 2024-12-31  
**Deciders**: CardMind Team

---

## Overview

This document records CardMind's core technology stack decisions.

---

## 1. CRDT: Loro

### Context

Need offline multi-device editing, automatic merge on reconnection, decentralized sync, data never lost.

### Decision

**Use Loro CRDT** as the data sync engine.

### Requirement: CRDT Operations

The system SHALL use Loro CRDT for all data synchronization.

#### Scenario: Offline editing
- GIVEN a device is offline
- WHEN a user creates/edits a card
- THEN the changes SHALL be stored in Loro document
- AND no sync attempt SHALL be made

#### Scenario: Reconnection and sync
- GIVEN devices have divergent changes
- WHEN devices reconnect
- THEN Loro CRDT SHALL automatically merge changes
- AND no data SHALL be lost

---

## 2. Cache Layer: SQLite

### Context

Loro CRDT focuses on consistency and sync, not querying. Need fast list queries, full-text search, sorting, pagination.

### Decision

**Use SQLite** for query caching with FTS5 full-text search.

### Requirement: Query Performance

The system SHALL achieve query performance targets.

#### Scenario: Load 1000 cards
- GIVEN 1000 cards in the database
- WHEN loading the card list
- THEN the query SHALL complete in < 1 second

#### Scenario: SQLite single query
- GIVEN a single card query by ID
- WHEN executing the query
- THEN the result SHALL return in < 10ms

---

## 3. ID Format: UUID v7

### Context

Need time-ordered, conflict-free unique identifiers for all entities.

### Decision

**Use UUID v7** for all entity IDs.

### Requirement: ID Generation

The system SHALL generate UUID v7 format IDs.

#### Scenario: Create new card
- GIVEN a card creation request
- WHEN generating the card ID
- THEN the ID SHALL be UUID v7 format
- AND the timestamp component SHALL reflect creation time

---

## 4. Cross-Platform Bridge: flutter_rust_bridge

### Context

Need type-safe, efficient communication between Flutter and Rust.

### Decision

**Use flutter_rust_bridge** for code generation.

---

## 5. Password Security: bcrypt + Keyring

### Context

Need secure password hashing and secure storage for pool passwords.

### Decision

**Use bcrypt** for hashing and platform Keyring for storage.

---

## 6. Peer Discovery: mDNS

### Context

Need automatic peer discovery on local network for P2P sync.

### Decision

**Use mDNS** for peer discovery.

---

**Related Documents**: [Tech Constraints](../../docs/architecture/tech_constraints.md)
