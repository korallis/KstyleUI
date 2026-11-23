# Task: release notes for v0.2.11

Write the notes PR for KstyleUI v0.2.11, released from `staging`. It covers everything merged on `staging` since the v0.2.10 tag (`git log v0.2.10..origin/staging`): #671 crest jewel polish, #679 hawk perches, and contributor Baine's #677 Zygor Guides Viewer skin, which is being merged now (read its body and `## Changelog` at https://github.com/korallis/KstyleUI/pull/677; if it is merged when you finish, rebase and confirm). Use each PR's `## Changelog` lines as the source; verify claims against the code, not titles.

**Lead with**: Zygor Guides Viewer support (the guide sits on the story rail like RestedXP and takes the KstyleUI theme; where to switch it: KstyleUI Skins > Zygor; credit Baine by name), then the Medallions crest: polished resource jewels (cut gems that flare on a gain, drain on a spend, the whole rune ring glows at max; Glow at max switch) and hawk perches for Beast Mastery hunters' Summon Hawk (idea from Baine; Action Bars > Slab and cooldowns > Hawk perches, on by default). Then the `/kstyle perf nan` fix from #677. Never name EllesmereUI, CaithUI or any other UI pack.

**Format**: the branded style of the v0.2.10 sections in `CHANGELOG.md` and `docs/RELEASE_NOTES.md` (short intro, 4-6 highlights that fit the Discord embed built by `Tools/release/discord_post.py`, grouped Added/Changed/Fixed lists). Highlights pass the 120-character rule. Add the v0.2.11 entry to `KstyleUI_Options/Notes.lua` (run `lua5.1 Tools/regression/test-options-notes.lua`; it prints the entries to paste) and translate its lines in `Tools/locale/<code>.json`, then `python3 Tools/locale/strings.py sync` and `python3 Tools/dev/crlf.py`.

**Checks**: lint and python gates, `test-options-notes`, `test-options-preview-content-locales`, Discord embed size check (`release_payload` in discord_post.py) under 6000 characters. PR title `docs(release): v0.2.11 notes`, target `staging`, `no changelog` label. Do not merge, tag or post anything.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
