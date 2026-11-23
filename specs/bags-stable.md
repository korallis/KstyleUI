# Task: Bags stop jumping and resizing

**Goal**: A tester (0xDAB, druid, levelling, Forever) reported this on 2026-11-19 after v0.2.6. "Bags are jumping, better to not compact them like this, changing size is bad." The bags window must keep a stable size and stable slot positions while you loot, sell, split or sort: no window resize and no slot reflow on each item change. New default: a fixed grid sized for all your bag slots (empty slots shown as empty sockets in the KstyleUI style), items stay in their slots until you sort. Keep today's compact behaviour as an Options choice ('Compact bags', default off). Check the bank and reagent views the same way. Find where `KstyleUI_Bags` resizes and re-lays slots on BAG_UPDATE. Test: looting into, selling from and splitting stacks keeps the window size and every other slot's position. Title `feat(bags): a steady bag window`; Changelog `Changed: The bag window keeps its size and your items stay put; compact bags are an option.`

**Files it may edit**: KstyleUI_Bags/**, Core/Locales/**, Tools/regression/**, Tools/render/**, docs/feature-map.md.

**Constraints**: minimal code; one consistent style; AGENTS.md rules (CRLF/ASCII addon files, one comment per TOC-loaded file, `K.Widgets.FontString`, secret values, combat lockdown, Forever API grep naming the proving file in `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0`). Every behaviour change toggleable in Options with the default stated below. Open a **draft** PR against `staging` with `## Summary` (the cause), `## Changelog`, `## In-game checks`, `## Before and after`. Do not merge.

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Evidence of done**: the cause with file:line; a regression test red before and green after; renders where it is visible; the draft PR's green `checks` run.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Local checks (speed rule, coordinator decision)**: do NOT run the full native Lua suite on Beast (no `bash scripts/gate.sh` or `gate.sh lua`); it starves the shared machine and CI runs the full suite in about 5 minutes. Before pushing run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; green Mac CI (`checks`) is the full proof. Render at most 2 pictures at a time, and only at the screen sizes your items need.

**Screen sizes (owner rule)**: tests and before/after renders for anything placed on screen cover 1920x1080, 2560x1440, 5120x1440 (ultrawide) and 3840x2160 (4K).

**One consistent style (owner rule)**: KstyleUI is "your whole interface, forged as one piece". Anything you add or change must match its siblings exactly (same frame, header, fonts, sizes, spacing, row and bar style), preferably through the same shared builder. Reviewers flag any visual inconsistency as an issue.
