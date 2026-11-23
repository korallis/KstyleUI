# Task: release notes for v0.3.4, the crest for every class

Write the notes PR for v0.3.4 from `staging`. v0.3.3.1 was a hotfix cut from v0.3.3 with cherry-picks (#777, #781, #782), so cover only what staging adds since then: #776 (warrior, paladin, rogue crests plus the shared crest system: major cooldowns burn round the rim, five-second rule for mana users, each piece its own switch, Frames row above the stance bar), #778 (hunter, mage, warlock; Soul Shards read from the bags), #771 (priest, druid with every form incl. bear tank pieces, shaman extensions), #785 (medal counts sit inside their medal) and #784 (world map reopen, search box top-right, zone labels keep their size). Docs-only PRs skip. Headline: every class now has its own crest, one place to look.

**Credit (owner's instruction)**: the map fixes come from Baine's report; credit him by name on those lines, as the PR changelog does. Hunter sting and Rapid Fire tracking came from hunter player feedback in Discord; say "thanks to the hunters in Discord" (no name).

Use each PR's `## Changelog`, verify every line against the code on staging (spell names must match what the trackers actually track). Owner's voice (`C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`), no AI tells, no em dashes. Keep it readable: one short line per class, not a wall of text. Branded style of the v0.3.3 and v0.3.3.1 sections in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, highlights of 120 characters or fewer, Notes.lua entry with translations (`strings.py sync`, `crlf.py`). Checks: lint, python, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed under 6000. PR `docs(release): v0.3.4 notes`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
