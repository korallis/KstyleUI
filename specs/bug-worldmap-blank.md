# Task: the skinned world map is blank until you zoom

**Goal**: the owner, from his game (3456x2234 MacBook, Medallions, Thunder Bluff): "map only appears if you zoom. seems to be a bug." The skinned "Map & Quest Log" window opens showing only an empty parchment with the player arrow and Cursor/Player coordinates; the map tiles draw only after zooming. Screenshot: `C:\Users\leeba\.cache\lee-shots\worldmap-blank.png`.

**Target**: KstyleUI on the latest `origin/staging`. `KstyleUI_Skins/WorldMap.lua` (and any PartB/PartC helpers it uses), Blizzard's WorldMapFrame / MapCanvas in the Forever UI source (`forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone `C:\Users\leeba\.cache\wow-ui-source`).

**Change**: find the root cause (likely candidates: the skin hides or re-parents the map's scroll container or a data-provider layer, changes the canvas size or scale after the map computed its zoom, strips a texture region that is actually the map tile layer, or resizes the window so the canvas never refreshes until a zoom event; Blizzard calls such as `OnCanvasSizeChanged`, `RefreshAll`, `ScrollContainer:ZoomOut`, `MapCanvasMixin`). Fix it in the skin so the map draws at the default zoom when the window opens, after resizing, after changing zone or continent through the breadcrumb, and when the quest log panel is shown or hidden. Never call protected functions in combat; the map must also open in combat. Test: a behaviour test that the map canvas has its tile layer shown and refreshed at the default zoom after open and after a size change (red on staging, green after), plus a render of the window. Add an in-game check list (open map; change zone via breadcrumb; toggle quest log; open in combat). Per the owner rule, if the fix changes how the skin behaves, the existing World Map skin toggle covers it; if there is none, the skin must already be switchable off.

**Constraints**: AGENTS.md rules (CRLF/ASCII, one comment per TOC-loaded file, Forever API grep naming the file, combat lockdown, taint safety). Another worker is restyling skinned windows (G11) in `KstyleUI_Skins/**`: keep to the world map code and rebase before the PR. Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Open a **draft** PR against `staging`: title `fix(skins): the world map draws without zooming first`, `## Summary`, `## Changelog` (`Fixed: The world map shows the map as soon as it opens, without zooming first.`), `## In-game checks`. Do not merge.

**Files it may edit**: `KstyleUI_Skins/WorldMap.lua`, `KstyleUI_Skins/PartB/**` and `PartC/**` only where the map uses them, `Tools/regression/**`, `Tools/render/scenes/**`.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Evidence of done**: the reproducing test red then green; a render of the open map; the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id and Gate output.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
