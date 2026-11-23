# Task: release notes for v0.2.15

Write the notes PR for v0.2.15 from `staging`, covering `git log v0.2.14..origin/staging`: #736 group frames round 8 (Name under the bar for party and raid rows in both styles; Anchor: party heal icon place, above side-by-side frames; Sort by FrameSort on party and raid when the FrameSort addon is loaded, out of combat, falling back to group order) plus docs (#735; skip). Use the PR's `## Changelog`; verify against the code; give Options paths. Owner's voice (`C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`), no AI tells, no em dashes. Branded style of the v0.2.14 section in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, highlights of 120 characters or fewer, Notes.lua entry with translations (`strings.py sync`, `crlf.py`). Checks: lint, python, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed under 6000. PR `docs(release): v0.2.15 notes`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
