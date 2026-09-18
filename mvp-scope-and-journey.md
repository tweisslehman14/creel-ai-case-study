# Proposed MVP scope and user journey

September 17, 2026. Incorporates Tom's latest decisions. Scope below is proposed, not an approved implementation plan. No application built in this step.

## Product objective

A private fishing journal for Montana anglers: save a partial memory in the field, enrich it later, and find useful past experience before the next trip. Preserve complete narratives and original media alongside structured facts; completeness is optional.

## Decisions supplied by Tom

- Support real-time, partial and retrospective entries, including photo-only capture.
- Preserve raw/original input alongside LLM interpretations.
- Retain external source distinctions, gauge location/distance and both user-reported and external conditions. Prioritize the user's observations in the journal presentation.
- Initial event vocabulary: Catch, Observation, Trip Context Change. Location context can be automatic; rig/technique changes need explicit user input.
- Reliable offline capture is an MVP requirement.
- Support long narrative recordings, including an approximately five-minute trip account; extraction should not replace the full journal.
- Allow later correction. Automated completeness prompts/validation workflows may come later.
- Minimize external disclosure; do not send GPS to a parsing model when unnecessary.
- Montana geography; investigate reuse from ~/flyfishing.

## Initial retrieval jobs

These recur in the reviewed threads; they are not quantitatively ranked by prevalence.

1. What happened last time I fished this water—what worked, what did not, and what were the conditions?
2. What do I remember about this place—access, particular runs, observations, companions and experiences?

Implement chronological browsing, river/date/type filters, and text search over notes/transcripts and extracted facts. Show source entries, not unsupported recommendations. Similar-condition ranking and natural-language Q&A are later candidates.

## Journey

### 1. Start or resume a trip

Start with date/time and available device location. Suggest a Montana waterbody when resolvable; manual name and unknown location remain valid. Trip title and starting context optional. Start must work offline without loading a map or waiting for enrichment.

### 2. Capture a moment

One prominent Add moment action with Record, Photo and Type options. Event type can be suggested after capture; no required taxonomy decision before recording. Audio, photo, text, or combinations can be saved without all fields filled. Show Saved on this device only after successful local persistence. A photo-only event stays valid, not perpetually marked incomplete.

Save capture time and available location/accuracy. Occurrence time/location may be edited or left uncertain for retrospective entries. Additions must be attachable to an existing event to avoid duplicate catches.

### 3. Record changing context

“Switched to a nymph rig” creates a context-change event with an effective time. Explicit event facts override trip/context defaults; inherited facts remain labeled. Subsequent processing uses occurrence order, not upload order.

Proposed prototype limit: automatic GPS snapshots at event capture and while the app is actively in use, rather than an always-on background route. Full continuous tracking remains a future product option. Movement need not create noisy visible journal entries. Missing tracks must not be drawn as observed routes.

### 4. End the trip or add a debrief

End trip and optionally record a longer story, add companions or observations, or state “no fish caught.” Ending does not lock the journal. A narrative remains one intact source; facts may link to earlier events or remain trip-level observations. Unclear mentions should not automatically create additional catches. Never infer no catches from an empty event list. A forgotten end time can be corrected; elapsed trip time is not necessarily active fishing effort.

### 5. Process and enrich when possible

Queue transcription, extraction and external enrichment independently. Closing/reopening or a failed request must not lose a saved capture or create duplicates. Display simple states: saved locally, organizing, ready, retry needed. Pending entries remain readable/playable.

Parse minimal text payloads: local record IDs rather than coordinates/route history. Prefer transcript-only extraction; original audio may need a transcription service and therefore requires a separately clear data flow. Location names spoken in a note are still location disclosure unless redacted; do not claim full privacy from merely omitting GPS. No photo classification required in first scope. Map/weather/gauge services may receive necessary location queries; do not include them unnecessarily in language-model requests.

Attach externally sourced conditions by occurrence time/location, retaining station/provider, measurement time, units, distance and available flags. Unknown coverage remains unknown. Historical lookup is required for delayed entries; never attach today's reading to an old event. User-reported weather is the primary journal account; external values remain separately accessible. Explicit user corrections take precedence over reprocessing.

### 6. Revisit and edit

Trip timeline contains photos, playable audio, transcript, narrative and a compact set of extracted facts. Allow edits/additions with provenance rather than overwriting original input. Missing optional facts do not require a review step. Prefer “uncertain species” or “time not specified” over uncalibrated model confidence percentages.

### 7. Find a previous experience

Search for a river, fly, wildlife encounter or phrase. Narrow by dates/event type. Open the original entry and inspect its context. Export a trip archive containing structured records and original media; multi-device sync is outside first scope.

## Recommended scope boundaries

| Include | Defer |
|---|---|
| One user/device, private by default | Accounts, collaboration, public sharing |
| Montana names and reusable water/gauge context | Wider geography and statewide downloadable map experience |
| Offline audio/photo/text persistence and replay | Always-on background GPS and route inference |
| Partial entries, long debriefs, later edits | Mandatory completion prompts and elaborate review queues |
| Three event types plus a trip-level journal/debrief | Fully automatic reconstruction of every event from a story |
| Structured extraction with original sources | Automatic fish identification, inferred measurements |
| River/date/type filters and full-text search | Catch predictions, causal effectiveness claims, analytics dashboards |
| Source-aware enrichment when available | Treating missing data as a capture failure |
| Explicit export/backup | Cross-device/cloud media sync |

## Interview build boundary

The first demonstrable slice should complete capture → durable local save → deferred extraction → correction/addition → retrieval. Recommend a mobile-shaped web prototype for reviewer accessibility, conditional on proving offline media persistence on the target browser. It must be hosted/installed or otherwise packaged appropriately; a static HTML mock alone does not establish reliable phone offline behavior.

Use one Montana river and a known linked gauge for the initial demonstration, while retaining manual entries elsewhere. Reuse assets and source-aware enrichment patterns, not FlyCaster's entire application. Gauge/weather integration should be cut back to one real path if time constrained. If enrichment uses a fixture, label it. Keep original recordings and persistence real; those are central to the hypothesis.

An hour cannot be honestly promised for all of the proposed field MVP. Preserve actual research/build time and distinguish the working interview slice from unvalidated field claims.

## Verification criteria

- In offline mode, save audio, photo-only and text entries; close and reopen; confirm originals and metadata remain intact.
- Record and replay a five-minute debrief.
- Reconnect and retry processing without duplicate entries or loss of human edits.
- Add a photo now and details later to the same event.
- Preserve unknowns and original narrative after extraction and correction.
- Apply a rig change to the right later events; handle out-of-order uploads.
- Explicitly record a zero-catch trip without converting unrecorded counts to zero.
- Search and retrieve the correct original entry for both selected user questions.
- Inspect provider payloads for unnecessary location/media disclosure.
- Verify external context time/source; make missing/stale/unrepresentative data visible.

## FlyCaster reuse inspection

Read-only inspection found:
- frontend/src/lib/mapStyle.ts and mobile/components/Map/flyfinderStyle.ts: MapLibre styling/source conventions for owned vector tile endpoints and mobile bundled tiles.
- mobile/assets/tiles/stream_gauges.mbtiles: bundled gauge map asset exists.
- backend/scripts/usgs_fetcher.py and usgs_loader.py: candidate USGS ingestion code.
- backend/services/gauge_capability.py: separates measurement capability from freshness.
- backend/tests/test_conditions_gauge_attribution.py: tests gauge-distance attribution, including distant-source handling.

These are code/asset findings, not verification that services are running, that all data is current, or that reuse will work without adaptation. No FlyCaster files changed and no credentials or private data read.
