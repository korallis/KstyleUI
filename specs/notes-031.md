# Task: release notes for v0.3.1

Write the notes PR for v0.3.1 from `staging`, covering `git log v0.3.0..origin/staging`: #753 item levels on the character window's equipment slots and the inspect window (bags already had them; Window Skins > Character > Item levels, on by default); #754 the lit glass finish on the Blizzard bars KstyleUI skins (trainer, legacy rewards and challenges, RestedXP progress, quest tracker timers and progress; same General > Appearance > Lit glass bars switch); #756 fixes: every world map route step now has a name (no more "Road to" with nothing after it), and party/raid frames no longer go solid and hide the name when someone has a debuff you can dispel; docs and roadmap PRs (#752, #755) skip.

Use each PR's `## Changelog`, verify every line against the code on staging, and give the Options path for each setting. Owner's voice (`C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`), no AI tells, no em dashes. Branded style of the v0.3.0 section in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, highlights of 120 characters or fewer, Notes.lua entry with translations (`strings.py sync`, `crlf.py`). Checks: lint, python, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed under 6000. PR `docs(release): v0.3.1 notes`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
