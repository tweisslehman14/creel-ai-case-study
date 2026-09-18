# Fishing capture hypothesis and information inventory

September 17, 2026. Based on the seven threads in fishing-notes-research.md and the source review behind fishing-record-use-cases.md. User hypothesis: reliable, structured capture is a bottleneck across many uses. No solution or schema selected.

## Assessment

Supported as a hypothesis for anglers who want records but struggle to maintain or use them. Evidence includes abandoned forms/spreadsheets, forgotten details after delayed entry, unstructured notes that cannot be cross-referenced, and unreliable voice-to-spreadsheet entry. It does not establish capture as the sole or dominant bottleneck for anglers generally. Some users have successful capture but cannot sort/retrieve useful information; others value narratives or do not want to log at all.

Working formulation: capture personally meaningful observations with little effort and preserve enough context and structure to retrieve and compare them later. Structure in the saved record need not require structured input from the angler. This last point is a design inference, not a validated solution.

## Information users discuss recording

These fields span current records, desired records, and suggestions. They are an inventory, not mandatory form fields. A field's presence does not mean every user wants it.

| Group | Information |
|---|---|
| Trip identity and time | Date, time of day, start/end times, trip duration, season/year, cumulative days fishing, days using a raft |
| Place | Waterbody name, river section, named run/hole, nearest town, region, coordinates, map pins, landmarks, directions, access points, put-in/take-out, walked or paddled tracks |
| Place assessment | Good/poor/unexplored status, fish quality, productive pools, resident-fish locations, difficult banks, silty bottom, wading difficulty, places with no catches, future waters to explore |
| Water | Flow/discharge/CFS, gauge station, water level, local high/low interpretation, local units such as boards, temperature, clarity, depth, current/tide context, visible rocks/holes, cover/structure; photos and gauge screenshots |
| Weather | Air temperature, sun/cloud/light, wind speed/direction, pressure, approaching/past fronts, preceding days' weather, broader winter conditions, moon phase; some moon/pressure tracking is proposed |
| Seasonal and ecological observations | Hatches, insect types/sizes, bugs under rocks, fish activity/holding locations, rises, ice-out/on, runoff, spawning beds, earliest/latest seasonal catches, birds/wildlife, unusual observations and longer-term changes |
| Equipment and method | Rod/weight, gear brought, fly/lure/bait name or pattern, color, size, fly combinations, rig, leader setup, indicator depth, fishing method, presentation; retrieve speed/pauses/angle are discussed as possible explanatory details |
| Catch and outcome | Species, count, length, weight, catch time/place, fly/lure used, bites, follows/raised fish, refusals, missed/lost fish, landed fish, zero-catch trips, general success, trophies, harvested pond-fish measurements, what worked/did not |
| Personal experience | Companions, interactions, funny/unusual events, wildlife encounters, narrative of the day, impressions, lessons and reminders, memories, photos/video/audio |
| Logistics | Drive time, campsites, food stops, fly shops, access routes, missing equipment/wish-I-had items, return/check-in plans |
| Standing references | Leader formulas, fly recipes and tying videos, purchased-fly photos/names/store, unit conversions, researched trout sections and seasons, species bucket lists, annual goals |
| Provenance and reconstruction | Personal versus other anglers' flow observations, gauge identity, dated/location-tagged photos, screenshots, map layers and annotations, recordings used to reconstruct events |
| One-off humorous entry | Consumption of “fish whistles” to bring more next time; joking rather than validated functional demand |

## Source map

- [Taking notes when fishing](https://www.reddit.com/r/flyfishing/comments/19cjde8/taking_notes_when_fishing/): trip/catch fields, video narration, rig detail, flow interpretation, separating observations, unsuccessful trips, photos, check-in context.
- [Documenting locations](https://www.reddit.com/r/flyfishing/comments/1hpvj81/documenting_locations/): access, place assessment, routes, future locations, spawning beds, purchased-fly reference, travel details and memories.
- [Do you keep a journal?](https://www.reddit.com/r/flyfishing/comments/1en87q1/do_you_keep_a_journal/): weather/ecology, formulas/conversions, seasonal comparisons, navigation, goals and narratives.
- [How do you record and use the data?](https://www.reddit.com/r/flyfishing/comments/1kg45id/do_you_have_a_fishing_journal_if_so_how_do_you/): station-specific flows, raft trips, navigation observations, catches, rigs, rod choice and retrieval problems.
- [Voice logging on Android](https://www.reddit.com/r/Fishing/comments/1sw65rz/anyone_have_a_workflow_for_logging_catches_via/): date, lake, species, technique, lure, length and weight; unreliable spoken entry.
- [Abandoned logging systems](https://www.reddit.com/r/FishingForBeginners/comments/1srt8fc/how_do_you_actually_keep_a_fishing_log_every_app/): capture effort, missing context, cross-referencing, photo metadata, tide/structure discussion, pond harvest records.
- [Who keeps a log?](https://www.reddit.com/r/flyfishing/comments/1c5we7z/who_keeps_a_fishing_log/): activity totals, goals, trip template, gear wishes, narrative and catch outcomes.

## Design implications to test, not requirements selected

- Preserve multiple levels: trip, stop/river section, method change, and catch/observation. Users also maintain place and reference records independent of trips.
- Preserve relationships: which outcome occurred with which rig at which place/time. A bag of extracted keywords will not support comparison.
- Distinguish unknown from zero, estimated from measured, user-observed from externally sourced, and current from historical.
- Keep source notes/photos alongside extracted fields so interpretations can be checked and corrected.
- Potential automatic enrichment: timestamps, supplied photo coordinates, historical weather, gauge readings. Availability, permissions, station matching and coverage remain unverified. A nearby gauge does not establish the exact conditions at the fishing spot.
- No capture format is selected. Voice, prose, photos and structured input all appear in the discussions.
