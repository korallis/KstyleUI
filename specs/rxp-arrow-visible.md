# Task: make the skinned RestedXP waypoint arrow easy to see in dark zones

**Goal**: the owner reports: "the RestedXP arrow is black but is hard to see when in Tirisfal and other dark areas." With KstyleUI's RestedXP skin, the guide's waypoint arrow must stand out clearly on dark ground (Tirisfal Glades, night, caves, Shadowmoon) and still on bright ground (snow, desert), while staying in the KstyleUI style.

**Target**: KstyleUI on the latest `origin/staging`. `KstyleUI_Skins/Addons/RestedXP/Chrome.lua:786-792` (`PaintArrow`: desaturates RestedXP's arrow texture and multiplies it by `Style.Accent()`, `KstyleUI_Skins/Style.lua:207`), `:1246-1260` (`Arrow`, hooks on `UpdateVisuals` and `SetupArrow`). Desaturating then vertex-colouring multiplies, so a dark source texture or a dark accent comes out near black.

**Change**:
1. Find why it reads as black: inspect RestedXP's arrow texture (the RestedXP addon source, if available in the WoW AddOns folder on this machine or its public repository; otherwise the stub scene) and the accent value for the default and class sources.
2. Make it legible on any ground: e.g. a bright tint (the accent lifted to a high-lightness version, or the KstyleUI gold/ivory text token from `Core/Tokens.lua` via the skin's existing helpers) plus a dark outline or soft shadow copy of the arrow behind it, so it has contrast both ways. Keep the arrow's distance text readable the same way. Do not edit `Core/Tokens.lua`.
3. Keep RestedXP's own behaviour (rotation, hiding, the arrow's texture coords and size) untouched; only colour and the added contrast layer.
4. Test: extend the RestedXP skin regression test so the painted arrow has a minimum luminance and a contrast layer, for the default, class and custom accent sources (including a dark custom accent).

**Proof**: render the arrow (existing RestedXP scene from `docs/feature-map.md`, or add one in `Tools/render/scenes/`) over a dark backdrop (near-black green-grey like Tirisfal) and a bright one at 1920x1080 and 5120x1440, before and after; open and describe the PNGs and give the WCAG contrast ratio of the arrow against each backdrop (target at least 3:1 on both). Nothing else in any scene may change: pixel-diff `hud_reference` (3 styles, 1920x1080) and the other RestedXP scenes outside the arrow, 0 differing pixels.

**Constraints**: AGENTS.md rules (CRLF/ASCII addon files via `python Tools/dev/crlf.py`, one comment per TOC-loaded file, `K.Widgets.FontString`, Forever API grep, secret values). Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Test slots are shared and busy: be patient, never stop other processes. Open a **draft** PR against `staging`: title `fix(skins): RestedXP arrow stays visible in dark zones`, body with `## Summary`, `## Changelog` (`Fixed: The RestedXP guide arrow is now easy to see in dark zones such as Tirisfal Glades.`), `## In-game checks` (Tirisfal at night, a snow zone), before/after pictures described. Do not merge.

**Files it may edit**: `KstyleUI_Skins/Addons/RestedXP/**`, `KstyleUI_Skins/Style.lua` (a helper only, if needed), `Tools/regression/**`, `Tools/render/scenes/**`, `Tools/render/guard_allow.tsv`, `docs/feature-map.md`.

**Gate**: `bash scripts/gate.sh` (natively green on Windows; Known failing: none).

**Evidence of done**: test red on staging and green after; before/after renders with contrast ratios; zero-diff table for everything else; the draft PR's green `checks` run.

**Before worker_done**: follow `C:\Users\leeba\orca-jev-router\WORKER.md`. Report SHA, base SHA, PR URL, run id, Gate output and evidence.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
