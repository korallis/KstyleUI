# Task: release notes for v0.2.9

Write the notes PR for KstyleUI v0.2.9, released from `staging`. It covers everything merged on `staging` since the v0.2.8.2 freeze (`b94abee8`) that the hotfixes v0.2.8.3, v0.2.8.4 and v0.2.8.5 did not already ship (their CHANGELOG sections are already on staging; do not repeat those fixes). Use `git log b94abee8..origin/staging` and the PR bodies' `## Changelog` lines as the source; verify claims against the code, not titles.

PR #654 (Group frames parity round 5) is still in its fix round and will merge before the tag. Write its lines from its PR body now, then rebase onto `origin/staging` after it merges (the coordinator will message you) and check they still hold.

**Lead with**: the crest resource jewels on the Medallions crest (combo points for rogues and cat druids, holy power, soul shards; Action Bars > Crest resource jewels, on by default). Then the big customisation wave in player words, grouped by area (unit frames, party and raid frames, nameplates, cooldowns, auras, chat, minimap, data bars incl. the second bar and forged Medallions dock, bags, tooltips, meters incl. second damage window and reports, quality of life incl. alerts, cursor ring, crosshair, raid tools, slash commands, profiles and sharing, Options What's new page), then faster loading, then remaining fixes. Every new option is off or at today's value unless stated. Never name EllesmereUI, CaithUI or any other UI pack.

**Format**: the branded style of the v0.2.8.2 sections in `CHANGELOG.md` and `docs/RELEASE_NOTES.md` (short intro, 4-6 highlights that fit the Discord embed built by `Tools/release/discord_post.py`, grouped Added/Changed/Fixed lists). Highlights must pass the 120-character rule. Also add the v0.2.9 entry to `KstyleUI_Options/Notes.lua` (run `lua5.1 Tools/regression/test-options-notes.lua`; it prints the entries to paste) and translate its lines in `Tools/locale/<code>.json`, then `python3 Tools/locale/strings.py sync` and `python3 Tools/dev/crlf.py`.

**Checks**: lint and python gates, `test-options-notes`, `test-options-preview-content-locales`, Discord embed size check (`release_payload` in discord_post.py) under 6000 characters. PR title `docs(release): v0.2.9 notes`, target `staging`. Do not merge, tag or post anything.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
