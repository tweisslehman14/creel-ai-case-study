# Process and evidence log

Record work as it happens. Empty sections are prompts for later documentation, not completed work.

## Discovery and selection

September 17, 2026, requirements: Tom split the product into offline phone capture and desktop processing/review/recall. At his request, created requirements-and-development-plan.md with a versioned export contract, phased implementation gates, privacy constraints and acceptance scenarios. External enrichment is proposed as a follow-on phase; technical defaults remain subject to device/provider verification. No implementation started.

September 17, 2026, focused follow-up: Tom chose fishing notes for deeper discovery. [Focused research](fishing-notes-research.md) compares seven core threads and separates capture effort, retrieval, river-condition context, and memory keeping. Full original thread access now succeeded. No solution selected or implemented.

September 17, 2026: Tom requested a broad search across youth sports, fishing, and aquariums before narrowing. AI searched Reddit and compared firsthand complaints, workarounds, and possible small solution scopes. [Discovery notes](reddit-discovery.md) retain seven candidates, source-access limitations, and open questions. No selection yet. One useful finding: several results were developer-led app research rather than clear firsthand complaints, so those received less weight.

- Reddit thread URL(s):
- Thread title, subreddit, and date inspected:
- Specific complaint / brief supporting excerpt:
- Who experiences the problem and in what situation:
- Current workaround and why it falls short:
- Our interpretation, separate from direct evidence:
- Why Tom wants to solve this:
- Chosen workflow and success criterion:
- Scope deliberately left out:

## AI iterations

### Iteration — September 17, 2026 / HTML to native phone implementation

- User direction: “I saved a phone capture mvp design file as HTML to this folder. Review the design, incorporate it into the development plan, and implement the app, ready to run via the xCode simulator.”
- Input: Creel phone capture HTML and the existing two-stage requirements.
- Decision: native SwiftUI phone implementation for this increment; desktop processing remains later work. Adopt the phone design, not its surrounding presentation canvas.
- AI review: separated genuine requirements from mock behavior, including sample GPS/waterbody data, simulated save/export, and unsupported transcript writeback. Kept raw capture, partial entries and manual transfer central.
- Artifacts: design-review.md and requirements-and-development-plan.md v0.2. Native implementation underway in creel-ios/.
- Verification: pending at this documentation update; no simulator or physical-device completion claim.

### Iteration — September 17, 2026 / Roles and bounded parallel work

- User direction: “Review the agent structure (product manager, sr. developer and jr. developer) used in the ~/flyfishing/ project and utlize a similar set up here to make the implementation more efficient.”
- Adaptation: product manager handles requirements/design/acceptance documentation; senior developer handles architecture/integration; junior developer handles bounded implementation. File ownership is explicit to avoid conflicting edits.
- Source reviewed for PM role: ~/.claude/agents/product-manager.md and ~/flyfishing/productmanager/CLAUDE.md.
- Decision: retain this case study's existing plan as its single status record, using Started/Completed dates and evidence-based gates. Do not transplant FlyCaster's app stack or change that project.
- Benefit to evaluate: whether parallel documentation/review and implementation reduce rework. No efficiency measurement has yet been made.


For each meaningful iteration, append:

### Iteration [number] — [time / purpose]

- Tool used:
- Exact prompt or saved transcript reference:
- Output / prototype version:
- What Tom observed:
- Decision: accepted, revised, rejected, or deferred — and why:
- Screenshot or artifact showing the change, if useful:

## Validation

| Scenario / input | Expected behavior | Observed behavior | Result / follow-up |
|---|---|---|---|

## Ongoing data plan

- Data needed and authoritative source:
- Prototype's actual data source:
- Proposed access method and any access requirements to verify:
- Refresh cadence and why:
- Record identifiers, normalization, and duplicate handling:
- Validation, provenance, stale data, and failed refresh behavior:
- What is implemented versus proposed:

## Reflection and delivery

- Most useful AI contribution:
- Where AI was wrong or needed direction, if any:
- What surprised us, if anything:
- Known limitations:
- What more time, tools, or resources would enable:
- Final solution URL / HTML file:
- Loom URL:

### Native phone implementation and review — September 17, 2026

- Implemented SwiftUI trip capture with original audio/photo/text, optional labels, later amendments, source history and ZIP transfer. No external AI/backend used by the phone.
- Tom requested the FlyCaster agent setup during implementation. Read its actual PM/senior/junior charters; used separate agents for product review, integrity/recovery review, and Xcode scaffolding/core tests. The main session handled UI implementation and integration. Saved equivalent local guidance in CLAUDE.md and agents/.
- Reviews caught and corrected snake-case ID decoding, optimistic interruption wording, memory-heavy export, historical photo timing, unsaved dismissal, direct end/outcome editing, and debrief classification. These are actual iterations, not hypothetical prompts.
- Eight core tests passed and native app built, installed and launched on iPhone 17 Pro/iOS 26.5. Interactive simulator work was blocked by locked Mac; user notified. No device reliability claim or final Loom recorded. See creel-ios/VALIDATION.md.
- Original HTML retained unchanged. Reviewed decoded source; browser blocked its local-file preview, with no bypass attempted. Native fonts approximate the web design.


### Iteration — September 17, 2026 / Desktop implementation starts

- User authorization: proceed with the desktop application consuming exported phone trips.
- Architecture: local Python standard-library loopback service, SQLite, original files and a Creel-styled static web interface. No accounts or remote hosting required.
- Agent split: coordinating developer owns server/UI; senior developer owns import/storage integrity; junior developer owns processing adapters; product manager owns journey and acceptance documentation.
- Product decision: import, reading, corrections, search and backup work without AI. Processing configuration is separate from authorization to transmit data or spend money; local versus external model choice remains open.
- Contract review: current phone package has snake_case keys, `kind` enum values, nested event attachments, omitted optional values, source correction histories and deletion markers. Validate semantics as well as checksums.
- Evidence at this entry: source/schema review only. Desktop runtime and adapter acceptance are pending; see creel-desktop/ACCEPTANCE.md.


### Desktop implementation and synthetic validation — September 17, 2026

- Implemented the local desktop service and Creel web interface. Phone source was unchanged during this increment.
- Used the actual Swift `Models.swift` exporter, compiled locally, to generate three synthetic trip packages; avoided describing hand-authored JSON as a real physical-phone transfer.
- Browser evidence: inspected empty layout; previewed/imported a synthetic package; saved an additional desktop note while retaining source text; kept/corrected a species proposal; searched “shaded bank”; created a downloadable backup.
- Local model iteration: llama3.1:8b with prompt v2 returned five supported proposals (rainbow trout, size 16, elk hair caddis, main run, wind). The implementation matches a unique exact quote deterministically. Human review remains necessary because a matching quote does not prove the interpretation.
- Local speech adapter evidence: installed whisper.cpp/base.en transcribed synthetic speech as “caught a rainbow trout on an elk hair caddis.” Full imported-audio HTTP smoke testing remains underway at this entry.
- Initial desktop tests: 28 passed; further regression coverage added, final count pending coordinator verification. Backup/restore core tests pass. UI review identified blank transcript overrides, polling/playback interference and unsaved-review risks for correction and verification.
- Privacy: local-only models; no paid or cloud requests. The user has not selected a cloud provider.
- Limits: synthetic data and speech do not validate field audio or the user's physical phone transfer. Final test/HTTP results will be recorded in creel-desktop/ACCEPTANCE.md.

### Desktop completion evidence — September 17, 2026

38 final regression tests passed. The real Swift exporter generated synthetic packages; browser import/review/acceptance/search/backup checks passed. A synthetic audio M4A package passed HTTP import, local Whisper transcription, local Llama extraction, duplicate-job reuse and backup restore; restored search retained the voice-only entry. Installed local Whisper and English model for actual audio processing, with no paid or cloud inference. Final app serves a clean library at localhost:8767. The browser file-picker tool had a prolonged (~38-minute reported wall-time) wait during validation; no one-hour total-time claim is made. Original phone source/build remains unchanged. See creel-desktop/VALIDATION.md.

### User walkthrough — September 18, 2026

- Tom reported that both the simulator app and desktop experience were working after his hands-on test.
- He created a trip and generated an export in the iOS Simulator. The export was present in the app's Application Support `Creel/exports` directory; troubleshooting corrected an initially incomplete retrieval path and made the `.fishing-trip.zip` accessible in Finder.
- This is user-reported simulator validation. It does not replace the remaining physical-device and field-audio acceptance work.

### Public reviewer package — September 18, 2026

- Published the source and evaluator-facing README at https://github.com/tweisslehman14/creel-ai-case-study.
- Published a responsive, interactive, synthetic walkthrough at https://tweisslehman14.github.io/creel-ai-case-study/. It explicitly does not claim to run the native capture, Python service, or local AI models in the browser.
- Published a curated `creel-demo-v1.0.0.zip` through GitHub Releases. It contains the phone app, desktop app, synthetic samples, and quick-start documentation; local models and personal journal data are excluded.
- Verified the release from a clean extraction: 8 Swift core tests and 38 desktop tests passed. Release SHA-256: `d63328a60ee1bbc6b7bf7acec9750b0c9ac44aa6a7cdb3f4babd7b54cefcf71e`.
