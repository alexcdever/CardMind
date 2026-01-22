# SP-SPM-001: Single Pool Model Core Specification

**Status**: Active  
**Date**: 2026-01-14  
**Module**: Rust Backend  
**Related Tests**: `rust/tests/sp_spm_001_spec.rs`

---

## Overview

## 📋 规格编号: SP-SPM-001
**版本**: 1.0.0
**状态**: 待实施
**依赖**: 

This spec defines the Single Pool Model, where each card belongs to exactly one pool, and each device can join multiple pools but has exactly one resident pool.

---

## Requirement: Single Pool Constraint

The system SHALL enforce that a device can join at most one pool for personal note-taking.

### Scenario: Device joins first pool successfully
- GIVEN a device with no joined pools
- WHEN the device joins a pool with a valid password
- THEN the pool SHALL be added to the device's joined pools
- AND sync SHALL begin for that pool

### Scenario: Device rejects joining second pool
- GIVEN a device has already joined a pool
- WHEN the device attempts to join a second pool
- THEN the system SHALL reject the request
- AND return an error indicating single-pool constraint violation

---

## Requirement: Card Creation in Resident Pool

When a device creates a new card, it SHALL automatically belong to the device's resident pool.

### Scenario: Create card auto-joins resident pool
- GIVEN a device has a resident pool set
- WHEN a user creates a new card
- THEN the card SHALL be created in the resident pool
- AND the card SHALL be visible to all devices in that pool

### Scenario: Create card fails when no resident pool
- GIVEN a device has no resident pool set
- WHEN a user attempts to create a new card
- THEN the system SHALL reject the request
- AND return an error indicating no resident pool

---

## Requirement: Device Leaving Pool

When a device leaves a pool, the system SHALL clear all data associated with that pool.

### Scenario: Device leaves pool and clears data
- GIVEN a device has joined a pool with cards
- WHEN the device leaves the pool
- THEN all pool data SHALL be cleared from the device
- AND the device SHALL no longer sync with that pool

---

**Test Cases**: See `rust/tests/sp_spm_001_spec.rs`

**Related ADRs**:
- [ADR-0001: Single Pool Ownership](../adr/0001-single-pool-ownership.md)
