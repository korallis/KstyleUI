# Task: Hovering an item in the auction house makes it blink

**Goal**: A tester (0xDAB, druid, levelling, Forever) reported this on 2026-11-19 after v0.2.6. "In auction when I hover over the item it starts blinking." Likely cause to check first: v0.2.6's default tooltip at the cursor out of combat (`KstyleUI_Tooltips/**`) puts the tooltip under the mouse, the hovered row gets OnLeave, the tooltip hides, OnEnter shows it again: a loop. Check also any auction house skin and list rows. Fix so the cursor tooltip never sits under the cursor or takes the mouse (offset it from the cursor and keep it from receiving mouse), anywhere: auction house, bags, merchant, quest log, chat links. Add a test that a cursor-anchored tooltip never overlaps the cursor point and is not mouse-enabled. Default: cursor tooltips stay on. Title `fix(tooltips): cursor tooltips never blink under the mouse`; Changelog `Fixed: Item tooltips no longer blink when you hover items in the auction house and other lists.`

**Files it may edit**: KstyleUI_Tooltips/**, KstyleUI_Skins/** (auction house only), Tools/regression/**.

**Constraints**: minimal code; one consistent style; AGENTS.md rules (CRLF/ASCII addon files, one comment per TOC-loaded file, `K.Widgets.FontString`, secret values, combat lockdown, Forever API grep naming the proving file in `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0`). Every behaviour change toggleable in Options with the default stated below. Open a **draft** PR against `staging` with `## Summary` (the cause), `## Changelog`, `## In-game checks`, `## Before and after`. Do not merge.

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Evidence of done**: the cause with file:line; a regression test red before and green after; renders where it is visible; the draft PR's green `checks` run.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Local checks (speed rule, coordinator decision)**: do NOT run the full native Lua suite on Beast (no `bash scripts/gate.sh` or `gate.sh lua`); it starves the shared machine and CI runs the full suite in about 5 minutes. Before pushing run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; green Mac CI (`checks`) is the full proof. Render at most 2 pictures at a time, and only at the screen sizes your items need.

**Screen sizes (owner rule)**: tests and before/after renders for anything placed on screen cover 1920x1080, 2560x1440, 5120x1440 (ultrawide) and 3840x2160 (4K).

**One consistent style (owner rule)**: KstyleUI is "your whole interface, forged as one piece". Anything you add or change must match its siblings exactly (same frame, header, fonts, sizes, spacing, row and bar style), preferably through the same shared builder. Reviewers flag any visual inconsistency as an issue.
