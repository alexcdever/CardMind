# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 📍 Quick Start

**New to this project?** Start here:
1. Read [Product Vision](docs/requirements/product_vision.md) - What is CardMind?
2. Review [System Design](docs/architecture/system_design.md) - How is it built?
3. ⭐ **NEW**: Check [OpenSpec Center](openspec/specs/) - What should be implemented?
4. Run `cargo doc --open` for implementation details

**Working on a task?**
- 🛡️ **Project Guardian is active** - Constraints auto-enforced
- Use `TodoWrite` tool to track progress
- Follow TDD principles (write tests first)
- Run `cargo doc --open` for implementation details
- Validate constraints: `dart tool/validate_constraints.dart`

---

## 🏗️ Project Overview

**CardMind** is a card-based note-taking application with:
- **Offline-first** design
- **P2P sync** capabilities (Phase 2)
- **CRDT** data consistency (Loro)
- **Dual-layer** architecture (Loro + SQLite)

**Current Status**: MVP v1.0.0 completed ✅, Phase 6R: Spec Coding Refactoring 🔄

**Tech Stack**:
- Frontend: Flutter 3.x
- Backend: Rust
- CRDT: Loro 1.3.1
- Cache: SQLite (rusqlite)
- Bridge: flutter_rust_bridge

---

## 📚 Documentation Structure

CardMind uses a **layered documentation system**. Always consult the right layer:

```
Layer Priority (When in doubt, check in this order):
  1. openspec/specs/    ← API specifications (what)
  2. openspec/specs/adr/ ← Architecture decisions (why)
  3. docs/architecture/ ← System principles (rules)
  4. docs/requirements/ ← Product goals (intent)
```

### [Specs] - API Specifications ⭐ NEW

**What**: Testable API definitions and behavior contracts

| Category | Location | Content |
|----------|----------|---------|
| Rust Backend | `openspec/specs/rust/` | 8 specs (SP-TYPE-000 ~ SP-SYNC-006) |
| Flutter UI | `openspec/specs/flutter/` | 3 specs (SP-FLUT-003/007/008) |
| Guides | `openspec/specs/` | SPEC_CODING_GUIDE.md, SPEC_CODING_SUMMARY.md |

**Key Files**:
- `openspec/specs/README.md` - Spec center index
- `openspec/specs/SPEC_CODING_GUIDE.md` - Implementation guide
- `openspec/specs/rust/single_pool_model_spec.md` - SP-SPM-001
- `openspec/specs/rust/sync_spec.md` - SP-SYNC-006
- `rust/tests/sp_*_spec.rs` - Executable spec tests (3 files)

**Spec Coverage**: 11 functional specs + 5 ADRs

### [ADRs] - Architecture Decision Records ⭐ NEW

**Why**: Design decisions with context, alternatives, and trade-offs

| ADR | Topic | Content |
|-----|-------|---------|
| 0001 | Single Pool Ownership | Why single pool model? |
| 0002 | Dual-Layer Architecture | Why Loro + SQLite? |
| 0003 | Tech Constraints | Why these technologies? |
| 0004 | UI Design | Why this design system? |
| 0005 | Logging | Why tracing/logger? Log levels, standards |

**Location**: `openspec/specs/adr/`

### [Architecture] - System Design

**Rules**: Invariant principles and constraints

| Doc | Content |
|-----|---------|
| [System Design](docs/architecture/system_design.md) | Dual-layer principles, constraints |
| [Sync Mechanism](docs/architecture/sync_mechanism.md) | Subscription-driven updates |

### [Requirements] - Product Goals

| Doc | Content |
|-----|---------|
| [Product Vision](docs/requirements/product_vision.md) | What & why |
| [Roadmap](docs/roadmap.md) | Version planning |

### [Implementation] - How to Code

| Doc | Content |
|-----|---------|
| [Build Guide](tool/BUILD_GUIDE.md) | How to build |
| [Logging Guide](docs/implementation/logging.md) | Logging standards |

---

## 🎯 Core Architecture (Quick Reference)

### Dual-Layer Data Architecture

```
┌─────────────────────────────────────┐
│   User Action (Create/Edit/Delete) │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Loro CRDT (Source of Truth)        │  ← ALL writes go here
│  - File: data/loro/<uuid>/          │
│  - Every card = one LoroDoc         │
└──────────────┬──────────────────────┘
               │ commit()
               ▼
┌─────────────────────────────────────┐
│  Subscription Callback              │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  SQLite (Query Cache - Read Only)   │  ← ALL reads from here
│  - Fast queries                     │
│  - Full-text search (FTS5)          │
└─────────────────────────────────────┘
```

**Critical Rules**:
1. ✅ ALL writes → Loro (never SQLite directly)
2. ✅ ALL reads → SQLite (fast cached queries)
3. ✅ Loro commits trigger subscriptions → update SQLite
4. ✅ SQLite can be rebuilt from Loro anytime

**Details**: [System Design](docs/architecture/system_design.md)
**Decisions**: [ADR-0002](openspec/specs/adr/0002-dual-layer-architecture.md)

### Rust Module Structure

```
rust/src/
├── api/           # Flutter Rust Bridge API layer
│   ├── card.rs    # Card CRUD operations
│   ├── pool.rs    # Data pool management
│   ├── device_config.rs  # Device configuration
│   └── sync.rs    # P2P sync API
├── store/         # Data persistence layer
│   ├── card_store.rs     # Card Loro + SQLite operations
│   └── pool_store.rs     # Pool Loro + SQLite operations
├── models/        # Data structures
│   ├── card.rs    # Card, CardMetadata
│   ├── pool.rs    # DataPool, PoolMember
│   └── error.rs   # AppError types
├── p2p/           # P2P networking
│   ├── network.rs        # libp2p transport layer
│   ├── discovery.rs      # mDNS peer discovery
│   ├── sync.rs           # Sync protocol
│   ├── sync_manager.rs   # Loro sync coordination
│   ├── sync_service.rs   # P2P sync service
│   └── multi_peer_sync.rs # Multi-device coordinator
├── security/      # Security primitives
│   ├── password.rs       # bcrypt hashing
│   └── keyring_store.rs  # Secure password storage
└── utils/         # Utilities
```

**Spec References**:
- API specs: `openspec/specs/rust/api_spec.md`
- Card model: `openspec/specs/rust/single_pool_model_spec.md`
- Sync specs: `openspec/specs/rust/sync_spec.md`

---

## 🔧 Development Workflow

### Before Starting Work
1. Review relevant specs in `openspec/specs/`
2. Check ADRs if design context needed
3. Use `TodoWrite` tool to track tasks

### While Working
1. **Write tests first** (TDD - Red, Green, Refactor)
2. **Follow Spec Coding**: Use `it_should_do_something()` naming
3. **Run checks**:
   ```bash
   flutter analyze  # Must pass
   cargo check      # Must pass
   cargo clippy     # Zero warnings
   ```

### After Completing Work
1. Mark task as `completed` using `TodoWrite`
2. Update `docs/roadmap.md` if milestone reached
3. Update specs if API changed (add test cases)
4. Document new decisions in ADRs

---

## 🛠️ Quick Commands

### Build
```bash
# Build all platforms (recommended)
dart tool/build_all.dart

# Build specific platform
dart tool/build_all.dart --android
dart tool/build_all.dart --linux

# Generate Flutter Rust Bridge code
dart tool/generate_bridge.dart
```

### Test
```bash
# All Rust tests (run from rust/ directory)
cargo test

# Run spec tests (NEW 2026-01-14)
cargo test --test sp_spm_001_spec
cargo test --test sp_sync_006_spec
cargo test --test sp_mdns_001_spec

# Run single Rust test
cargo test test_name

# Run specific test file
cargo test --test sync_integration_test

# Flutter tests
flutter test
```

### Documentation
```bash
# Generate Rust API docs
cargo doc --open

# View spec center
cat openspec/specs/README.md

# View Project Guardian config
cat project-guardian.toml
```

### Code Quality
```bash
# Auto-fix lint issues
dart tool/fix_lint.dart

# Check without fixing
dart tool/check_lint.dart

# Rust linting
cargo clippy

# Validate Project Guardian constraints
dart tool/validate_constraints.dart

# Full validation (includes compilation)
dart tool/validate_constraints.dart --full
```

See [Build Guide](tool/BUILD_GUIDE.md) for details.

---

## ⚠️ Critical Constraints

🛡️ **Project Guardian Active** - All constraints are automatically enforced via `project-guardian.toml`

### Data Layer Rules
- **NEVER write to SQLite directly** - only Loro writes, subscriptions update SQLite
- **ALWAYS call `loro_doc.commit()`** after modifications
- **ALWAYS persist Loro files** after commits
- **Use UUID v7** for all IDs (time-ordered, conflict-free)

### Development Rules
- **Write tests first** (TDD required)
- **Test coverage > 80%** (hard requirement)
- **New code requires spec tests** (`it_should_xxx()` style)
- **Never bypass Loro** for data changes
- **SQLite is read-only** from app perspective

### Code Quality Rules (Auto-enforced)
- **No `unwrap()` or `expect()`** - use `?` or `match`
- **No `panic!()`** - return `Result` types
- **No `print()`** in Dart - use `debugPrint()`
- **No TODO/FIXME** in committed code
- **All API functions return `Result<T, Error>`**

### File Organization
- Each card = one LoroDoc file
- Path: `data/loro/<base64(uuid)>/snapshot.loro` and `update.loro`
- Never use a single shared LoroDoc for all cards

**See**: `project-guardian.toml` for complete constraint definitions

---

## 📖 Common Tasks - Where to Look

| Task | Look Here |
|------|-----------|
| Understand the product | [Product Vision](docs/requirements/product_vision.md) |
| Understand architecture | [System Design](docs/architecture/system_design.md) |
| Understand design decisions | Check `openspec/specs/adr/` |
| Find API specs | Check `openspec/specs/` |
| Write tests | [Spec Coding Guide](openspec/specs/SPEC_CODING_GUIDE.md) |
| Build the app | [Build Guide](tool/BUILD_GUIDE.md) |
| Check logging standards | [Logging Guide](docs/implementation/logging.md) |
| **View constraints** | `project-guardian.toml` |
| **Best practices** | `.project-guardian/best-practices.md` |
| **Anti-patterns** | `.project-guardian/anti-patterns.md` |

---

## 🛡️ Project Guardian

**What**: Automatic constraint enforcement system that prevents LLM hallucinations and architecture violations.

**Key Files**:
- `project-guardian.toml` - Main configuration (250 lines)
- `.project-guardian/README.md` - Usage guide
- `.project-guardian/best-practices.md` - 11 recommended patterns
- `.project-guardian/anti-patterns.md` - 11 common mistakes
- `.project-guardian/failures.log` - Violation history

**Quick Commands**:
```bash
# Validate constraints
dart tool/validate_constraints.dart

# Full validation (with compilation)
dart tool/validate_constraints.dart --full

# Rust only
dart tool/validate_constraints.dart --rust-only

# Dart only
dart tool/validate_constraints.dart --dart-only
```

**How It Works**:
1. LLM reads `project-guardian.toml` at conversation start
2. Constraints are auto-injected based on operation type
3. Code is checked against forbidden/required patterns
4. Validation commands run automatically
5. Violations are logged to `.project-guardian/failures.log`

**Constraint Categories**:
- **Rust Code**: No unwrap/panic, must use Result, must commit Loro
- **Dart Code**: No print(), must check mounted, must have key param
- **Commands**: Forbidden dangerous commands, require confirmation for risky ops
- **Submission**: 8-item checklist before commit

**See**: `.project-guardian/README.md` for complete documentation

---

## 🤖 AI Usage Guidelines

### When Starting a New Conversation
1. Check `openspec/specs/README.md` - what specs exist?
2. Check relevant ADRs in `openspec/specs/adr/` - understand design decisions
3. Review [System Design](docs/architecture/system_design.md) - understand architecture
4. Use `TodoWrite` to track tasks if needed

### When Implementing Features
1. **Check specs first** - `openspec/specs/rust/*.md`, `openspec/specs/flutter/*.md`
2. **Check ADRs for context** - `openspec/specs/adr/*.md`
3. **Understand architecture** - `docs/architecture/system_design.md`
4. **Follow TDD** - write spec tests first (`it_should_xxx()` naming)
5. **Check implementation details** - run `cargo doc --open`

### When Stuck
- What to implement? → `openspec/specs/`
- Why this design? → `openspec/specs/adr/`
- Architecture unclear? → `docs/architecture/system_design.md`
- Requirements unclear? → `docs/requirements/product_vision.md`
- Implementation unclear? → `cargo doc --open`
- Not sure about priority? → [roadmap.md](docs/roadmap.md)

---

## 📝 Performance Targets

Achieved in MVP v1.0.0:

- ✅ Card creation: 2.7ms (target < 50ms)
- ✅ Card update: 4.6ms (target < 50ms)
- ✅ 1000 cards load: 329ms (target < 1s)
- ✅ SQLite query: < 4ms (target < 10ms)

See [CHANGELOG.md](CHANGELOG.md) for release details.

---

## 🚀 Current Focus (2026-01)

**Phase 6R: Single Pool Model Refactoring + Spec Coding** 🔄

- ✅ Spec Coding infrastructure: 11 functional specs + 5 ADRs
- ✅ Spec tests: 3 executable tests (sp_spm_001_spec, sp_sync_006_spec, sp_mdns_001_spec)
- 🔄 Remaining: Implement remaining specs, add more tests

**Spec Center**:
- `openspec/specs/` - 11 functional specs + 5 ADRs
- `rust/tests/sp_*_spec.rs` - 3 executable spec tests

**ADRs**:
- `openspec/specs/adr/0001-single-pool-ownership.md` - Single pool model
- `openspec/specs/adr/0002-dual-layer-architecture.md` - Dual-layer architecture
- `openspec/specs/adr/0003-tech-constraints.md` - Technology choices
- `openspec/specs/adr/0004-ui-design.md` - UI design decisions
- `openspec/specs/adr/0005-logging.md` - Logging system decisions

See [roadmap.md](docs/roadmap.md) for details.

---

## 📚 Core Terminology

### Architecture Terms

**CRDT** (Conflict-free Replicated Data Type)
- 无冲突复制数据类型，支持多设备同时离线编辑并自动合并

**Loro**
- 基于 Rust 的 CRDT 库，CardMind 的数据核心，支持文件持久化和订阅机制

**双层架构**
- 源数据层 (Loro) + 查询缓存层 (SQLite)
- 所有写操作走 Loro，所有读操作走 SQLite

**单向数据流**
- 写: 用户 → Loro → commit → 订阅 → SQLite → UI
- 读: 用户 → SQLite → 快速返回

**订阅机制**
- Loro 变更时自动通知订阅者更新 SQLite，保证数据一致性

### Data Terms

**UUID v7**
- 时间排序的全局唯一标识符，CardMind 所有 ID 的标准格式

**数据池 (Data Pool)**
- P2P 同步的逻辑边界，通过密码控制设备间的数据共享范围

**软删除**
- 设置 `is_deleted = true` 而非物理删除，支持数据恢复和 CRDT 同步

### Development Terms

**TDD** (Test-Driven Development)
- 先写测试再写实现：Red (失败) → Green (通过) → Refactor (重构)

**Spec Coding**
- 测试即规格，规格即文档
- 使用 `it_should_do_something_when()` 命名

**P2P** (Peer-to-Peer)
- 点对点网络，设备间直接通信，无需中央服务器

**libp2p**
- 模块化 P2P 网络协议栈，CardMind 用于设备发现和数据传输

---

## 📌 Important Notes

### Documentation Philosophy
1. **Specs are primary** - define "what" and "how" (testable)
2. **ADRs explain "why"** - design decisions with trade-offs
3. **Architecture docs describe rules** - invariant principles
4. **Implementation details in code** - use `cargo doc` for "how"
5. **Never duplicate code in markdown** - point to specs or code instead

---

*Last updated: 2026-01-16*
