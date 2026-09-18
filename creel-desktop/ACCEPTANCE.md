# Desktop journal acceptance

September 17, 2026 · Status: desktop implemented; synthetic/browser acceptance partially verified.

This ledger separates required behavior from observed evidence. Passing phone tests does not establish desktop import, processing or recovery. Do not mark an adapter verified without an actual successful run under an authorized configuration.

## User journey

Import preview → library → trip originals → optional processing → review/correction → source-linked search → desktop backup/restore.

The journal remains usable with processing unconfigured. No audio, location, photo, note or API request leaves the machine merely because a package was imported. UI styling follows Creel's parchment, ink, orange, sage and rounded surfaces. Every empty/error state should explain the next useful action.

## Acceptance ledger

Rows distinguish browser evidence, local adapter runs and remaining end-to-end checks. Results below were reported by the coordinating developer on September 17, 2026; unresolved scenarios stay pending.

| ID | Exercise | Required result | Evidence / status |
|---|---|---|---|
| D01 | Import an actual phone-exported mixed-media ZIP | Preview correct trip/counts; commit originals with matching hashes; notes and audio/photos readable | Partial: browser preview/import passed using actual Swift-exporter synthetic packages; physical-phone mixed-media transfer pending |
| D02 | Restart desktop service/browser | Library, originals and desktop edits persist | Passed with synthetic trip/desktop note across server restart; repository reopen tests cover originals |
| D03 | Import identical ZIP and re-exported unchanged trip with new package ID | No duplicate trip/events/media; understandable unchanged result | Passed: core tests and full HTTP duplicate import |
| D04 | Import newer revision, older revision and same-revision conflicting content | New source updates; old source cannot downgrade; conflict reported; human corrections retained | Passed in core regression tests |
| D05 | Corrupt checksum, remove referenced media, mismatch event trip ID | Reject before mutation; previous library remains usable | Passed in core regression tests |
| D06 | Unsafe ZIP path, symlink, duplicate path, excessive expanded size, unsupported major schema | Reject cleanly; no writes outside staged import/library | Unsafe paths/symlinks/duplicates/schema covered by tests; field-scale size pressure untested |
| D07 | Import partial events, unknown occurrence/location, explicit zero catches, deleted event | Partial entries accepted; unknown not fabricated; zero distinct; deletion absent from active timeline/search while retained in source history | Source preservation/deletion tests pass; synthetic zero-catch and voice-only packages imported |
| D08 | Import and browse without provider/model credentials or network | Full originals/manual review/search work; processing honestly unconfigured | Browser manual note save/read verified with original preserved; explicit network-disabled whole-flow check pending |
| D09 | Configure adapter and inspect outbound request without sending private data | Explicit run action; minimal intended payload; no location/EXIF/photo/unrelated records; secrets absent from browser/archive | Local-only configured; no cloud/paid requests. Mocked request inspection tests verify excluded metadata; actual local runs used synthetic text/audio |
| D10 | Successfully transcribe authorized fixture or run configured local model | Original audio unchanged; raw transcript separate from edits; processor/model/time/source hash retained | Passed adapter and full Swift-package HTTP audio transcription/extraction flow |
| D11 | Extract facts from “nice rainbow on an elk hair caddis” | Species/pattern only if stated; sizes unknown; supporting source linked; no invented confidence | Actual local llama3.1:8b v2 run: species rainbow trout, fly size 16, fly elk hair caddis, place main run, weather wind with exact quotes; size-free synthetic voice yielded species/fly and no size |
| D12 | Provider failure, malformed output, partial run, service restart and retry | Originals usable; clear failed stage; no duplicates or overwritten human corrections | Malformed/provider error and raw-correction tests pass; unchanged actual job returned no-op; forced mid-job service death not exercised |
| D13 | Debrief repeats catch and context change has ambiguous time | Full narrative retained; no silent extra catch or asserted context inheritance | Conservative context regression tests pass; extraction never creates extra events |
| D14 | Accept/correct/dismiss a fact, then reprocess or import revised source | Human judgment remains separate and authoritative; outdated derivation visible; source trace retained | Browser keep/correct species passed; core regressions verify retained review across source/processing changes |
| D15 | Search across three trips by river, fly, wildlife and date/type | Matching source moment identifiable and opens; notes/transcripts/corrections included; deleted entries excluded | Browser search “shaded bank” returned imported trip; HTTP search across four trips includes voice-only transcript; core tests cover filters; full browser filter matrix not exercised |
| D16 | Backup, restore into clean library, then test corrupt restore | Originals, source history, transcripts and corrections match; corrupt restore leaves current library untouched | Core backup/restore tests passed; browser backup creation produced download. 38 total regression tests passed; actual four-trip backup restored and search verified |
| D17 | Restore over nonempty library | Clear replacement/merge semantics and explicit confirmation before mutation | Nonempty restore rejected by design and tests; UI states empty-library requirement |
| D18 | Notes contain HTML/script or instructions for the model | Render as text; no script execution or tool privilege; source facts remain source data | Model-injection tests pass; UI escapes dynamic content and CSP forbids inline script; malicious-content browser scenario not separately run |

## Highest-priority trust checks

- Compare stable source IDs/revisions/content, not package ID: every fresh export can have a new package ID.
- Validate nested attachments against manifest and actual bytes. Checksums alone do not prove event-trip relationships are valid.
- Preserve originals plus separate desktop layers. Never write corrections into phone source fields or let reprocessing replace human decisions.
- Handle each 30-second audio part and record its identity. A whole-trip transcript must not lose source links or silently duplicate adjacent parts.
- Keep unconfigured, failed, proposed and accepted states distinct. Working journal features do not imply a working transcription provider.
- Bound archive expansion before committing. Backup must include database state and originals consistently, not copy a live database in a way that loses pending writes.
- Loopback-only binding is a requirement; browser-facing write routes also need protection against unintended cross-origin mutation. No remote hosting is implied.

## Recording results

For each verified scenario record test command or manual steps, fixture identity, expected versus observed outcome, date and remaining limitation. Use only synthetic/public fixtures for model checks unless Tom authorizes the actual private payload. Record cloud provider/model/cost authorization independently from code/configuration status.


## Current evidence boundaries

Final desktop suite: 38 tests passed. Four synthetic packages were generated by compiling the actual phone exporter. Local Llama extraction and local Whisper synthetic speech were executed; they are not mocked successes. No cloud or paid requests ran.

Browser import, manual notes, species review, one text search and backup creation were exercised. The full imported-audio HTTP flow and actual archive restore passed with synthetic data. Real field audio, a user's own exported trip and physical-phone transfer are still pending. A unique exact source quote establishes traceability, not that the model's interpretation is correct; user review remains required.

## Final coordinator evidence

Final regression suite: **38 tests passed, 0 failures**. Full synthetic HTTP audio trip flow passed (Swift-exported M4A package, local Whisper transcript, local Llama species/fly proposals, unchanged-job reuse, backup download). Restored that actual backup into a fresh library and confirmed four trips, seven events, one original audio attachment, desktop review and search. Final production app opened at http://127.0.0.1:8767 with an empty library. See VALIDATION.md; physical-phone transfer and real fishing audio remain pending.
