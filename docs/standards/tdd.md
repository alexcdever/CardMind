# TDD Standard

## Normative Process

- Engineering changes MUST follow the complete cycle: `Red -> Green -> Blue -> Commit`.
- `Red` MUST introduce or adjust a check first, then confirm the expected failing state.
- `Green` MUST apply the minimal implementation change required to satisfy the check.
- `Blue` MUST refactor naming/structure/duplication while preserving passing verification.
- `Commit` MUST happen only after required verification commands pass.

## Test Placement and Coverage

- Flutter tests MUST reside in `test/` and align with the behavior they verify.
- Rust integration tests MUST reside in `rust/tests/` and cover FFI entry points plus boundary conditions.
- New features and bug fixes MUST include tests for both success and failure paths.

## Verification Commands

- Recommended verification commands SHOULD include `flutter test`, `cargo test`, and `flutter analyze` according to change scope.
- Teams MAY add focused command subsets for faster iteration, but release-ready validation MUST still cover full affected scope.
