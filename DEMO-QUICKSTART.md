# Creel demo quick start

## Fastest review

Open the [static reviewer walkthrough](https://tweisslehman14.github.io/creel-ai-case-study/) for a no-install tour using synthetic content. It demonstrates the intended phone-to-desktop journey but does not run the Python service or local AI models.

## Run the working desktop journal

Requirements: Python 3.11 or later and a modern browser. No package installation is required for import, review, manual notes, search, or backup.

```sh
cd creel-desktop
python3 server.py
```

Open the local address printed in the terminal. Choose **Import a trip** and select `samples/sample-1.fishing-trip.zip`.

Optional transcription and extraction require separately installed local Whisper and Ollama tools. The full setup is in [`creel-desktop/README.md`](creel-desktop/README.md).

## Run the native iPhone app

Requirements: macOS, Xcode, and an installed iOS Simulator runtime.

1. Open `creel-ios/Creel.xcodeproj`.
2. Select the Creel scheme and an iPhone Simulator.
3. Press Run.

The native app has no account, backend, or third-party dependency. See [`creel-ios/README.md`](creel-ios/README.md) for command-line launch and export details.

