# Creel phone design review

September 17, 2026 · Supplied HTML reviewed; implementation acceptance pending.

Reference: [Creel — Phone Capture MVP.html](Creel%20-%20Phone%20Capture%20MVP.html). This is an interactive design mock, not evidence that audio, persistence, GPS or export already work. The central phone is the app; the surrounding navigation and rationale are presentation material.

## Design adopted

Keep the warm parchment background, dark ink, orange primary action, sage accents, rounded cards and large readable typography. Use the supplied heading/body fonts where practical, with legible native fallbacks. Preserve the reassuring, low-pressure copy and a prominent Record / Photo / Type control row. An unlabeled photo or recording is a valid entry. Type assignment happens afterward and is never required.

| Design screen | Native implementation requirement | Acceptance evidence needed |
|---|---|---|
| Your creel | Empty state, start trip, reopen previous trips, own-text search | First launch has no fabricated journal entries; persisted trips survive relaunch |
| Starting out | Optional title, waterbody and companions; captured start time | Empty optional fields never prevent starting; actual location can remain unknown |
| Active trip | Chronological moments, elapsed time, capture actions, end trip | Elapsed time is not described as active fishing effort; save and reopen event |
| Recording | Timer, stop/save, raw local audio, understandable failure state | Completed parts playable; stop/background/interruption semantics truthful |
| A moment | Original media, editable note, optional type, attach more material | Adding media revises same event; source bytes/text revisions retained |
| When was this? | Capture time separate from occurrence time, earlier/range/unknown | Retrospective correction preserves original capture time and GPS without assigning it to earlier event |
| Type a note | Actual entered text, explicit save | Failed save retains editable content and never shows Saved |
| Wrapping up | Optional debrief, end time, explicit outcome | Zero catches remains different from unspecified; ended trip can reopen |
| Hand it over | Actual ZIP package, file share/save, revision status | Independent archive/checksum verification; generating/sharing never claims another device received it |
| Find something | Search local trip metadata and entered text | No promise of transcripts or desktop writeback in this increment |
| Error examples | Actual contextual permission/interruption/storage errors | No shipped “simulate error” menu or hardcoded capacity claims |

## Deliberate changes from the mock

1. **Native phone app.** Tom requested Xcode Simulator delivery. SwiftUI replaces the conditional mobile-web proposal; the desktop surface and transfer contract remain separate.
2. **Truthful location.** Remove the sample Madison River guess and fixed “40 seconds ago, ±18 m” data. No map/name resolver is included. Show manual waterbody and actual fix accuracy/time if available; absent or stale location remains unknown and never blocks capture.
3. **Truthful connectivity.** Replace the mock's permanent “Offline · fine” indicator with a local-storage statement such as “On this phone.” Offline operation is a capability to test, not a simulated network state.
4. **Recoverable audio.** Finalize approximately 30-second audio parts under the same event. Keep originals and a pending-part recovery marker. Stop and finalize on background/interruption rather than promising background capture. A crash can lose an unfinished part; completed parts must survive. Measure transition gaps and five-minute capture on hardware before claiming field reliability.
5. **Original media.** Prefer original photo data supplied by the system picker/camera path. Do not silently re-encode an imported image and describe it as byte-identical. Any transformed capture must have an honest origin description. Verify the exported file against the locally captured/imported source.
6. **Transfer status.** Package generation, presenting a share sheet and confirmed activity completion are different states. None proves desktop receipt. Preserve phone records and show when later revisions need another export.
7. **No reverse synchronization.** The mock mentions desktop-written-back content in phone search. Remove that promise: the existing requirements explicitly require no reverse sync. Desktop transcript search remains future desktop work.
8. **Voice preference is unproven.** The rationale says research proves voice is what users manage mid-river. The threads do not establish that general claim. Prominent voice capture is a design hypothesis; photo and text must remain equally available alternatives.

## Review gates and remaining risks

A simulator build can establish that navigation, local persistence and file generation work in that environment. It cannot alone establish hardware camera behavior, intelligible riverside audio, microphone permission routing, cold weather handling, OS interruption recovery or device storage-pressure safety.

Before calling this a field-ready MVP, test five-minute audio with part transitions; foreground/background and forced termination; fresh/denied/stale location; original photo format preservation; save/export failure; relaunch; add-after-export; and an independently read ZIP with matching hashes. A retained recovery file is not itself a recovered playable recording.

The planned 250 MB trip envelope is unverified. Export now streams file output, verifies originals and enforces a 250 MB ceiling. A capture-time storage warning and physical-device envelope validation remain outstanding.

An initial source review found implementation underway for local metadata/media storage, audio parts and ZIP export. This is architectural evidence only: it is not a claim that these paths build, run or pass acceptance. The coordinating developer will record verified results separately.

## Implementation review results

The coordinating implementation addressed the review findings: explicit ID decoding, durable metadata correction history, preserved recording errors, streaming export, unknown occurrence/location for historical photo imports, dirty-note/photo dismissal protection, direct trip end/outcome correction, explicit Journal debrief type and a distinct unreadable-photo state. See [validation evidence](creel-ios/VALIDATION.md); build/core tests passed, while visual and hardware acceptance remain pending.
