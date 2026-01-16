# Common Type System

> **Purpose**: Define reusable data types and constraints used across all specs.
> This spec ensures consistency in data modeling across CardMind.

---

## 1. Core Types

### 1.1 UniqueIdentifier

**Definition**: A globally unique identifier for distributed systems.

**Requirements**:
- Globally unique without centralized coordination
- Time-ordered (sortable by creation time)
- 128-bit length
- Collision probability < 10^-15

**Implementation**: UUID v7

**Example**: `018c8f8e-1a2b-7c3d-9e4f-5a6b7c8d9e0f`

**Usage**: `Card.id`, `Pool.id`, `DeviceConfig.device_id`

---

### 1.2 OptionalText

**Definition**: A UTF-8 encoded string that may be null or empty.

**Constraints**:
- May be null or empty string
- Maximum length: 256 Unicode characters (not bytes)
- Must not contain control characters (e.g., `\0`)

**Usage**: `Card.title`, `Pool.name`

---

### 1.3 MarkdownText

**Definition**: Content formatted with CommonMark Markdown.

**Supported Features**:
- Headings (H1-H6)
- Lists (ordered, unordered)
- Code blocks (with syntax highlighting)
- Inline code
- Blockquotes
- Links
- Tables
- Bold, italic, strikethrough

**Constraints**:
- Cannot be empty string (at least one space)
- No maximum length (limited by system performance)

**Usage**: `Card.content`

---

### 1.4 Timestamp

**Definition**: Unix timestamp in milliseconds.

**Format**: Unix epoch milliseconds

**Precision**: Millisecond (1/1000 second)

**Timezone**: UTC

**Example**: `1704067200000` (2024-01-01 00:00:00 UTC)

**Constraints**:
- Non-negative integer
- Range: 1970-01-01 to 2262-04-11

**Usage**: `Card.created_at`, `Card.updated_at`, `Pool.created_at`

---

## 2. Domain Terminology

| Term | Description |
|------|-------------|
| **Card** | Basic note unit containing title and Markdown content |
| **Pool** | Single user's note space containing multiple cards |
| **Device** | Terminal running CardMind |
| **Member** | Device that has joined a pool |

---

## 3. Data Integrity Invariants

### 3.1 Referential Integrity

- `DeviceConfig.pool_id` must reference an existing Pool
- `Pool.card_ids` must be consistent with SQLite `card_pool_bindings` table

### 3.2 Timestamp Consistency

- `created_at <= updated_at` (always true)
- `updated_at` is automatically updated on every modification
- All timestamps use UTC

### 3.3 Soft Delete

- Soft-deleted cards (`is_deleted = true`) do not appear in default queries
- Soft-deleted cards can be recovered

---

## 4. Related Specs

- [Single Pool Model Spec](./single_pool_model_spec.md) - Card and Pool data models
- [DeviceConfig Spec](./device_config_spec.md) - Device configuration data model
- [API Spec](./api_spec.md) - API field types

---

**Last Updated**: 2026-01-15
