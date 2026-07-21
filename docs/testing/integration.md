# Integration journeys

`integration_test/cardmind_journeys_test.dart` covers six user journeys using
the real flutter_rust_bridge API and an isolated SQLite database per test.
The test adapter is intentionally kept under `integration_test/support/` until
production startup exposes an injectable `NoteRepository` and database path.

## Run existing targets

The runner never invokes `flutter pub get`, installs SDKs, or creates devices.
It expects an already configured Flutter toolchain and an existing device.

```powershell
# Windows desktop
dart run tool/feature_test.dart --windows

# Android, using an existing adb device
$env:CARDMIND_ANDROID_DEVICE_ID = 'emulator-5554'
dart run tool/feature_test.dart --android

# Both targets, sequentially
dart run tool/feature_test.dart --all --device=emulator-5554
```

The runner always passes `flutter test --no-pub` and forwards Flutter output.
Android runs fail with an actionable message when no device id is supplied;
there is no automatic SDK or emulator download.

## Production adapter handoff

The test adapter currently owns `SyncService` and `NoteStore` and writes to a
temporary directory. Production should expose the same four `NoteRepository`
operations plus an explicit lifecycle method or provider that accepts a
database path. Once available, the journey tests can replace the test adapter
without changing their finders or user flows.
