# Wrapbook AI usage case study — initial answers

Drafted September 18, 2026. This is a first-person working draft for the submission and five-minute Loom, not a claim that every future-looking capability is implemented.

## What problem did I start with?

I started with [Taking notes when fishing](https://www.reddit.com/r/flyfishing/comments/19cjde8/taking_notes_when_fishing/). The thread contains several different reasons anglers keep records: remembering what a river looked like at a given flow, learning from successful and unsuccessful outings, and preserving memories. It also contains the central tension I wanted to explore: detailed records can be valuable later, but capturing them can turn fishing into work.

I used AI to broaden that initial thread into related discussions rather than treating one comment as a complete market signal. The most useful supporting threads were:

- [Documenting locations](https://www.reddit.com/r/flyfishing/comments/1hpvj81/documenting_locations/), where the poster struggles to remember explored water, access, and fishing quality.
- [Do you keep a journal?](https://www.reddit.com/r/flyfishing/comments/1en87q1/do_you_keep_a_journal/), where anglers describe short voice notes, photos, prose, and the downside of journaling becoming a chore.
- [Do you have a fishing journal? If so, how do you record and use the data?](https://www.reddit.com/r/flyfishing/comments/1kg45id/do_you_have_a_fishing_journal_if_so_how_do_you/), which connects personal observations with flows, seasons, equipment, and future trip planning.
- [Voice logging on Android](https://www.reddit.com/r/Fishing/comments/1sw65rz/anyone_have_a_workflow_for_logging_catches_via/), where the poster describes failing to reliably turn spoken fishing details into spreadsheet fields.

My synthesis was that reliable capture is a bottleneck for anglers who already want a record, but it is not the only bottleneck. Some people successfully record information and never use it again; others do not want to journal at all. That pushed me toward a narrower user: an angler who values a personal journal but abandons detailed logging because it interrupts the trip or creates a backlog.

## What did I build?

I built **Creel**, a two-stage private fishing journal.

The first stage is a native iPhone app for low-friction field capture. A user starts a trip and records partial events through voice, text, or photos. Entries can be incomplete, added to later, or corrected. The app works offline and exports a versioned `.fishing-trip.zip` containing the structured trip record and original media.

The second stage is a local desktop journal. It imports the trip package, preserves the phone originals, transcribes audio with a local Whisper model, and uses a local language model to suggest structured facts such as species, fly, or reported place. Suggestions remain proposals until the user accepts or corrects them. The user can also add desktop notes, search the journal, and create a backup.

The working solution is available publicly, with the real processing applications running locally:

- Reviewer walkthrough: [https://tweisslehman14.github.io/creel-ai-case-study/](https://tweisslehman14.github.io/creel-ai-case-study/)
- Public source: [https://github.com/tweisslehman14/creel-ai-case-study](https://github.com/tweisslehman14/creel-ai-case-study)
- Downloadable package: [Creel case-study demo v1.0.0](https://github.com/tweisslehman14/creel-ai-case-study/releases/tag/v1.0.0)
- iPhone app: [Xcode project and run instructions](creel-ios/README.md)
- Desktop app: [desktop instructions](creel-desktop/README.md)
- Original visual prototype: [Creel — Phone Capture MVP.html](Creel%20-%20Phone%20Capture%20MVP.html)

The phone and desktop experiences are working in the iOS Simulator and local browser. Eight phone-core tests and 38 desktop tests pass, including reruns from the clean downloadable archive. I also verified a synthetic audio round trip through the actual phone exporter, desktop import, local transcription, local extraction, search, backup, and restore. Real field audio and physical-device behavior still need validation.

## How did I use AI?

I used AI as a research partner, product critic, designer, implementation team, and test partner.

First, I asked it to search broadly across youth sports, fishing, and aquariums for genuine complaints. After choosing fishing notes, I asked it to find related Reddit discussions and compile every way people said they used their records, including one-offs and conflicting behavior. I then asked whether my hypothesis—that structured capture was the bottleneck—actually followed from the evidence. AI agreed only conditionally and pointed out that retrieval value and willingness to journal were separate problems. That distinction materially changed the product framing.

I proposed a voice- and camera-led app that could eventually add GPS, weather, maps, and stream-gauge context. I asked AI to attack the idea. It identified field-use problems such as wet hands, glare, wind, battery use, delayed entries, ambiguous notes, missing versus zero values, nearby gauges that may not represent the fishing location, privacy, and the danger of turning selected catches into misleading analysis. I accepted some feedback, pushed back or clarified other parts, and required preservation of the raw recording alongside every interpretation.

I then reduced the MVP to two stages: reliable offline capture on the phone, followed by processing and review on a computer. AI converted that decision into requirements and a development plan. I supplied an HTML phone design, and AI used it as the visual reference for a native SwiftUI implementation. I also asked AI to adopt a product-manager, senior-developer, and junior-developer structure from another project. Those roles reviewed scope, data integrity, recovery behavior, implementation, and acceptance criteria in parallel.

For the desktop app, AI designed and implemented the package importer, immutable source storage, review layer, search, local-model adapters, and backup/restore flow. I kept the core experience usable without AI configured and chose local Whisper and Ollama processing to avoid sending private fishing locations, voices, or photos to a cloud provider.

## What did I prompt, iterate on, and change direction about?

The major prompt sequence was:

1. Search broadly for complaints in youth sports, fishing, and aquariums.
2. Investigate similar fishing-note threads and related problems.
3. Compile all downstream uses of fishing records without prematurely ranking them.
4. Test my structured-capture hypothesis against the evidence and inventory what people record.
5. Critique my proposed voice/camera/GPS/weather/gauge solution.
6. Turn my responses into a reasonable MVP journey.
7. Split the system into phone capture and desktop processing to reduce field complexity.
8. Write requirements, review the HTML design, implement both parts, and validate them.

Several iterations mattered more than the initial generation:

- **I narrowed the problem.** The first concept included maps, OSM river data, USGS gauges, weather, GPS, capture, and processing. The Reddit evidence supported those as useful context, but reliable offline capture was the most direct pain point. I deferred enrichment.
- **I preserved evidence instead of trusting extraction.** Every transcript and structured fact sits beside the original audio, photo, or text. Human corrections are stored separately rather than overwriting the source.
- **I rejected the first extraction result.** The local model produced plausible facts but supplied inaccurate character offsets for its supporting quotes. All six proposals were rejected. The implementation now accepts only an exact source quote and resolves a unique span locally; ambiguous repeated quotes require explicit valid offsets.
- **I corrected a semantic error.** An intermediate prompt classified “main run” as the name of a waterbody. I changed the prompt to distinguish a named river or lake from a place within it. The next run treated it as a user-reported place.
- **I separated creation from transfer.** The phone initially reported a successful export when the package existed inside its app container. Testing reinforced that package creation is not proof that the file reached the desktop. The record stays on the phone, and transfer is a separate user action.
- **I kept incomplete and unsuccessful trips valid.** The system does not manufacture measurements, infer zero catches from an empty log, or require every event to fit a complete schema.

## What surprised me?

The biggest surprise was how quickly “simple voice logging” became a provenance problem. Transcription was only the first uncertain step. The model then had to distinguish a river from a run, a catch from a general trip story, unknown from zero, and direct observation from inherited context. A fluent structured response could still be wrong in ways that would corrupt later analysis.

That changed my definition of the product. The valuable part is not automatic structure by itself. It is a trustworthy path from a quick field observation to a reviewable record: preserve the source, show what the model inferred, link each suggestion to evidence, and let the user correct it.

I was also surprised by how often the best product decision was to remove intelligence from the field experience. Keeping capture durable and simple on the phone, then doing optional processing at a computer, reduced interaction cost, offline risk, privacy exposure, and implementation complexity at the same time.

## How would I pull in data programmatically over time?

The MVP uses an explicit, versioned trip package rather than a live backend. Each trip, event, attachment, and revision has a stable identifier. The desktop importer verifies file hashes, treats identical reimports as no-ops, accepts a newer source revision without erasing desktop review, and rejects older or conflicting source data. That is the foundation I would retain if transfer later became automatic.

The next step would be an opt-in sync or watched import folder that moves new trip revisions to the desktop and runs idempotent processing jobs. Raw sources and processing versions would remain immutable so a changed transcript or model output could be traced and reprocessed safely.

For external context, I would add separate source-aware jobs:

- Match an event’s time and coordinates to a Montana waterbody using appropriate OSM-derived data or a licensed map provider.
- Query the USGS Water Data APIs for the selected monitoring location and event time, storing station ID, parameter, units, observation time, distance, and matching method—not just a flow number.
- Query a historical weather provider for the event time and area while retaining the provider, timestamp, and resolution.

These jobs should run after capture, retry independently, cache the raw response, and make missing or stale data visible. User-reported weather and water conditions should remain distinct and take precedence in the journal presentation. A nearby gauge should never be presented as an exact on-site measurement, and location should not be included in a language-model request unless the task truly requires it.

## What would I do with more resources or tools?

I would spend the next effort on evidence and field reliability rather than adding a dashboard:

- Interview several anglers from the target segment and observe how they currently capture and retrieve information.
- Test on physical phones in wind, water, glare, gloves, poor connectivity, low battery, and interrupted recording conditions.
- Build a small evaluation set from consented real fishing recordings, including corrections, and measure transcription errors, extraction errors, and review burden.
- Test whether users can answer the two intended retrieval questions: “What happened last time I fished this water?” and “What do I remember about this place?”
- Validate Montana waterbody-to-gauge matching with hydrology or local-domain expertise before using it for comparisons.
- Package the desktop service as a straightforward installable application and add an opt-in transfer mechanism.
- Run a privacy and security review before adding accounts, cloud sync, or any external model provider.

The most important open product question is whether the later retrieval value is high enough to sustain the capture habit. The prototype demonstrates a credible workflow; it does not yet prove long-term engagement or better fishing outcomes.

## Five-minute Loom narrative

**0:00–0:40 — Start with the user problem.** Show the original “Taking notes when fishing” thread and the related location/voice threads. Explain that anglers want memories and reusable context, but detailed logging becomes work. State the chosen user and the narrower hypothesis.

**0:40–1:25 — Show how AI changed the framing.** Briefly show the broad research, inclusive use-case inventory, and critique of the initial all-in-one concept. Explain that I separated capture from retrieval and cut maps, gauges, and weather from the MVP.

**1:25–2:25 — Show the product evolution.** Show the HTML concept, then the native phone flow: start a trip, add a short event, and export it. Explain why partial entries, original media, offline storage, and later editing mattered more than a large form.

**2:25–3:35 — Demo the desktop and a real AI iteration.** Import the package, open the original entry, run local processing, and show a suggestion linked to its exact source. Explain that the first model output had invalid quote offsets and that “main run” was initially misclassified; show why proposals require review.

**3:35–4:15 — Explain ongoing data.** Describe stable IDs and revisions, idempotent imports, and future independent OSM/USGS/weather enrichment with provider, time, units, distance, and provenance. Clearly label these integrations as proposed.

**4:15–5:00 — Reflect.** Explain that AI accelerated research, critique, implementation, and testing, while my judgment set the user, scope, privacy model, trust requirements, and rejection criteria. Close with physical field testing and retrieval value as the next questions.
