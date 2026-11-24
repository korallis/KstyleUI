# Task: release notes for hotfix v0.3.4.2

Write the notes PR for v0.3.4.2 from `staging`, covering `git log v0.3.4.1..origin/staging`: #789 (the world map's terrain art no longer goes missing after switching zone, closing and reopening the map; the map now opens without its fade), #791 (`/kstyle setup` no longer shows a Lua error when you leave the first page), #792 (setup's Modules, Your addons and Welcome lists draw every row straight away instead of needing a scroll). Docs-only PRs skip.

**Credit (owner's instruction)**: Baine reported and tested all three; credit him by name ("Thanks to Baine for finding and testing these."). Same credit in `docs/RELEASE_NOTES.md` and the Notes.lua entry (translated).

Use each PR's `## Changelog`, verify against the code on staging. Owner's voice (`C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`), no AI tells, no em dashes. Branded style of the v0.3.4.1 section in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, highlights of 120 characters or fewer, Notes.lua entry with translations (`strings.py sync`, `crlf.py`). Checks: lint, python, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed under 6000. PR `docs(release): v0.3.4.2 notes`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
