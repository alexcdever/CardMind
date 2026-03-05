# Fractal Documentation Standard

## Normative Rules

- Any feature, architecture, or implementation change MUST update the corresponding `DIR.md` entries in the touched directories.
- Each maintained directory MUST include a `DIR.md`, including the repository root where applicable.
- A `DIR.md` MUST begin with concise positioning text (within three lines), then list files with name, role, and responsibility.
- When a `.dart` or `.rs` file is modified, its three-line header MUST stay truthful and synchronized with directory indexing.
- The source header for `.dart` and `.rs` SHOULD keep the canonical keys exactly as:
  - `input:`
  - `output:`
  - `pos:`

## Scope Exclusions

- Generated artifacts and third-party dependencies are out of scope for this standard: `build/`, `rust/target/`, `ios/Pods/`, `android/.gradle/`, `linux/build/`, `macos/Build/`, `windows/build/`, `pubspec.lock`, `lib/**.g.dart`, `lib/**.freezed.dart`.

## Execution Guidance

- This standard is policy-driven. Compliance MUST be enforced during review and delivery workflows, not by repository gate scripts.
