# Task: release notes for v0.2.13

Write the notes PR for KstyleUI v0.2.13, released from `staging`, covering everything since tag `v0.2.12.1` (`git log v0.2.12.1..origin/staging`): #713 guides on the left (RestedXP and Zygor guide card top left above the party frames, quest log alone on the story rail, threat no longer follows the guide; credit Baine for Zygor where it reads naturally), #712 raid warnings and Edit Mode fit 3:2 screens, plus tests/docs (#714; skip test-only items). Use each PR's `## Changelog`; verify against the code; give the Options paths. Branded style of the v0.2.12 sections in `CHANGELOG.md` and `docs/RELEASE_NOTES.md` (intro, highlights of 120 characters or fewer, Added/Changed/Fixed, Upgrading note for the guide move and the retired threat-follows-guide setting). Notes.lua entry with translations, `strings.py sync`, `crlf.py`. Checks: lint and python gates, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed size under 6000. PR `docs(release): v0.2.13 notes`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
