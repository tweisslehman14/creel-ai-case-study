# Fishing journal MVP — requirements and development plan

Version 0.3 · September 17, 2026 · Status: native phone builds and launches in simulator; 8 core tests pass; interactive/device acceptance pending; desktop implemented with synthetic workflow validation; remaining acceptance documented

## 1. Objective and scope authority

Build two complementary surfaces:

1. **Phone capture app:** reliably record a trip offline through audio, photos and text. No transcription, LLM processing, maps or external-data integration is required on the phone.
2. **Desktop journal:** import an exported trip package, preserve originals, transcribe and structure useful information, support correction, and retrieve past experiences.

The central promise is: **capture a little now, add more later, and find it when it matters.** This is a searchable journal with optional structured facts, not a requirement to turn every experience into a complete dataset.

This document supersedes the earlier proposed scope wherever it conflicts with the two-stage workflow. The two-stage split, original-source retention, offline reliability, partial entries, privacy minimization and Montana focus reflect Tom's decisions. The manual transfer format, technical architecture, detailed limits and phase boundaries below are proposed implementation defaults.

### Current implementation increment

Tom has requested implementation of the phone capture app from the supplied **Creel — Phone Capture MVP** HTML, ready to run in Xcode Simulator. This increment implements the native phone journey and export contract. Tom subsequently authorized the desktop increment: import, processing configuration, review, recall and backup/restore are now implemented with synthetic end-to-end verification. The phone remains a separate capture surface. A runnable simulator build is a delivery gate, not evidence of physical-device reliability. See [design-review.md](design-review.md) for screen mapping and deliberate departures from the mock.

## 2. User and evidence

Initial user: an individual Montana angler who already takes photos or notes but struggles to preserve context consistently and find it later. One user, one phone and one desktop installation; no accounts required.

Primary questions:
- What happened last time I fished this water, including what worked, what did not and the conditions I recorded?
- What do I remember about this place: access, runs, wildlife, companions and experiences?

Evidence is qualitative, not a market-size or prevalence estimate. Key sources: [original notes discussion](https://www.reddit.com/r/flyfishing/comments/19cjde8/taking_notes_when_fishing/), [documenting locations](https://www.reddit.com/r/flyfishing/comments/1hpvj81/documenting_locations/), [using journal data](https://www.reddit.com/r/flyfishing/comments/1kg45id/do_you_have_a_fishing_journal_if_so_how_do_you/), and [failed voice capture workflow](https://www.reddit.com/r/Fishing/comments/1sw65rz/anyone_have_a_workflow_for_logging_catches_via/). See fishing-notes-research.md and fishing-record-use-cases.md for broader evidence and contrary experiences.

## 3. Release boundaries

| Core MVP: required for completion | Follow-on increment | Deferred |
|---|---|---|
| Offline phone capture and replay | Historical USGS/weather enrichment on desktop | Phone-side transcription/LLM processing |
| Start/end/resume trip; later additions | Small Montana map and river/gauge associations | Continuous background GPS tracking |
| Audio, photo, text and partial entries | Better location-name normalization | Automatic fish/photo identification |
| Manual trip export/import | Completeness suggestions and richer uncertainty review | Accounts, automatic sync, collaboration |
| Desktop transcription and structured extraction | Side-by-side condition comparisons | Public sharing and discovery feed |
| Source-linked review and corrections | Natural-language questions over journal | Catch predictions and causal analytics |
| Multi-trip browsing, filters and search | More export formats | Full offline statewide maps |
| Local archive/backup and restore | Additional platforms after device validation | Automatic reconciliation of every narrative mention |

External enrichment is explicitly **not a core-MVP completion dependency**. It belongs on desktop if added. The phone still captures available coordinates/time so later enrichment is possible. Montana is the initial terminology/data/demo scope; an unknown waterbody never prevents saving a journal entry.

## 4. User journeys and screens

### Phone

**P1 — Trip list:** start a trip or reopen an existing trip, including one already ended/exported. No sign-in or network required after initial installation/setup.

**P2 — Active trip:** show a chronological event list and prominent Record, Photo and Type actions. Display elapsed trip time as elapsed time, not active fishing effort. Ending a trip is explicit and reversible through a correction.

**P3 — Capture/detail:** accept audio alone, photo alone, text alone or a combination. Allow playback/preview, optional type/time edits, attaching more material to the same event, and removal of an accidental capture. Show local save status independently of processing.

**P4 — Finish/export:** optionally add a trip debrief, notes or an explicit zero-catch result. Export a single trip package using a file-save/share flow supported by the tested device. Retain the local trip after export. Show when subsequent changes have not yet been exported.

### Desktop

**D1 — Import/library:** select a package, validate it, preview trip name/date/media totals and import. Previously imported trips remain available after restart.

**D2 — Trip workspace:** timeline with original photos/audio/text, transcripts and extracted details. Pending/failed processing does not block reading the originals. Start/retry processing and edit facts here.

**D3 — Review:** use an inline panel in the workspace rather than a separate mandatory review workflow. Trace each extracted fact to source material; correct, dismiss or leave it uncertain. Optional missing fields do not create overdue work.

**D4 — Recall:** search the library and filter by waterbody, date range and event type. Open a result at its source entry, with surrounding trip context. Include narratives, transcripts, corrected facts and general observations in search.

## 5. Phone functional requirements

| ID | Requirement |
|---|---|
| CAP-01 | Create a stable trip ID with created/start times, timezone and optional title/waterbody/companions. Support manual or unknown location. |
| CAP-02 | Record audio offline, including at least a five-minute debrief. Keep recordings playable locally. |
| CAP-03 | Capture or select photos and enter text offline. Preserve captured/imported source media bytes; make derivatives separately. |
| CAP-04 | Persist each completed capture before displaying Saved on this device. Save failure must be visible and leave a recovery/retry route. |
| CAP-05 | Assign stable event and attachment IDs. Permit multiple attachments per event and later additions without creating another catch. |
| CAP-06 | Capture available GPS/time metadata without waiting indefinitely or requiring permission. Retain accuracy and fix time; stale/absent fixes must not appear current. |
| CAP-07 | Distinguish captured_at from occurred_at. For an immediate entry, occurrence time may default to capture time with a labeled basis; retrospective entries require a supplied time/range or remain unknown. Never assign the car's GPS to an earlier catch implicitly. |
| CAP-08 | Types: Unclassified, Catch, Observation, Context Change, plus trip-level Journal/Debrief entries. Type selection is optional on phone. |
| CAP-09 | Permit end-trip, resume, time correction and retrospective entry. Zero catches must be explicit, not inferred from missing catch events. |
| CAP-10 | Preserve source text revisions and edit history. Deletion is explicit and represented in later exports so old imports do not resurrect it. |
| CAP-11 | Support export offline. Export completion means a package was generated/handed to the save flow, not that another device received it. |
| CAP-12 | Keep offline app shell, trip records and media available after restart. No external request is necessary to capture, replay or export. |

Use short, thumb-friendly controls and text status alongside icons. Offer text if microphone permission fails and file selection if camera access fails. Recording interruption must surface clearly; finalize and persist audio parts approximately every 30 seconds, attached to the same event. Retain a recovery marker for the current part. A crash may leave that unfinished part unplayable; previously committed parts must remain available. Stop and finalize when the app backgrounds or audio is interrupted, and explain that the user must keep Creel open to record. Never claim uninterrupted background recording. Small gaps between sequential parts are a known risk to measure on a physical device.

## 6. Trip package contract

Use a versioned ZIP archive, suggested extension `.fishing-trip.zip`:

```text
manifest.json
trip.json
events.json
media/<attachment-id>.<extension>
```

### Required records

| Record | Minimum content |
|---|---|
| Manifest | schema_version, package_id, exported_at, app_version, trip_id, trip_revision; file list with relative path, byte length, MIME type and SHA-256 checksum |
| Trip | id, revision, title/waterbody if supplied, created_at, started_at, ended_at or null, timezone, optional companions and explicit result summary |
| Event | id, trip_id, revision, type or unclassified, created_at/captured_at, occurred_at or time range/null, occurrence basis, capture location and event location separately, source text/revisions, attachment IDs, updated_at, deletion marker if applicable |
| Attachment | id, event/trip association, relative path, MIME type, size, checksum, capture timestamp if available; optional dimensions/duration and media-origin information |

Use RFC 3339 timestamps with offset or UTC plus trip timezone. Coordinates use WGS84 latitude/longitude; accuracy is meters. Preserve original entered values alongside normalized quantities. Null means unknown; zero is an explicit value. An audio event with no transcript and a photo event with no species are valid.

Package format version is separate from trip/event revision. Reject unsupported major versions with a readable explanation; additive optional fields should not destroy compatibility. Include no API credentials, provider tokens or unrelated device data.

### Integrity and reimport

- Validate manifest, referenced files, sizes, checksums and relationships before committing an import.
- Reject unsafe archive paths, duplicate/conflicting file entries and unreasonable expanded sizes. Do not execute archive contents or render notes as trusted HTML.
- Identical package or unchanged entity revision: no-op, with an Already imported message.
- Newer phone revisions: add source material and update source records while retaining desktop corrections as a separate layer.
- Older revisions: never silently downgrade. Conflicting content for the same revision: report a conflict rather than choose arbitrarily.
- Phone deletion markers hide/remove the associated source in the active desktop view; preserve an explicit recoverable trash history until user purge. A desktop deletion and a later source update require visible resolution rather than silent resurrection.
- An import is atomic: failure leaves the previous library intact. Keep the original imported package as an archive until explicit deletion.

Proposed initial supported test envelope: 100 events, 50 photos and 30 total audio minutes per trip, including one continuous five-minute recording, up to 250 MB expanded. Limits are engineering targets to validate on the selected phone, not measured capabilities. Warn before capture/export exceeds supported storage limits; never silently discard media.

## 7. Desktop processing and review

| ID | Requirement |
|---|---|
| DESK-01 | Import package locally, show validation outcome and retain durable records/media across restarts. |
| DESK-02 | Transcribe audio through an interchangeable provider; preserve original audio and raw transcript separately from edited transcript. |
| DESK-03 | Extract optional facts from text/transcripts using a validated output schema. Reject malformed output without damaging the journal. |
| DESK-04 | Every proposed fact references its source event/attachment and supporting text span; timestamp spans where supplied by transcription. Record processor/model/prompt version and processing time. |
| DESK-05 | Do not infer missing species, measurements, counts, locations or time. Preserve ambiguities, estimates and user-reported distinctions. |
| DESK-06 | Keep long debriefs intact. Do not automatically duplicate prior catches based on summary mentions; uncertain associations stay as narrative/trip-level facts for optional review. |
| DESK-07 | Apply explicit context changes by effective occurrence time, not import order. Preserve inherited-versus-explicit attribution. Ambiguous timing must not propagate context as fact. |
| DESK-08 | Make editing possible without model processing. Human corrections override derived values and remain intact when sources are reprocessed. |
| DESK-09 | Track processing jobs by source revision/hash and processor version. Retry only necessary stages; do not duplicate facts/events. Show partial success and actionable failures. |
| DESK-10 | Persist search results across app restart through a durable index or rebuildable index over stored content. Support the two retrieval jobs without requiring a chat interface. |
| DESK-11 | Export/restore a desktop archive containing originals, source revisions, transcripts, interpretations and corrections. This is separate from the phone transfer package; no reverse sync required. |

Initial extracted fields: event type, user-stated species/count/size, fly/lure/pattern/color/size, technique/rig, user-mentioned place/time, user-observed conditions, wildlife/access observations and companions. All optional. Keep unmodeled content searchable as narrative; do not add a large taxonomy just to structure every sentence.

Use Uncertain or Not specified where justified; do not present model-generated confidence percentages as calibrated reliability. Automated completion prompts are deferred.

## 8. Privacy, storage and data flow

Default phone storage and desktop library are local and private; no account, telemetry or public sharing in MVP. Local storage is not a backup: provide explicit export/archive guidance and do not promise protection against device loss or user-cleared storage.

Data flow:

```text
Phone originals + metadata
  → manual trip package
  → local desktop import
  → audio-only transcription where needed
  → minimal text extraction request
  → source-linked facts + human corrections
  → local journal search
```

Before external processing, show provider and data categories being sent. Store API secrets only in the desktop service environment/key store, never phone/browser bundles or archives. Do not start billable requests until provider and cost settings are configured explicitly; no paid fallback.

Send no GPS, EXIF, route history or photos to a text-extraction provider unless required by an explicitly selected feature. Use opaque local IDs. Spoken/written place names may still occur in content: either redact locally or clearly disclose that note content is transmitted. External transcription may receive the original voice, including spoken personal details; “private by default” does not mean all processing is on-device. Do not send the entire journal to process one new entry.

Treat imported text and model output as data, not instructions; extraction gets no execution privileges. Desktop service should bind locally for the private MVP. A publicly accessible hosted version with private media would require a separate access-control design.

## 9. Recommended architecture and reuse

**Locked for this increment:** a native SwiftUI iOS app, using local app storage, native audio/photo/location facilities and a versioned ZIP export. Native delivery follows Tom's explicit Xcode Simulator request and avoids making browser capture feasibility a prerequisite. Use no network service, external AI provider or account in the phone implementation. The desktop increment uses a Python standard-library service bound to loopback, SQLite records, local original files and a static HTML/JavaScript/CSS interface matching Creel. Core import, reading, editing and search must work without AI configured. Transcription/extraction adapters are configurable; no external data transmission or billable calls are authorized by configuration alone.

Store metadata atomically and source media as separate immutable files. Save media before committing references; a failed metadata write must not produce a false success state. Validate originals against checksums before export. Audio parts belong to one event, not multiple catches. Recovery must tolerate interruption between media and metadata writes. Keep exact file-transfer status distinct from local persistence.

Native modules live in `creel-ios/`: models and persistence/export, device services, and SwiftUI screens. Select APIs supported by the deployment target and prove the project builds in the installed simulator runtime. Test the package with an independent ZIP reader. Physical camera capture, actual microphone quality, lock-screen/interruption behavior, storage pressure and five-minute offline audio remain physical-device acceptance gates even when simulator checks pass.

Inspect FlyCaster for reusable patterns rather than making this MVP depend on its entire stack. Prior read-only inspection found MapLibre map assets, bundled gauge tiles, USGS ingestion code, gauge capability/freshness logic and distance-attribution tests. These matter for the follow-on enrichment phase; core capture/import can proceed independently. Do not modify FlyCaster or copy credentials as part of this plan.

Follow-on enrichment must use event-time historical observations and retain station/provider, units, observed/retrieved times, distance and quality flags. User-reported conditions remain primary in the journal presentation; external conditions coexist separately. Unknown data never blocks use. OSM tile/provider permissions and historical weather coverage require verification before implementation.

## 10. Development plan and completion gates

Status is evidence-based. Mark work complete only after the listed gate passes; keep physical-device and desktop gaps visible.

| Workstream | Status | Evidence / next gate |
|---|---|---|
| HTML design review and scope reconciliation | Completed 2026-09-17 | Screen mapping and decisions in design-review.md; no runtime claim |
| Native phone architecture and package contract | Core verified 2026-09-17 | Build passes; 8 core tests verify persistence, correction history, standard ZIP and checksums; hardware recovery pending |
| Native capture journey | Implemented; acceptance pending | Voice/photo/text, revisions, retrospective timing, end/reopen, local search and export in source; interactive walkthrough blocked by locked Mac |
| Simulator delivery | Build/install/launch verified 2026-09-17 | Xcode 27, iPhone 17 Pro/iOS 26.5; UI walkthrough requires unlocked Mac. See creel-ios/VALIDATION.md |
| Physical-device field validation | Not started | Five-minute capture, hardware camera, interruption and offline checks required |
| Desktop library, processing and recall | Implemented; acceptance in progress 2026-09-17 | Browser import/review/search/backup and local synthetic extraction/transcription verified; broader field and recovery gates remain |

**Result (2026-09-17, design review):** adopt Creel's visual language and capture-first flow; remove mock GPS/river guesses, simulated errors, and desktop transcript writeback claims. Voice prominence remains a hypothesis to validate, not a research-proven preference.

| Phase | Work | Completion gate |
|---|---|---|
| 0 — Feasibility and contract | Use native iOS and the installed Xcode Simulator; define package schema and fixtures; prove persistence/export | Simulator builds/launches and exported package opens with matching checksums. Track real-phone five-minute audio/restart validation separately; native choice is locked for this increment. |
| 1 — Capture journey | Trip lifecycle, timeline, audio/photo/text, GPS metadata, partial entries, later additions, revisions and export | Complete a mixed-media offline trip and export it without loss. Permission-denied and storage-error paths are visible. |
| 2 — Desktop library | Import validator, durable originals, timeline/playback, duplicate handling and archive backup/restore | Import/reimport/update/corrupt-package cases behave correctly; original bytes match phone export; restore reproduces the library. |
| 3 — Processing | Transcription adapter, extraction schema, source links, job states/retry and context logic | Process an example trip; preserve narrative/unknowns; failures are recoverable; later debrief does not double-count catches. |
| 4 — Review and recall | Corrections, source inspection, text search and filters across trips | Human edits survive reprocessing; both retrieval questions return correct supporting entries. |
| 5 — Acceptance and demo | Real-device offline checks, transfer round trip, privacy payload review, demo seed data and Loom evidence | Acceptance matrix below passes; publish explicit limitations and actual time spent. |
| 6 — Optional enrichment | Small Montana river/gauge integration, historical weather, source context | Event-time lookup works, missing data is explicit, and provenance/distance are visible. Not required for core release. |

### Interview timebox

For the current phone increment, complete one trip with audio/photo/text, later additions, end/resume and an actual exported package first. The broader interview end-to-end slice would then add real desktop import, transcription/extraction, editing and basic search. Do not imply those desktop capabilities ship with the phone app. Do not spend the initial hour on maps, accounts, background tracking, dashboards or advanced matching.

The interview slice is not automatically the full field MVP. Track actual elapsed research and build time. If the timebox ends with incomplete capabilities, label them rather than describing the prototype as validated field software. Offline persistence and original retention are not acceptable simulated shortcuts.

## 11. Acceptance scenarios

| ID | Scenario | Required result |
|---|---|---|
| A1 | Install/setup once, then disable connectivity and restart | App opens; start/capture/replay/end/export work without network. |
| A2 | Save text, photo-only event and five-minute audio; close/reopen | All completed captures remain playable/readable with correct associations. |
| A3 | Interrupt recording or exhaust available storage | No false Saved confirmation; interrupted/recoverable state is clear. Previously saved entries remain intact. |
| A4 | Deny GPS/camera/microphone selectively | Available input alternatives work; absent metadata is null rather than fabricated. |
| A5 | Add details later to the photo-only event | Same event gains a revision; original remains; retrospective time/location is handled explicitly. |
| A6 | Export/import and repeat import | File checksums match; no duplicate trip, attachment or event. |
| A7 | Import newer/older/conflicting revisions and deletions | Correct source revisions retained; no silent downgrade, overwrite of corrections or resurrection. |
| A8 | Import missing/corrupt files, unsupported schema or unsafe paths | Reject cleanly before mutation, with understandable errors. |
| A9 | Provider outage, malformed extraction, retry or app restart | Originals remain usable; processing can resume without duplicate records. |
| A10 | Sample “nice rainbow on an elk hair caddis” | Reported species/pattern extracted; fish size and fly size remain unknown; source linked. |
| A11 | Rig change and out-of-order note import | Correct temporal context applied; conflicting/unknown time remains explicit. |
| A12 | Debrief mentions catches already captured | Preserve story without inflating counts; ambiguous links not silently resolved. |
| A13 | Explicit zero-catch trip versus no recorded catch events | Distinct states preserved in display/search. |
| A14 | Correct an extracted field and reprocess | Human correction remains authoritative; original and prior interpretation traceable. |
| A15 | Search river, fly and wildlife phrase across at least three trips | Relevant source entries returned, including narrative-only information. |
| A16 | Inspect outbound processing requests | No unnecessary coordinates, photos, EXIF, credentials or other trips' content transmitted. |
| A17 | Backup and restore desktop archive | Originals, corrections and journal/search content preserved. |

Record capture interaction time, import/export duration, processing latency, correction burden and lost/duplicate events during testing. Do not invent performance targets or success rates from the Reddit evidence; acceptance requires zero lost completed captures and zero duplicates in the specified test scenarios.

## 12. Remaining implementation choices

- Physical iPhone/OS for field validation remains to be selected. Native iOS and Xcode Simulator are locked for this increment; desktop local implementation is now underway.
- Local versus external transcription/extraction provider and allowed cost; configure before external processing.
- Initial media format compatibility and package-size envelope; verify rather than assume.
- Packaging for reviewer access: local desktop app instructions plus a demonstrable capture app, or a separately designed hosted demo using synthetic/public sample records.

No unresolved choice blocks reviewing this document. They are setup decisions for development, not reasons to expand scope.


## 13. Adapted agent workflow

Use the role boundaries from `~/flyfishing/` without importing its application architecture or altering that project. Keep this document as this case study's single living requirements/plan record.

- **Product manager:** owns requirements, design reconciliation, acceptance gates and evidence/status wording. Reads code to identify gaps; does not edit implementation or tests.
- **Senior developer:** owns architecture, integrity/recovery decisions, integration and final technical review. Resolves cross-file contracts; the coordinating agent assigns bounded tasks.
- **Junior developer:** implements a concrete, isolated assignment against the agreed interfaces and reports verification and remaining gaps. Does not independently expand product scope.
- **Coordinating agent:** partitions file ownership, integrates results, runs simulator acceptance and records actual completion evidence. No phase is declared complete from an agent's implementation report alone.

Prioritize integrity and a working trip flow over decorative detail. The supplied HTML remains unchanged as the design reference. Do not ship its sample data as the user's journal, simulated save/export actions, a development-only errors menu, or unsupported claims about GPS and transcription.

## 14. Phone delivery evidence

See [run instructions](creel-ios/README.md), [validation and remaining gates](creel-ios/VALIDATION.md), and [agent working agreement](CLAUDE.md). The native app is implemented and builds/launches; the full capture acceptance gate remains open until interactive and physical-device checks pass.

**Result (2026-09-17):** eight core tests pass. Export streams files and rejects trips above 250 MB. Photo imports default to unknown occurrence/location; camera captures can use capture-time defaults. Dirty notes and pending photos resist dismissal. Trip end/outcome can be corrected directly. Explicit debrief capture creates a Journal event. Prior text and metadata corrections remain in the package. Physical microphone/camera and five-minute recovery behavior are not yet validated.


## 15. Desktop implementation increment — started September 17, 2026

Implement a local desktop journal in `creel-desktop/`. The interface should retain Creel's parchment background, dark ink, orange primary action, sage status accents, rounded surfaces and plain language. Desktop space enables a library alongside a trip timeline and selected source entry; it does not justify adding a mandatory data-entry form.

### Focused journey

1. **Import preview:** select the actual phone ZIP; validate before changing the library; show trip, date, moment/media totals and whether this is new, unchanged or an update. Explain a rejection with the prior library intact. A preview does not count as import success.
2. **Library:** retain imported trips across restart; distinguish explicit zero catches from unspecified; open a trip or find it through waterbody/date/text filters.
3. **Trip and originals:** show chronological moments, full notes, image previews and original audio parts, with captured-versus-occurrence time and source location distinctions. Unknown time remains unknown. Deleted source entries are not included as active search results.
4. **Processing:** core journal works while unconfigured. Present provider/model and outgoing data categories before explicitly initiating processing. Audio transcription and text extraction are separate recoverable stages. No silent fallback, no invented transcript and no claim of AI processing for manual/rule-based data.
5. **Review:** show proposed fields beside supporting source text/audio. Accept, correct or dismiss without changing the original source. Keep the complete narrative. Reprocessing or a newer phone import must not overwrite human corrections; stale derivations must be labeled or regenerated.
6. **Recall:** search notes, available transcripts and corrected facts; results identify the matching source moment and open its trip context. Provide waterbody/date/type filters without requiring chat.
7. **Backup/restore:** export a separate desktop archive containing sources and review state. Validate before restore; clearly describe whether restore replaces or merges the library. Preserve the existing library on failure and require an explicit confirmation before replacing existing data.

### Contract compatibility and trust gates

Use the current phone exporter as the schema authority. Its JSON uses snake_case; events carry `kind` values `unclassified`, `catchFish`, `observation`, `contextChange`, or `journal`. Attachments are nested inside events; `trip.json` contains an empty `moments` array and actual events live in `events.json`. Optional fields can be omitted. Preserve text/correction histories and deletion markers, and accept valid optional additive fields without discarding them.

Check relationships in addition to hashes: manifest trip ID/revision must match the trip; every event must belong to that trip; event and attachment IDs must be unique; attachment paths, sizes and checksums must agree with the manifest and ZIP. Reject unsafe paths, duplicate ZIP entries, oversized expansion and unsupported schema majors before commit. Stage new media separately and commit only after complete validation.

Reimport cannot use package ID alone: the phone generates a fresh package ID on every export. Compare stable trip/event IDs, revisions and source content. Identical source is a no-op; older source never silently replaces newer source; equal revision with different content is a conflict. Desktop corrections and transcripts live in their own layer. Newer source changes invalidate dependent derived facts without erasing user judgment.

Current default is local-only processing: installed Ollama with llama3.1:8b and local whisper.cpp with base.en. No cloud/private-payload or billable request was used. Future cloud processing would require a separate explicit choice and authorization. An adapter that has not run successfully must be labeled configured/unverified or unavailable, not working. Local model prerequisites and provider failures must be explicit. Keep credentials out of browser responses, archives and source control.

Detailed acceptance scenarios and evidence ledger: [creel-desktop/ACCEPTANCE.md](creel-desktop/ACCEPTANCE.md). The desktop prototype is implemented and has synthetic workflow evidence; acceptance is partial as recorded below. The phone's passing tests do not count as desktop evidence.


### Desktop evidence — September 17, 2026

The coordinating developer reported a passing initial 28-test desktop run, with additional regression tests still being finalized. Do not treat 28 as the final test count; final evidence belongs in the acceptance ledger.

Browser checks covered the empty layout, import preview and import of synthetic packages generated by compiling the actual Swift phone exporter, preservation of the original note after saving a desktop note, keeping/correcting a species proposal, a “shaded bank” search result and creation of a downloadable desktop backup. Three synthetic phone-format packages were generated; this is not a transfer from the user's physical phone.

An actual local llama3.1:8b extraction with the v2 prompt produced five proposals: rainbow trout, fly size 16, elk hair caddis, main run and wind. Each had an exact supporting quote. Quote location is matched deterministically only when unique; exact quotation proves source correspondence, not semantic correctness. The UI keeps the user's review step and makes no calibrated-confidence claim.

Local whisper.cpp with base.en transcribed a synthetic spoken fixture as “caught a rainbow trout on an elk hair caddis.” This verifies a local adapter run, not riverside microphone quality or the full HTTP audio-import journey. That end-to-end audio check is still underway at this documentation update. Core backup/restore tests passed; real field audio, the user's own phone export and physical-device capture remain open. No phone code changed in this desktop increment.

## Desktop delivery result — September 17, 2026

The local desktop app is implemented and running at http://127.0.0.1:8767. **38 tests pass.** Browser checks verified import preview/commit, original-versus-review separation, local extraction proposals/acceptance, search and backup creation. A full synthetic M4A → actual Swift ZIP export → desktop import → local transcription → local extraction → archive → empty-library restore round trip passed. Four trips, seven events, one audio original and desktop corrections/search survived restoration. See [desktop validation](creel-desktop/VALIDATION.md) for exact evidence and limits.

Local processors configured on this Mac: installed `llama3.1:8b` through Ollama and whisper.cpp 1.9.4 with the English base.en model. No cloud/billable inference was used. The core remains usable without either service. Physical-phone exports and realistic field audio remain acceptance work. Backups currently enforce a 250 MB total expanded limit, including stored original archives; large-library capacity is not claimed.
