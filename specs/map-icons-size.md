# Task: Map icons are too small

**Goal**: A tester (0xDAB, druid, levelling, Forever) reported this on 2026-11-19 after v0.2.6. "I don't like that map icon compactment, too small, can't see." Find what KstyleUI shrinks or compacts on the maps: the minimap addon-button drawer (`KstyleUI_Minimap/Drawer.lua`), minimap pins and tracking icons (`Pins.lua`), and the world map skin's pins. Make them readable: at least Blizzard's default size on every screen size, the drawer showing buttons at full size rather than squeezed. If compaction is a deliberate feature, keep it as an Options choice defaulting to off. Same style as the rest of the UI. Title `fix(minimap): map icons at a readable size`; Changelog `Fixed: Minimap and map icons are no longer shrunk; compact icons are an option.`

**Files it may edit**: KstyleUI_Minimap/**, KstyleUI_Skins/** (world map pins only), Core/Locales/**, Tools/regression/**, Tools/render/**.

**Constraints**: minimal code; one consistent style; AGENTS.md rules (CRLF/ASCII addon files, one comment per TOC-loaded file, `K.Widgets.FontString`, secret values, combat lockdown, Forever API grep naming the proving file in `C:/Users/leeba/.cache/wow-ui-source` at `9dc84f0`). Every behaviour change toggleable in Options with the default stated below. Open a **draft** PR against `staging` with `## Summary` (the cause), `## Changelog`, `## In-game checks`, `## Before and after`. Do not merge.

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Evidence of done**: the cause with file:line; a regression test red before and green after; renders where it is visible; the draft PR's green `checks` run.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Local checks (speed rule, coordinator decision)**: do NOT run the full native Lua suite on Beast (no `bash scripts/gate.sh` or `gate.sh lua`); it starves the shared machine and CI runs the full suite in about 5 minutes. Before pushing run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; green Mac CI (`checks`) is the full proof. Render at most 2 pictures at a time, and only at the screen sizes your items need.

**Screen sizes (owner rule)**: tests and before/after renders for anything placed on screen cover 1920x1080, 2560x1440, 5120x1440 (ultrawide) and 3840x2160 (4K).

**One consistent style (owner rule)**: KstyleUI is "your whole interface, forged as one piece". Anything you add or change must match its siblings exactly (same frame, header, fonts, sizes, spacing, row and bar style), preferably through the same shared builder. Reviewers flag any visual inconsistency as an issue.
