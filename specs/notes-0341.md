# Task: release notes for hotfix v0.3.4.1

Write the notes PR for v0.3.4.1 from `staging`, covering `git log v0.3.4..origin/staging`: #788 only (party frames no longer show one buff twice; the External and Big defensives indicators stay empty on Forever, which does not classify defensives, instead of both showing the member's top buff such as Find Minerals or a zone buff). Say in player words that those two indicators only light up for real defensives, which Forever does not report yet, so they stay empty for now. Docs-only PRs skip.

**Credit (owner's instruction)**: Baine reported it; credit him by name, as v0.3.3.1 did ("Thanks to Baine for spotting this."). Same credit in `docs/RELEASE_NOTES.md` and the Notes.lua entry (translated).

Use the PR's `## Changelog`, verify against the code on staging. Owner's voice (`C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`), no AI tells, no em dashes. Branded style of the v0.3.3.1 section in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, highlights of 120 characters or fewer, Notes.lua entry with translations (`strings.py sync`, `crlf.py`). Checks: lint, python, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed under 6000. PR `docs(release): v0.3.4.1 notes`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
