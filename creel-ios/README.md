# Creel for iPhone

A native, local-only fishing journal based on the supplied **Creel — Phone Capture MVP** HTML design. No account, backend, network calls, or third-party dependencies. Exported trips can be reviewed in the separately packaged desktop journal.

## Run in Xcode

1. Open `Creel.xcodeproj` in Xcode.
2. Select the **Creel** scheme and an installed iPhone simulator.
3. Press **Run** (⌘R).

Or, from this directory:

```sh
./scripts/run-simulator.sh
```

The script chooses an available iPhone simulator (preferring an already booted one), builds without signing, installs Creel, and launches it. Pass a simulator device ID as the first argument to select a specific device. Build files default to `/tmp/creel-derived-data`; override with `CREEL_BUILD_DIR`.

Requires Xcode with an iOS simulator runtime. Deployment target is iOS 17 or later. Physical-device installation additionally needs your own signing team in Xcode.

## Capture and export

Start a trip, then **Record**, **Photo**, or **Type**. An entry can stay incomplete or unclassified. Add information later, correct its occurrence time, and end or reopen the trip. Search uses your own text and trip information. Recording is foreground-only; completed audio parts are committed regularly and interruptions retain recoverable data.

**Export** creates one `.fishing-trip.zip` with trip metadata, events, a checksummed manifest, and original media. The share sheet lets you save or transfer it. Exporting does not delete the local trip or confirm delivery to another device. No desktop import or AI processing is implemented here. The current export limit is 250 MB of trip metadata and media; an oversized trip stays on the phone and export stops with an error. An unfinished recording that cannot be recovered is retained separately on the phone, outside the normal trip export, and is not represented as a successfully saved audio attachment.

The app uses native serif/body fonts to approximate the design because the supplied web fonts were not available in an iOS-compatible format. Real device testing is still needed for microphone interruptions, physical camera behavior, and field storage/GPS conditions. Simulator camera availability is limited; photo-library selection is available as a fallback. Microphone recording depends on host microphone permission and simulator audio support.

## Tests

```sh
swift test --scratch-path /tmp/creel-swift-tests
```

The dependency-free macOS test target compiles the same models and repository used by the app. Tests cover identity and revision round trips, original media integrity, ZIP extraction with the system unzip tool, manifest checksums, and failure on corrupted data. UI and physical-device checks are separate from these tests.

## Local data

Data lives inside the app's Application Support/Creel directory. Reinstalling without deleting the app preserves its sandbox; deleting the app or erasing the simulator removes it. Export important trips before deleting or resetting the app. No cloud backup or cross-device sync is provided.
