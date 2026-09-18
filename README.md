# Creel

Creel is a private fishing journal that separates quick, offline iPhone capture from later review, organization, and search on a desktop.

This project was built for a Wrapbook AI usage case study. The goal was to start with a real Reddit complaint, use AI throughout discovery and development, and preserve the decisions and failures that shaped the result—not merely present a polished final screen.

## Explore the case study

- **Interactive walkthrough:** [Creel on GitHub Pages](https://tweisslehman14.github.io/creel-ai-case-study/)
- **Starting Reddit thread:** [Taking notes when fishing](https://www.reddit.com/r/flyfishing/comments/19cjde8/taking_notes_when_fishing/)
- **Research synthesis:** [fishing-notes-research.md](fishing-notes-research.md)
- **AI process and iterations:** [process-log.md](process-log.md)
- **Initial case-study answers:** [case-study-initial-answers.md](case-study-initial-answers.md)
- **Five-minute Loom:** pending

The Pages experience is a static, synthetic walkthrough for convenient review. The native phone capture and local desktop processing applications are the working implementation.

## The problem

Anglers described valuable uses for fishing records—remembering a river at a particular flow, returning to access points, comparing successful and unsuccessful approaches, and preserving personal memories. They also described abandoning logs because detailed entry interrupted fishing, accumulated into a backlog, or produced notes that were difficult to retrieve later.

My working hypothesis became narrower than “build a better fishing database”:

> Help an angler who already values a journal preserve a partial observation in the field, then turn it into a trustworthy, searchable record later.

This is a qualitative hypothesis from a small, self-selected set of Reddit threads. It is not evidence of prevalence, willingness to pay, or improved fishing outcomes.

## What works

### iPhone capture

The native SwiftUI app records trips and partial voice, photo, or text moments without a network connection. A trip remains editable and exports as a versioned `.fishing-trip.zip` containing the structured record and original media.

[Open the Xcode project](creel-ios/Creel.xcodeproj) or follow the [iPhone run instructions](creel-ios/README.md).

### Desktop journal

The local desktop app validates and imports a phone package, preserves immutable originals, supports corrections and notes in a separate review layer, searches the journal, and creates restorable backups. Optional local Whisper and Ollama integrations transcribe audio and propose source-linked facts. AI output remains a proposal until the user accepts or corrects it.

The core journal has no third-party Python dependencies:

```sh
cd creel-desktop
python3 server.py
```

Open the printed local URL and import one of the clearly labeled packages in [`creel-desktop/samples/`](creel-desktop/samples/). Local model installation is optional; see the [desktop instructions](creel-desktop/README.md).

## How AI changed the product

AI helped search and synthesize related Reddit discussions, inventory what anglers record, critique the initial concept, turn decisions into requirements, implement both applications, and generate tests. The useful moments were often corrections:

- Research challenged the assumption that capture was the only problem; later retrieval value and willingness to journal were separate questions.
- The initial idea included maps, GPS, weather, and USGS gauges. I cut those integrations from the MVP and split reliable phone capture from desktop processing.
- Product, senior-development, and junior-development agent roles reviewed scope, data integrity, recovery behavior, and implementation in parallel.
- The first local extraction returned plausible facts with invalid source offsets, so every proposal was rejected. The implementation now requires an exact supporting quote and resolves a unique span locally.
- An intermediate prompt interpreted “main run” as a waterbody. A revised prompt distinguished a named river or lake from a place within it; suggestions still require human review.
- Export testing reinforced that creating a package is different from successfully transferring it to another device.

The full chronology and prompt-level decisions are in the [process log](process-log.md).

## Verification

| Surface | Verified | Still open |
|---|---|---|
| iPhone | Native app builds and launches in the iOS Simulator; eight core persistence/export tests pass; the project owner completed a simulator trip and generated an export | Physical-device camera, microphone, interruption, low-storage, and field testing |
| Desktop | 38 tests pass; browser import, review, search, and backup work | Large-library performance and arbitrary-library merge restore |
| Local AI | Synthetic audio completed phone export → import → Whisper transcript → Llama proposals → backup/restore | Real riverside audio quality, accents, and broader model evaluation |
| Data integrity | Hashes, revisions, duplicate imports, immutable originals, review history, and unsafe archives are covered | Long-term multi-device synchronization |

Exact quotes establish traceability, not semantic correctness. Synthetic samples are not user catches. See the detailed [phone validation](creel-ios/VALIDATION.md) and [desktop validation](creel-desktop/VALIDATION.md).

## How data could arrive over time

The implemented boundary is a versioned trip package with stable trip, event, attachment, and revision identifiers. Reimport is idempotent, and a newer phone revision does not erase desktop review.

A next iteration could watch an opt-in sync folder and process new revisions automatically. Separate enrichment jobs could match an event to OSM-derived waterbody data, retrieve a historical USGS observation, and retrieve historical weather. Each value should retain its provider, station or area, units, observation time, matching method, and distance. Missing or stale data should remain visible, user observations should remain distinct, and private coordinates should not enter a language-model request unless required.

## Repository map

| Path | Purpose |
|---|---|
| [`creel-ios/`](creel-ios/) | Native SwiftUI capture app and tests |
| [`creel-desktop/`](creel-desktop/) | Local desktop journal, processing adapters, and tests |
| [`docs/`](docs/) | Static reviewer walkthrough published through GitHub Pages |
| [`Creel - Phone Capture MVP.html`](Creel%20-%20Phone%20Capture%20MVP.html) | Original visual and interaction prototype |
| [`requirements-and-development-plan.md`](requirements-and-development-plan.md) | Product requirements, architecture, and status |
| [`fishing-record-use-cases.md`](fishing-record-use-cases.md) | Inclusive inventory of how Reddit users use records |

## Privacy and scope

The phone app makes no network requests. The desktop service binds only to loopback. Core import, review, search, and backup work without an AI provider. Local model files, personal journal data, generated build products, and machine-specific Xcode state are excluded from this repository.
