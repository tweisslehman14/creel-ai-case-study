# Creel — working agreement

## Product and architecture

The single active plan is `requirements-and-development-plan.md`. The supplied `Creel - Phone Capture MVP.html` is the visual/interaction reference; retain it unchanged. `design-review.md` records implementation decisions. Phone code lives in `creel-ios/`; desktop code lives in `creel-desktop/` with its own README and validation record.

Native SwiftUI capture is entirely local. No phone AI calls, telemetry, accounts, maps, weather or background tracking. Preserve originals and source history. Partial/unclassified entries are valid. Capture time/location and retrospective occurrence time/location are distinct. A successful export means a local package exists, never proof it arrived elsewhere.

## Agent responsibilities

Adapted from `~/flyfishing/CLAUDE.md`, its productmanager guide and global PM/senior/junior charters. Role boundaries apply across tooling; Claude-specific model names are not requirements for Codex.

- Main session: coordinate bounded tasks, assign non-overlapping files, integrate, run final build/simulator checks, and report evidence and remaining limitations. Do not ask workers to orchestrate.
- Product manager: review user journeys/design, maintain the active plan and acceptance/status records. Read code as evidence; do not change implementation in this role. See `agents/product-manager.md`.
- Senior developer: own architecture, recording lifecycle, storage, package contract, recovery and cross-cutting correctness. See `agents/senior-developer.md`.
- Junior developer: execute explicit, bounded tasks with a known pattern, such as project scaffolding, UI components or specified tests. Escalate contract/architecture ambiguity. See `agents/jr-developer.md`.

The coordinator delegates only independent work with clear inputs, owned files and a definition of done. Workers report actual checks, changed files and residual risks; no worker spawns additional agents or commits unless explicitly tasked. Use the user's configured model unless explicitly instructed otherwise.

## Verification and status

Update the plan at phase start and after verified completion. Separate simulator evidence from physical-device evidence. Build/test instructions live in `creel-ios/README.md` and `creel-desktop/README.md`. Desktop uses a Python standard-library loopback service, SQLite, immutable original files and static browser UI. Never bind it publicly or add cloud requests silently. Keep desktop corrections separate from phone sources and AI proposals. Do not advance a dependent acceptance gate while required checks fail. Never claim five-minute audio, low-storage recovery, physical camera or offline field reliability based only on compilation.

No secrets or live fishing data in fixtures. Use temporary test libraries; do not overwrite user trips. Keep generated build products outside source. Preserve unrelated workspace work and the original HTML design.
