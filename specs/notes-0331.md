# Task: release notes for hotfix v0.3.3.1

Write the notes PR for v0.3.3.1 from `staging`, covering `git log v0.3.3..origin/staging` once these are merged: #777 polish batch F (minimap buttons inside the round ring, drawer and zoom slider, tracked-bar counts, proc glow width, the proc glow can't stay invisible), #781 setup cards (the picked HUD style and role cards show the accent edge only, no green wash or missing square, the Tank card shows its pick, pictures sit evenly in their cards, tabs fit long German and French labels), and the player status sockets and compass fix (sockets show only when lit, no stray dots; the minimap N sits on the forged ring). Docs-only PRs skip.

**Credit (owner's instruction)**: these hotfixes come from Baine's reports. Credit him by name in the notes: a line under the v0.3.3.1 heading such as "Thanks to Baine for spotting these." and keep the Fixed lines in player words. Same credit in `docs/RELEASE_NOTES.md` and the Notes.lua entry (translated).

Use each PR's `## Changelog`, verify every line against the code on staging. Owner's voice (`C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`), no AI tells, no em dashes. Branded style of the v0.3.3 section in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, highlights of 120 characters or fewer, Notes.lua entry with translations (`strings.py sync`, `crlf.py`). Checks: lint, python, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed under 6000. PR `docs(release): v0.3.3.1 notes`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
