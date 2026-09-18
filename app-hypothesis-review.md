# Review of Tom's initial app hypothesis

September 17, 2026. Review only; no implementation authorized or selected in this step.

## Hypothesis supplied by Tom

An app with a simple, primarily voice/camera driven interface supports field capture through trip creation/general context and event capture (fish, wildlife, etc.). GPS, maps, USGS gauges and weather automate basic context. Quick notes/photos are saved offline or processed by an LLM into structured records for later evaluation. Intended benefit: fast field capture with well-structured, analysis-ready information.

## Assessment

Plausible and supported by the capture-friction evidence. Strong elements: trip/event separation, multiple event types, automatic context, and deferred offline processing. The biggest unproven claims are that the actual field interaction is easy and that sparse, selected observations become analysis-ready. Structure alone does not provide completeness, correctness, or comparability.

## Gaps and questions

1. **Field usability.** Unlocking, launching, wet hands, glare, rushing water/wind, battery, photo/voice association and attention while handling a fish need testing. Preserve after-trip and text entry. Voice is one input mode, not a validated universal preference.
2. **Ambiguous notes.** “Nice rainbow in the main run on an elk hair caddis” supplies user-reported species and pattern. It does not supply fish length, fly size, exact named reach, fishing duration or trustworthy hydrologic context. Do not fill these from plausibility. Distinguish capture time from event time when notes are delayed.
3. **Source and uncertainty.** Keep original audio/photo/text; distinguish user-stated values, inferred classifications, phone observations and external measurements. Missing is different from zero; approximate counts differ from exact counts. Suggest corrections after the trip without blocking capture.
4. **Trip state.** Include end-trip and correction when start/end is forgotten. Stops, location changes, rig changes, retrospective summaries, wildlife, photos of the same fish and explicit zero-catch results need handling. Context changes over time; a trip-wide default cannot silently override event detail.
5. **External context matching.** Nearby water is not necessarily the intended reach. Nearest gauge is not necessarily representative: river connectivity, tributaries, dams and timing matter. Preserve station, parameter, units, measurement time and source flags. External weather and water observations are context, not proof of exact on-site conditions. No gauge/no parameter/no permission must be valid states.
6. **Offline reliability.** Save raw media and metadata durably first; display saved/pending/processed/review-needed states. Processing and sync should survive closure/retry without duplicates. Backfill conditions for event time, not reconnect time. Recording audio offline differs from transcribing offline.
7. **Analysis limits.** Catch-only logging misses unsuccessful effort and changes in tactics. Duration, explicit no-catch results and meaningful method changes are needed for some comparisons. Selected photos cannot establish catch rates or causal fly effectiveness. Name one downstream retrieval task to test, rather than promising all analyses.
8. **Privacy and ownership.** Private spots and voices/photos sent for processing require understandable controls. Private-by-default records, selective sharing and export/backup deserve consideration given thread evidence.
9. **Coverage and build scope.** USGS narrows the initial geography to the US, and gauge coverage varies. River enrichment does not cover every fishing style. An hour-long prototype should demonstrate capture, extraction review, and one retrieval loop on a small scope; a polished native offline app with all integrations is much larger.

## Technical checks

- [USGS Water Data APIs](https://api.waterdata.usgs.gov/): observations are parameter-specific time series associated with monitoring locations; metadata includes units and observation dates. Proposed station matching and actual regional coverage have not been implemented or tested.
- [OSMF tile policy](https://operations.osmfoundation.org/policies/tiles/): public standard raster tiles prohibit offline downloading. OSM data can still underlie an offline solution using an appropriate provider or self-hosted tiles. A map display is not the same thing as queryable river geometry.
- [Apple speech recognition](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition): offline transcription support must be checked; Apple's cited recognizer requires network when on-device recognition is unsupported. This does not prevent offline raw-audio capture.
- Weather provider, pricing, historical resolution and coverage remain unselected/unverified.

## Suggested first validation, not a selected implementation plan

Test a short trip with a catch, a rig change, a zero-catch period, wildlife, and a delayed note. Verify fast durable capture, correct event association, explicit unknowns, retry without duplicates, and one later question answered from the saved evidence. Compare field voice capture with a short debrief at the car. Measure interaction time, correction burden, lost/duplicate records and retrieval success.

The defensible near-term promise is: preserve quick observations with source-linked structured context that can be reviewed and used later. Reliable capture and useful retrieval must be demonstrated separately.
