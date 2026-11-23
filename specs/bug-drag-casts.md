# Task: Dragging an action button casts its spell

**Goal**: A tester (0xDAB, druid, levelling, Forever) reported this on 2026-11-19 after v0.2.6. "When I move icons on panels I use the skill I move." Dragging a spell off or between KstyleUI action buttons (Frames, Orbs, Medallions; main, pet, stance and bar 3) must pick it up without casting it, the way Blizzard's bars behave. Find the cause in `KstyleUI_ActionBars/**` and `Core/Widgets/IconButton.lua` (likely clicks registered on mouse down, `ActionButtonUseKeyDown`, or a click handler running before the drag starts; compare Blizzard's ActionButton handling in the Forever source) and fix it. Keep cast-on-key-down for key presses if that is the current setting. Default: fixed (no setting needed unless the fix changes how clicks feel; then a toggle defaulting to the fixed behaviour). Title `fix(actionbars): dragging a button never casts it`; Changelog `Fixed: Moving a spell on your action bars no longer casts it.`

**Files it may edit**: KstyleUI_ActionBars/**, Core/Widgets/IconButton.lua, Core/Widgets/Slot.lua, Tools/regression/**.

**Constraints**: minimal code; one consistent style; AGENTS.md rules (CRLF/ASCII addon files, one comment per TOC-loaded file, `K.Widgets.FontString`, secret values, combat lockdown, Forever API grep naming the proving file in `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0`). Every behaviour change toggleable in Options with the default stated below. Open a **draft** PR against `staging` with `## Summary` (the cause), `## Changelog`, `## In-game checks`, `## Before and after`. Do not merge.

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Evidence of done**: the cause with file:line; a regression test red before and green after; renders where it is visible; the draft PR's green `checks` run.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Local checks (speed rule, coordinator decision)**: do NOT run the full native Lua suite on Beast (no `bash scripts/gate.sh` or `gate.sh lua`); it starves the shared machine and CI runs the full suite in about 5 minutes. Before pushing run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; green Mac CI (`checks`) is the full proof. Render at most 2 pictures at a time, and only at the screen sizes your items need.

**Screen sizes (owner rule)**: tests and before/after renders for anything placed on screen cover 1920x1080, 2560x1440, 5120x1440 (ultrawide) and 3840x2160 (4K).

**One consistent style (owner rule)**: KstyleUI is "your whole interface, forged as one piece". Anything you add or change must match its siblings exactly (same frame, header, fonts, sizes, spacing, row and bar style), preferably through the same shared builder. Reviewers flag any visual inconsistency as an issue.
