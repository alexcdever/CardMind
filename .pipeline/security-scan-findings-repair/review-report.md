# Independent Security Review

- task-id: `security-scan-findings-repair`
- identity: independent read-only reviewer
- worktree: `D:/Projects/CardMind/.worktrees/security-scan-findings-repair`
- branch: `task/security-scan-findings-repair`
- reviewed HEAD: `8acff7e314325101db3f310eaa39abbc2ea31140`
- expected latest HEAD: `8acff7e314325101db3f310eaa39abbc2ea31140`
- frozen scan revision: `87b42ce6be45c431cea55b545fa08f17832f3cd5`
- scope: frozen task sheet, executor evidence, current production code/tests, focused regressions, and static scans; product code and task sheet not modified

## Verdict

**PASS**. All frozen acceptance contracts are evidenced at the requested worktree and HEAD. The prior pairing assertion gap is repaired: `pairing_identity_must_match_transport` uses a real authenticated iroh connection through the production route, then asserts the actual receiver pending-pairing state is empty and the actual receiver `NoteStore` has no paired-device rows. Production inspection confirms authorization before payload reads and before import/projection/last_seen, allowlist refresh from the current store, successful-pairing authorization on both sides, bounded inbound reads/decoders, and shell-free argv launching.

## Findings

### PASS — transport identity binding and receiver state

`rust-backend/tests/security_sync_test.rs:75-113` passes the receiver's `receiver_store` into the real receive seam and asserts `!receiver.has_pending_pairing_for_test()` plus `receiver_store.list_paired_devices().is_empty()` after the forged claimed identity is rejected. `route_incoming` compares the decoded request identity with `conn.remote_id()` before storing `PendingPairing`; the receiver cannot retain or persist the forged identity.

### PASS — authorization-before-read and allowlist lifecycle

`route_incoming` reads only the fixed marker, checks `authorized_peers` before reading push, health, or device-name bodies, and rejects unauthorized peers before CRDT import, SQLite projection, or last-seen updates. `receiver_handle_incoming` refreshes the allowlist from the current receiver store before routing. Successful pairing inserts both peer IDs into the shared allowlist. The live unknown-peer test proves no note or paired-device state change, while receiver and pairing regressions prove the authorized path remains usable.

### PASS — bounded parsing and shell-free runner

Production inbound `read_to_end` calls use finite push/pairing/name limits; decoder tests reject oversized fields/counts without panic. The scan found `usize::MAX` only in unrelated legacy test fixtures, not production `rust-backend/src`; `runInShell: true` was found only in the boundary-scanner fixture, not `tool/feature_test.dart`. The feature runner validates bounded device identifiers and uses argv with `runInShell: false`.

## Commands and results

| Command | Result |
|---|---|
| `git rev-parse --show-toplevel && git status --short --branch && git rev-parse HEAD && git branch --show-current` | PASS; HEAD `8acff7e314325101db3f310eaa39abbc2ea31140` |
| `cargo test --test security_sync_test && cargo test --test pairing_test && cargo test --test receiver_continuous_test && cargo test --test sync_test && cargo test --test device_name_test` | PASS; 4, 10, 14, 1, 12 tests |
| `flutter test test/feature_test_security_test.dart` | PASS; 2 tests |
| `cargo fmt --all -- --check && cargo check --tests` | PASS |
| production bounded-read/shell-free scans | PASS; no `usize::MAX` reads in `rust-backend/src`, no shell launch in `tool/feature_test.dart` |
| `git diff --check 8acff7e^..HEAD` | PASS |

## Frozen acceptance matrix

| Acceptance | Result | Evidence |
|---|---|---|
| `acceptance-unauthorized-peer` | PASS | Live unknown-peer no-state-change test plus production pre-read authorization inspection |
| `acceptance-pairing-identity` | PASS | Real transport mismatch rejection plus actual receiver pending/store emptiness assertions |
| `acceptance-bounded-frames` | PASS | Oversized fields/counts/response decoder tests and finite production read limits |
| `acceptance-shell-free-runner` | PASS | Flutter security test and `tool/feature_test.dart` inspection |
| `acceptance-existing-sync` | PASS | Full receiver-continuous and sync suites |
| `acceptance-existing-pairing` | PASS | Full pairing suite and identity assertions |

## Evidence identity

The worktree, branch, and reviewed HEAD exactly match the requested identity. Only `review-report.md` and `reviewer-result.json` were written; task sheet, scanner evidence, and product code were not modified. The verdict is independent of the executor PASS claim.

<!-- pipeline-evidence
{"schema":1,"task_id":"security-scan-findings-repair","role":"reviewer","identity":"independent read-only reviewer","worktree":"D:/Projects/CardMind/.worktrees/security-scan-findings-repair","branch":"task/security-scan-findings-repair","head":"8acff7e314325101db3f310eaa39abbc2ea31140","expected_head":"8acff7e314325101db3f310eaa39abbc2ea31140","frozen_scan_revision":"87b42ce6be45c431cea55b545fa08f17832f3cd5","status":"PASS","commands":[{"command":"git rev-parse --show-toplevel && git status --short --branch && git rev-parse HEAD && git branch --show-current","cwd":"D:/Projects/CardMind/.worktrees/security-scan-findings-repair","exit_code":0},{"command":"cargo test --test security_sync_test && cargo test --test pairing_test && cargo test --test receiver_continuous_test && cargo test --test sync_test && cargo test --test device_name_test","cwd":"D:/Projects/CardMind/.worktrees/security-scan-findings-repair/rust-backend","exit_code":0,"tests_passed":{"security_sync_test":4,"pairing_test":10,"receiver_continuous_test":14,"sync_test":1,"device_name_test":12}},{"command":"flutter test test/feature_test_security_test.dart","cwd":"D:/Projects/CardMind/.worktrees/security-scan-findings-repair","exit_code":0,"tests_passed":2},{"command":"cargo fmt --all -- --check && cargo check --tests","cwd":"D:/Projects/CardMind/.worktrees/security-scan-findings-repair/rust-backend","exit_code":0},{"command":"production bounded-read/shell-free scans","cwd":"D:/Projects/CardMind/.worktrees/security-scan-findings-repair","exit_code":0},{"command":"git diff --check 8acff7e^..HEAD","cwd":"D:/Projects/CardMind/.worktrees/security-scan-findings-repair","exit_code":0}],"assertions":["unauthorized peer cannot change note or paired-device state","pairing identity mismatch is rejected on authenticated transport before pending/store persistence and actual receiver state remains empty","oversized fields/counts/response fields reject without panic","successful pairing authorizes both sides and existing receiver/sync paths remain green","feature runner validates device argv and uses runInShell false"],"findings":[],"pipeline_evidence":{"acceptance-unauthorized-peer":"PASS","acceptance-pairing-identity":"PASS","acceptance-bounded-frames":"PASS","acceptance-shell-free-runner":"PASS","acceptance-existing-sync":"PASS","acceptance-existing-pairing":"PASS"}}
-->
