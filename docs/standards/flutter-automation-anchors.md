# Flutter Automation Anchors Standard

## Goal

- Standardize machine-readable UI anchors for Flutter interactions so widget tests, integration tests, and desktop automation use the same identifiers.

## Required Pattern

- Interactive Flutter widgets SHOULD use all three layers together when they are part of a user flow worth automating:
  - `Semantics(identifier: ...)` for machine-readable stable identifiers
  - `ValueKey(...)` for Flutter-native test targeting
  - user-readable `Semantics(label: ...)` for accessibility text

- Recommended shape:

```dart
Semantics(
  identifier: SemanticIds.poolCreateButton,
  label: '创建池',
  button: true,
  child: ElevatedButton(
    key: const ValueKey('pool.create_button'),
    onPressed: () {},
    child: const Text('创建池'),
  ),
)
```

## Naming Rules

- `identifier` and `ValueKey` MUST use the same stable machine id.
- Machine ids SHOULD use dotted paths such as `cards.create_fab`, `pool.edit_dialog.save`, `nav.settings`.
- `label` MUST stay user-readable and MUST NOT be replaced with machine ids.
- Shared machine ids SHOULD be declared in a central constants file such as `lib/features/shared/testing/semantic_ids.dart`.

## Coverage Rules

- The pattern MUST be applied to:
  - primary action buttons
  - navigation entry points
  - dialog confirm/cancel actions
  - form inputs used in automated flows
  - any control required by widget or integration regression tests

- Purely decorative widgets SHOULD NOT receive automation anchors.

## Testing Rules

- Flutter automation tests SHOULD prefer `find.byKey(...)` for primary interaction targeting.
- Accessibility contract tests SHOULD verify user-readable labels still exist.
- When adding a new automated flow, add or update at least one test that proves the anchor is present and one test that uses it in interaction.

## Platform Guidance

- `Semantics.identifier` is the preferred machine-readable channel for future platform automation bridges.
- `ValueKey` remains the primary stable selector for Flutter widget tests.
- Desktop system automation MAY still expose only partial accessibility trees; this limitation does not waive the requirement to add identifiers, keys, and labels.
