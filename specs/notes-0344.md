# Task: release notes for hotfix v0.3.4.4

Write the notes PR for v0.3.4.4 from `staging`, covering `git log v0.3.4.3..origin/staging`: #798 (on the Medallions HUD, aura timers and stack counts on your player, target and focus frames, and in the Options preview, sit clear of the portrait rim instead of being cut off at the bottom; Frames is unchanged). #797 is docs/store only (new store pictures): skip it in the Fixed list, but you may add one plain line that the store pages and README have fresh pictures of the crest on every class. Docs-only PRs otherwise skip.

Use the PR's `## Changelog`, verify against the code on staging. Owner's voice (`C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`), no AI tells, no em dashes. Branded style of the v0.3.4.3 section in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, highlights of 120 characters or fewer, Notes.lua entry with translations (`strings.py sync`, `crlf.py`). Checks: lint, python, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed under 6000. PR `docs(release): v0.3.4.4 notes`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
