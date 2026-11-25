# Task: release notes for hotfix v0.3.4.5

Write the notes PR for v0.3.4.5 from `staging`, covering `git log v0.3.4.4..origin/staging`: #799 (the crest no longer throws "forbidden object" Lua errors in combat, e.g. a rogue using Vanish or Stealth mid-fight, or the shaman storm clouds; every crest piece keeps lighting, filling and counting through the fight; a first form or stance switch in combat shows its pieces at once; medals snap back to whole pixels after a UI scale change). Docs-only PRs skip. This one came from the owner's own BugGrabber, so no player credit.

Use the PR's `## Changelog`, verify against the code on staging. Owner's voice (`C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`), no AI tells, no em dashes. Branded style of the v0.3.4.4 section in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, highlights of 120 characters or fewer, Notes.lua entry with translations (`strings.py sync`, `crlf.py`). Checks: lint, python, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed under 6000. PR `docs(release): v0.3.4.5 notes`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
