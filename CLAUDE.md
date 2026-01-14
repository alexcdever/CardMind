# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 📍 Quick Start

**New to this project?** Start here:
1. Read [Product Vision](docs/requirements/product_vision.md) - What is CardMind?
2. Check [TODO.md](TODO.md) - What needs to be done now?
3. Review [System Design](docs/architecture/system_design.md) - How is it built?

**Working on a task?**
- Update [TODO.md](TODO.md) using the `TodoWrite` tool
- Follow TDD principles (write tests first)
- Run `cargo doc --open` for implementation details

---

## 🏗️ Project Overview

**CardMind** is a card-based note-taking application with:
- **Offline-first** design
- **P2P sync** capabilities (Phase 2)
- **CRDT** data consistency (Loro)
- **Dual-layer** architecture (Loro + SQLite)

**Current Status**: MVP v1.0.0 completed ✅, P2P sync in progress 🔄

**Tech Stack**:
- Frontend: Flutter 3.x
- Backend: Rust
- CRDT: Loro 1.3.1
- Cache: SQLite (rusqlite)
- Bridge: flutter_rust_bridge

---

## 📚 Documentation Structure

CardMind uses a **layered documentation system**. Always consult the right layer:

### [Management Docs] - Time & Progress
Track what's being done and when:

- **[TODO.md](TODO.md)** ← Update this frequently!
  - Current tasks (AI-writable)
  - Pending work
  - Completed items

- **[docs/roadmap.md](docs/roadmap.md)**
  - Version planning (v1.0, v2.0...)
  - Milestones
  - Priorities

- **[CHANGELOG.md](CHANGELOG.md)**
  - Release history
  - Version changes
  - Feature additions and bug fixes

### [Design Docs] - Architecture & Rules
Understand "why" and "what":

#### Requirements Layer - Product Goals
- [Product Vision](docs/requirements/product_vision.md) - What & why
- [User Scenarios](docs/requirements/user_scenarios.md) - How users use it (Note: may be incomplete)
- [Business Rules](docs/requirements/business_rules.md) - Domain logic (Note: may be incomplete)
- [Success Metrics](docs/requirements/success_metrics.md) - Definition of done (Note: may be incomplete)

#### Interaction Layer - User Experience
- [UI Flows](docs/interaction/ui_flows.md) - Screen flows (Note: may be incomplete)
- [Feedback Design](docs/interaction/feedback_design.md) - User feedback (Note: may be incomplete)
- [Information Architecture](docs/interaction/information_arch.md) - Navigation (Note: may be incomplete)
- [Accessibility](docs/interaction/accessibility.md) - A11y requirements (Note: may be incomplete)

#### Architecture Layer - System Design
- **[System Design](docs/architecture/system_design.md)** ← Read this first!
  - Dual-layer architecture
  - Data flow principles
  - Layer responsibilities

- [Data Contract](docs/architecture/data_contract.md) - Data schemas
- [Layer Separation](docs/architecture/layer_separation.md) - Code organization
- [Sync Mechanism](docs/architecture/sync_mechanism.md) - How data syncs
- [Tech Constraints](docs/architecture/tech_constraints.md) - Why these technologies?

### [Implementation Guides] - How to Code
Point to code and tools:

- **[Rust Doc Guide](docs/implementation/rust_doc_guide.md)** - Documentation standards
  - Run `cargo doc --open` to see API docs
  - Implementation details live in code, not markdown

- [Testing Guide](docs/implementation/testing_guide.md) - TDD methodology
- [Build Guide](tool/BUILD_GUIDE.md) - How to build
- [Logging Guide](docs/implementation/logging.md) - Logging standards

### [Reference Docs] - Look Up Info
- [Documentation Index](docs/index/readme.md) - Navigate all docs
- [Glossary](docs/index/glossary.md) - Term definitions
- [User Guide](docs/user_guide.md) - For end users
- [FAQ](docs/faq.md) - Common questions

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

Details: [System Design](docs/architecture/system_design.md)

### Rust Module Structure

```
rust/src/
├── api/           # Flutter Rust Bridge API layer (11 functions)
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
├── p2p/           # P2P networking (Phase 6)
│   ├── network.rs        # libp2p transport layer
│   ├── discovery.rs      # mDNS peer discovery
│   ├── sync.rs           # Sync protocol messages
│   ├── sync_manager.rs   # Loro sync coordination
│   ├── sync_service.rs   # P2P sync service
│   └── multi_peer_sync.rs # Multi-device coordinator
├── security/      # Security primitives
│   ├── password.rs       # bcrypt hashing
│   └── keyring_store.rs  # Secure password storage
└── utils/         # Utilities (logging, etc.)
```

**Key Design Patterns**:
- **Thread-local storage** for API layer to handle SQLite thread safety
- **Subscription callbacks** for Loro → SQLite synchronization
- **Mock vs real network** in P2P tests (use `new_with_mock_network()` for testing)

---

## 🔧 Development Workflow

### Before Starting Work
1. Check [TODO.md](TODO.md) for current tasks
2. Use `TodoWrite` tool to mark task as `in_progress`
3. Review relevant design docs

### While Working
1. **Write tests first** (TDD - Red, Green, Refactor)
2. **Run checks**:
   ```bash
   flutter analyze  # Must pass
   cargo check      # Must pass
   cargo clippy     # Zero warnings
   ```
3. **Update TODO.md** when completing tasks

### After Completing Work
1. Mark task as `completed` in TODO.md
2. Update `docs/roadmap.md` if milestone reached
3. Update architecture docs if design changed

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
# Rust tests (all)
cd rust && cargo test

# Run single Rust test
cd rust && cargo test test_name

# Run specific test file
cd rust && cargo test --test sync_integration_test

# Flutter tests
flutter test
```

### Documentation
```bash
# Generate Rust API docs
cd rust && cargo doc --open

# View documentation index
open docs/index/readme.md
```

### Code Quality
```bash
# Auto-fix lint issues
dart tool/fix_lint.dart

# Check without fixing
dart tool/check_lint.dart

# Rust linting
cd rust && cargo clippy
```

See [Build Guide](tool/BUILD_GUIDE.md) for details.

---

## ⚠️ Critical Constraints

### Data Layer Rules
- **NEVER write to SQLite directly** - only Loro writes, subscriptions update SQLite
- **ALWAYS call `loro_doc.commit()`** after modifications
- **ALWAYS persist Loro files** after commits
- **Use UUID v7** for all IDs (time-ordered, conflict-free)

### Development Rules
- **Write tests first** (TDD required)
- **Test coverage > 80%** (hard requirement)
- **Never bypass Loro** for data changes
- **SQLite is read-only** from app perspective

### File Organization
- Each card = one LoroDoc file
- Path: `data/loro/<base64(uuid)>/snapshot.loro` and `update.loro`
- Never use a single shared LoroDoc for all cards

---

## 📖 Common Tasks - Where to Look

| Task | Look Here |
|------|-----------|
| Understand the product | [Product Vision](docs/requirements/product_vision.md) |
| See current work | [TODO.md](TODO.md) |
| Understand architecture | [System Design](docs/architecture/system_design.md) |
| Learn data schemas | [Data Contract](docs/architecture/data_contract.md) |
| Write tests | [Testing Guide](docs/implementation/testing_guide.md) |
| Build the app | [Build Guide](tool/BUILD_GUIDE.md) |
| Add Rust docs | [Rust Doc Guide](docs/implementation/rust_doc_guide.md) |
| Find term meanings | See "Core Terminology" below |

---

## 🤖 AI Usage Guidelines

### When Starting a New Conversation
1. Read `TODO.md` - what's the current status?
2. Check relevant design docs for context
3. Use `TodoWrite` to mark task as `in_progress`

### When Implementing Features
1. **Check requirements first** - [requirements/](docs/requirements/)
2. **Understand the architecture** - [architecture/](docs/architecture/)
3. **Follow TDD** - write tests first
4. **Update TODO.md** - track progress
5. **Check implementation details** - run `cargo doc --open`

### When Stuck
- Architecture unclear? → [System Design](docs/architecture/system_design.md)
- Requirements unclear? → [Product Vision](docs/requirements/product_vision.md)
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

**Phase 6: P2P Sync Implementation** (100% complete) ✅

All core features implemented:
- ✅ libp2p request-response protocol
- ✅ P2P sync service with dual-mode support (real/mock network)
- ✅ Flutter UI and Provider integration
- ✅ Complete test coverage (128 tests passing)

**Next Steps**: Optional features (Search, Tags, Import/Export)

See [TODO.md](TODO.md) and [roadmap.md](docs/roadmap.md) for details.

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

**P2P** (Peer-to-Peer)
- 点对点网络，设备间直接通信，无需中央服务器（Phase 2）

**libp2p**
- 模块化 P2P 网络协议栈，CardMind 用于设备发现和数据传输（Phase 2）

---

## 📌 Important Notes

### Documentation Philosophy
1. **Design docs are stable** - describe "what" and "why", not "how"
2. **Implementation details in code** - use `cargo doc` for "how"
3. **Management docs updated frequently** - TODO.md, roadmap.md
4. **Never duplicate code in markdown** - point to `cargo doc` instead

---

*Last updated: 2026-01-08*
