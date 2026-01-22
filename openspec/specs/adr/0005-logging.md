# ADR-0005: Logging System
# ADR-0005：日志系统

**Status**: Accepted  
**Date**: 2024-12-31  
**Deciders**: CardMind Team

---

## Context | 上下文

Need unified logging solution for both Rust and Flutter, supporting debugging, tracing, and monitoring.

---

## Decision | 决策

**Use platform-appropriate logging solutions**:

| Platform | Library | Reason |
|----------|---------|--------|
| Rust | `tracing` + `tracing-subscriber` | Performance, async support |
| Flutter | `logger` package | Simple, colorful output |

### Requirement: Log Output

The system SHALL produce logs with consistent information.

#### Scenario: Error logging
- GIVEN an error occurs
- WHEN logging with ERROR level
- THEN the output SHALL include error message
- AND stack trace if available

#### Scenario: Info logging
- GIVEN a significant operation completes
- WHEN logging with INFO level
- THEN the output SHALL include operation details
- AND result status

---

## Log Level Policy | 日志级别策略

### Level Definitions | 级别定义

| Level | Use Case | Example |
|-------|----------|---------|
| ERROR | Must-fix issues | File write failed, DB connection failed |
| WARN | Needs attention | Empty title, missing config |
| INFO | Important operations (default) | Card created, sync completed |
| DEBUG | Development use | Function parameters, intermediate state |
| TRACE | Very detailed | Function entry/exit, loop iterations |

### Requirement: Level Filtering

The system SHALL filter logs by configured level.

#### Scenario: Production mode
- GIVEN the app runs in production
- WHEN configured with INFO level
- THEN DEBUG and TRACE logs SHALL be suppressed

#### Scenario: Development mode
- GIVEN the app runs in development
- WHEN configured with DEBUG level
- THEN DEBUG logs SHALL be visible
- AND TRACE logs MAY be enabled separately

---

## Content Standards

### Good Logging Examples

```rust
// ✅ Clear and informative
info!("Card created: id={}, title=\"{}\"", card.id, card.title);

// ❌ Avoid
info!("Created card");
```

### Requirement: Log Content

The system SHALL include contextual information in logs.

#### Scenario: Card operation
- GIVEN a card operation occurs
- WHEN logging the operation
- THEN include card ID and relevant attributes
- AND avoid logging sensitive data

---

**Related Documents**: None
