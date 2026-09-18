# Validation — September 17, 2026

## Verified

- Native SwiftUI app builds with Xcode 27.0 (27A266a), iOS simulator SDK 27, deployment target iOS 17.
- Installed and launched bundle `com.creel.journal` on iPhone 17 Pro, iOS 26.5, simulator ID `90ED4252-5C48-4E89-882F-0A05BEA202F8`. Simulator launch returned an app process ID.
- Eight dependency-free core tests passed, zero failures:
  - Persist/reload trip and moment identities, original text revisions and unknown occurrence time.
  - Export and independently extract a standard ZIP with system unzip; compare original bytes and all manifest checksums.
  - Reject altered original media without changing the saved library.
  - Reject empty media.
  - Reject corrupt library JSON without replacing it.
  - Reject invalid/duplicate media paths and clean incomplete exports.
  - Reject an oversized sparse-file trip and retain the original.
  - Preserve trip/event correction history through persistence.
- Product/senior review resulted in fixes for ID decoding, recording error wording, source correction history, export memory use, retrospective photo timing, unsaved note dismissal, direct end/outcome correction and explicit debrief classification.

Commands are in README.md. Build products and logs are outside source in `/tmp/creel-derived-data` and `/tmp/creel-build.log`.

## Not yet verified

The Mac lock screen prevented computer-use access to Simulator. The user was asked to unlock it. **No interactive UI walkthrough, screenshot review or simulator mixed-media trip is claimed.** The supplied HTML was reviewed from its decoded source; local-file browser preview was blocked by browser URL policy, and no workaround was attempted.

Physical-device gates remain open: five-minute intelligible recording, audio part-transition gaps, real microphone/camera, recording interruption/force-quit recovery, low-storage behavior, airplane-mode capture/export, permission-denied flows, GPS accuracy/staleness, and share-to-desktop receipt. Core repository tests do not validate these hardware/UI behaviors.

## Next simulator walkthrough

Use synthetic notes/photos; do not treat fixtures as user catches.

1. Start an empty trip, open it, save text; relaunch and verify it persists.
2. Edit the note, add a photo to the same moment, and check original text history and unchanged moment ID.
3. Import an old photo as a new moment: occurrence time/location must be unknown until supplied. Correct time/range and verify capture metadata remains separate.
4. Record/play a short clip, then a five-minute debrief; verify one event contains playable parts and explicit Journal type.
5. End with explicit zero catches, edit end/outcome directly, reopen, and append another note.
6. Generate package, cancel and complete local save separately; confirm no delivery claim. Verify ZIP hashes independently. Add a note and check changes-since-export status.
7. Deny microphone/location, attempt text capture, interrupt recording, and check reported state against actual retained files.

## Known limits

- Foreground recording only, in approximately 30-second parts. Capture holds the screen awake; switching apps stops capture. There can be gaps between parts; hardware measurement is pending.
- A force-quit may leave the current part unplayable. Completed parts remain in the trip. Unrecoverable raw audio and its association are retained separately in app storage, outside the normal trip export; no in-app repair/export tool for those files yet.
- 250 MB is an enforced export ceiling, not a tested field reliability claim. No capture-time size/storage warning yet. Multiple generated exports occupy local space.
- Native serif/system body fonts approximate the HTML typography. No bundled web-font conversion.
- Photo-library import preserves the current representation returned by the system picker. A cloud-only photo may need downloading first. Live Photo motion and RAW pairing are not a supported promise.
- Event type/time and trip corrections are retained in exported history; only prior text revisions currently have a history viewer on the phone.
- Desktop import/processing/search, cloud sync, maps, gauges and weather are not implemented in this phone increment.
