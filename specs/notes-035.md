# Task: release notes for v0.3.5, the crest comes alive

Write the notes PR for v0.3.5 from `staging`, covering `git log v0.3.4.5..origin/staging` (#803, #805, #802, #804, #806, #809, #807, #808, #814, #813, #810, #815, #811, #812). Headline: the crest comes alive. No more little icons on the crest: every class's tracked buffs, debuffs, procs and cooldowns are now part of the crest itself (perched objects, overlays, fuses and grooves on the ring), plus ten new crest effects inspired by the old WeakAuras centre-piece UIs (Unleashed cooldowns, rising heat, glyph tide, stance mantle, cast/swing/global cooldown rings, expiring embers, kill window, target lock), shared cooldown sigils, trinkets on the rim. Also: the energy tick spark, readable expiring timers everywhere (with a Warn under setting), windows and pages that show at once (no more invisible-window bugs), RestedXP/loot-roll/Zygor fixes, raid timers clear of the power strip (Frames raid keeps 3 debuffs, no timer text).

Group it so it is easy to read: a short crest section (one line per class family at most, plus the ten effects as one compact list), then Added/Changed/Fixed. Every piece has its own switch (say so once). Credit: the hunter sting/Rapid Fire tracking came from hunters in Discord (already credited in v0.3.4, don't repeat); no new player credits.

Use each PR's `## Changelog`, verify against staging. Owner's voice (`C:/Users/leeba/.cache/kstyleui-evidence/voice/lee-discord-voice.txt`), no AI tells, no em dashes. Branded style of the v0.3.4 section in `CHANGELOG.md` and `docs/RELEASE_NOTES.md`, highlights of 120 characters or fewer, Notes.lua entry with translations (`strings.py sync`, `crlf.py`). Checks: lint, python, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed under 6000. PR `docs(release): v0.3.5 notes`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
