# Task: release notes for v0.2.9

Write the notes PR for KstyleUI v0.2.10, released from `staging`. It covers everything merged on `staging` since the v0.2.9 tag (`git log v0.2.9..origin/staging`) that the hotfixes v0.2.9.1 and v0.2.9.2 did not already ship (their sections are already on staging; do not repeat those fixes). Use the PR bodies' `## Changelog` lines as the source; verify claims against the code, not titles.

**Lead with**: KstyleUI draws less every frame (the hidden see-through ring and frame centres, about a fifth less drawn area, no look change) and the new Medallions switches to trade effects for frame rate (Low-health vignette, Ambient hub effects, both on by default; where they live in Options). Then `/kstyle perf` (thanks to contributor Baine, credit them by name) and how a player uses it when reporting frame rate, then the party and raid frame options (#666), then remaining changes and fixes. Every new option is off or at today's value unless stated. Never name EllesmereUI, CaithUI or any other UI pack.

**Format**: the branded style of the v0.2.8.2 sections in `CHANGELOG.md` and `docs/RELEASE_NOTES.md` (short intro, 4-6 highlights that fit the Discord embed built by `Tools/release/discord_post.py`, grouped Added/Changed/Fixed lists). Highlights must pass the 120-character rule. Also add the v0.2.10 entry to `KstyleUI_Options/Notes.lua` (run `lua5.1 Tools/regression/test-options-notes.lua`; it prints the entries to paste) and translate its lines in `Tools/locale/<code>.json`, then `python3 Tools/locale/strings.py sync` and `python3 Tools/dev/crlf.py`.

**Checks**: lint and python gates, `test-options-notes`, `test-options-preview-content-locales`, Discord embed size check (`release_payload` in discord_post.py) under 6000 characters. PR title `docs(release): v0.2.10 notes`, target `staging`. Do not merge, tag or post anything.

**Files it may edit**: `CHANGELOG.md`, `docs/RELEASE_NOTES.md`, `KstyleUI_Options/Notes.lua`, `Core/Locales/*`, `Tools/locale/*`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report PR number, SHA and run id.
