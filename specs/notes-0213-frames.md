# Task: add Frames to the v0.2.13 notes

The v0.2.13 notes are already on staging (CHANGELOG.md, docs/RELEASE_NOTES.md, KstyleUI_Options/Notes.lua, from #715). #717 (merged) brought the Frames HUD style back next to Medallions, with the class crowns, Spirit Poles row, Ghost Wolf and Lightning Shield storm orbs in Frames' resource row. Add it as the lead item: a highlight (120 characters or fewer), an `Added:` line in the CHANGELOG and RELEASE_NOTES, and an Upgrading note: players moved to Medallions by v0.2.12 pick Frames again under setup or Options (give the exact Options path from the code); profiles from before v0.2.12 that chose Frames stay on Frames. Update the Notes.lua v0.2.13 entry with translations (`strings.py sync`, `crlf.py`). Checks: lint, python, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed under 6000. PR `docs(release): Frames in the v0.2.13 notes`, label `no changelog`. Do not merge.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR, SHA, run id.
