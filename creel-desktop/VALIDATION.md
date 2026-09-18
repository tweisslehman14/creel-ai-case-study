# Desktop validation — September 17, 2026

## Verified delivery

The desktop journal runs at `http://127.0.0.1:8767` with a clean local library. `Start Creel.command` starts the service and configures the local models verified on this Mac. Processing still requires an explicit action on an entry; no automatic inference or cloud upload occurs.

The iOS application source/build was not modified during desktop work.

## Automated checks

Final command, from this directory:

```sh
python3 -m unittest discover -s tests -v
```

**38 tests passed, zero failures** (36.692 seconds in this run). Coverage includes:

- Manifest/file/hash/ID validation; unsafe paths, active media types, duplicate entries, missing files and unsupported formats rejected.
- Reimport no-op despite new package ID; newer/older/conflicting revision handling; immutable originals and prior source versions.
- Separate human corrections, optimistic review revision checking, source deletion conflicts and stale derivations.
- Effective narrative/transcript/fact search; discarded or stale AI-only values excluded.
- Human-reviewed context inheritance with exact chronology and suppression of unknown, overlapping or conflicting timing.
- Consistent archive/restore containing original packages, media, source/review/processing histories; nonempty library restore rejected.
- Exact quote/span validation, deterministic proposal IDs, malformed outputs, raw/corrected transcripts, opt-in local inference and minimal payloads.
- Loopback HTTP import, range reads, backup download, security headers, cross-origin and invalid-token write rejection.

JavaScript syntax and Python compilation checks also passed.

## Actual cross-platform and model checks

Compiled the unchanged iOS `Models.swift` with a small Mac fixture program and used its real `Repository.export` implementation to generate four clearly marked synthetic packages in `samples/`. These were not handwritten approximations of the phone ZIP schema.

- Browser import preview and commit succeeded for the Madison sample.
- The original phone note remained visible after saving a separate desktop note.
- Actual local Ollama `llama3.1:8b`, prompt `creel-extract-2`, produced source-linked proposals for rainbow trout, size 16, elk hair caddis, main run and wind; no fish measurement was supplied. Browser acceptance saved the species as a human correction.
- Browser search for a phrase in the desktop note returned the matching trip.
- Browser backup action produced a downloadable archive.
- Local whisper.cpp 1.9.4 with `base.en` transcribed computer-generated speech as “caught a rainbow trout on an elk hair caddis.”
- The synthetic audio was encoded as M4A, packaged with the real Swift exporter, imported through HTTP, transcribed through the app's job API, then extracted into species and fly proposals. Original media remained unchanged. Repeating unchanged extraction returned `unchanged`.
- Downloaded the resulting desktop backup and restored it into an isolated empty library: four trips, seven events, one audio original and the desktop review returned. Search for rainbow returned two trips, including the voice-only entry.
- The final user-facing service was opened and showed zero trips, ready for the user's own phone exports. Synthetic QA records remain in `/tmp/creel-desktop-qa`, separate from `data/`.

## Actual iteration, not simulated success

The initial local extraction pass proposed facts with inaccurate character offsets; all were rejected. The implementation now accepts only an exact matching source quote and determines its unique span locally. Repeated ambiguous quotes require valid explicit offsets. No fuzzy citation repair is performed.

One intermediate model pass classified “main run” as a waterbody. Prompt version 2 distinguishes a named river/lake from a place within it; the next browser run labeled it as reported place. This illustrates why suggestions remain proposals. Exact source matching is evidence linkage, not proof of semantic correctness or a calibrated confidence score.

Review also corrected empty manual overrides hiding future transcripts, refreshes interrupting active audio, time reset pinning old phone values, and stale-search/cache behavior.

## Remaining limits

- Tested media and notes were synthetic. Wind/noise, accents, long multi-part field audio, camera formats and the user's own physical-phone transfer still need acceptance testing.
- English transcription model. Local model quality is not comprehensively evaluated; edits/review remain necessary.
- Backup currently caps **total expanded archive content at 250 MB**, including original ZIP packages and media copies. This is smaller than a 250 MB trip plus all derived/history material. Large-library backup/restore needs a larger streaming design before field-scale use.
- Restore targets an empty library only. It does not merge arbitrary desktop libraries or overwrite an existing one.
- No reverse sync to phone, cloud provider, account, shared journal, maps, historical weather or gauge enrichment.
- Search is direct local filtering, adequate for the MVP but not benchmarked on a large journal.
