# SP-SYNC-006: Sync Layer Specification

**Status**: Active  
**Date**: 2026-01-14  
**Module**: Rust Backend - P2P Sync  
**Related Tests**: `rust/tests/sp_sync_006_spec.rs`

---

## Overview

## 📋 规格编号: SP-SYNC-006
**版本**: 1.0.0
**状态**: 待实施
**依赖**: 

This spec defines the P2P sync layer requirements for CardMind, including peer discovery, sync status tracking, and sync service management.

---

## Requirement: Sync Service Creation

The system SHALL provide a sync service that manages P2P connections and data synchronization.

### Scenario: Create sync service with valid config
- GIVEN a valid SyncConfig with peer ID and port
- WHEN creating a new SyncService
- THEN the service SHALL initialize successfully
- AND be ready to accept connections

### Scenario: Sync service tracks online peers
- GIVEN a sync service is running
- WHEN peers join the network
- THEN the service SHALL track online peer count
- AND the count SHALL be accessible via SyncStatus

---

## Requirement: Sync Status Reporting

The system SHALL provide a SyncStatus struct that reflects the current sync state.

### Scenario: Initial sync status has zero online peers
- GIVEN a newly created SyncService
- WHEN requesting SyncStatus
- THEN the online_peers count SHALL be 0
- AND syncing_peers count SHALL be 0

### Scenario: Sync status reflects independent copies
- GIVEN a SyncService is running
- WHEN multiple threads request SyncStatus
- THEN each request SHALL return an independent copy
- AND modifications to one copy SHALL NOT affect others

---

## Requirement: Peer Discovery

### Scenario: mDNS peer discovery enabled
- GIVEN the sync service is configured with mDNS
- WHEN discovering peers on the local network
- THEN the service SHALL find other CardMind instances
- AND add them to the peer list

---

**Test Cases**: See `rust/tests/sp_sync_006_spec.rs`

**Related Documents**:
- [Sync Mechanism](../../docs/architecture/sync_mechanism.md)
