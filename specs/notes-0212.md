# Task: release notes for v0.2.12

Write the notes PR for KstyleUI v0.2.12, released from `staging`. It covers everything merged on `staging` since tag `v0.2.11` that hotfix v0.2.11.1 did not already ship (its section is on staging; do not repeat the Cooldown Manager fix): `git log v0.2.11..origin/staging`. PR #702 (Medallions fits MacBook and 3:2 screens) is in review; include it if merged when you finish, else leave a clearly marked line I can drop. Use each PR's `## Changelog` lines; verify against the code.

**Lead with**: KstyleUI is now Medallions only (Frames and Orbs removed; your HUD moves to Medallions on update with one chat line; setup is shorter); then the class crowns over the crest for every class (rogue crown of blades, cat-druid claws, warrior banners/Sunder, priest candles/Shadow Weaving, mage shards/Arcane Blast, bear talons/Lacerate, hunter arrows/Sniper Shot; Class-themed pips, on by default); then shamans: Spirit Poles (totem bar on the crest with flyouts, Ghost Wolf and Call medals, right-click Call = Recall, Shift right-click dismiss) and Storm Orbs (Lightning Shield charges on the crest); then cast bars on the player and target frames; then "your choices win over the Medallions look", no duplicate player-frame buffs, the MacBook/3:2 fit, performance fixes. Where to switch each on/off (exact Options paths from the code). Never name EllesmereUI, CaithUI or any other UI pack.

**Format**: the branded style of the v0.2.11 sections in `CHANGELOG.md` and `docs/RELEASE_NOTES.md` (short intro, 4-6 highlights that fit the Discord embed in `Tools/release/discord_post.py`, grouped Added/Changed/Fixed, an Upgrading note), 120-character highlights. Add the v0.2.12 entry to `KstyleUI_Options/Notes.lua` (run `lua5.1 Tools/regression/test-options-notes.lua`) with translations in `Tools/locale/<code>.json`, `python3 Tools/locale/strings.py sync`, `python3 Tools/dev/crlf.py`.

**Checks**: lint and python gates, `test-options-notes`, both `test-options-preview-content-locales*`, `Tools.tests.test_release_changelog`, embed size under 6000. PR `docs(release): v0.2.12 notes`, target `staging`, label `no changelog`. Do not merge, tag or post.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
