# Integration journeys

`integration_test/cardmind_journeys_test.dart` covers six user journeys using
`CardMindApp(repository:)` and the production `FrbNoteRepository`. Every test
gets an isolated temporary data directory containing the persistent Loro source
and its SQLite read projection. The harness closes all FRB opaque handles before
removing the directory.

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

## Coverage seams

The journeys interact through stable public `ValueKey` and Semantics anchors,
then observe persistence through the same production repository used by the
application. They cover create and reopen, list/open, desktop autosave,
Markdown input, tag filtering, and debounced search. Windows and Android run
the identical suite through `tool/feature_test.dart`.
