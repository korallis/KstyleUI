# Task: consistency batch 2: nameplate bars on the shared bar builder

**Goal**: Batch 2 from the consistency audit (section 4). Nameplate `FlatBar` becomes `StatusBar{border=true}` with the shared `Widgets.BarEdge` (batch 1, #495, merged: BarEdge has an optional noTrack flag; the rim recolours on `edge.hard` as `Plate.lua:229-231` does). Level and health text use the `number` role, and cast names use the caps role in upper case. Also fix two review notes from batch 1:
- document BarEdge's second parameter in `Core/Widgets/README.md:416`;
- make `test-widgets-unitbar.lua:150` assert what its message says, that a nameplate can recolour its rim.

Use `SIZES.barHeight` (batch 4, merged) for the plate bar height. 11.875 becomes 12, a 0.125-unit change; say so in the Changelog. Title `refactor(nameplates): one bar build`. Changelog `Changed: Nameplate bars, levels and cast names use the same bar and fonts as the rest of the interface.`

**Files it may edit**: `KstyleUI_Nameplates/Plate.lua`, `KstyleUI_Nameplates/Cast.lua`, `KstyleUI_Nameplates/Settings.lua` (bar height default only), `Core/Widgets/README.md`, `Tools/regression/**`, `Tools/render/**`.

**Source**: the consistency audit `C:/Users/leeba/.cache/kstyleui-consistency-audit.md` (sections 1-4 hold every value with file:line, the winner per kind and the batch plan; crops `C:/Users/leeba/.cache/crop_*.png`). **Owner decisions (2026-11-19)**: meter rows put name and number above a 12-unit bar (nameplate style, about 27-unit rows); party and raid health use class colour; party health numbers use the shared `number` font role; short numbers read `12.4K` (capital K/M) everywhere; tracked-buff bars and the tooltip bar join `barHeight` 12. Owner rule: one consistent style, everything forged as one piece; meter bars keep full class colour. Implement exactly your batch from section 4, with the fewest lines (the audit estimates net negative). Visual batches render before/after at 1920x1080, 2560x1440, 5120x1440 and 3840x2160 over a real backdrop, in Frames, Orbs and Medallions where the element shows, at most 2 renders at a time; pixel-only refactors prove zero changed pixels. Saved profiles holding an explicit non-default texture keep it; say so in the Changelog. Open a **draft** PR against `staging` with `## Summary`, `## Changelog` (player words), `## Before and after`, `## In-game checks`. Do not merge.

**Gate**: lint, python and the Nameplates and widgets tests locally; green Mac CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id, render paths.

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Local checks (speed rule, coordinator decision)**: do NOT run the full native Lua suite on Beast (no `bash scripts/gate.sh` or `gate.sh lua`); it starves the shared machine and CI runs the full suite in about 5 minutes. Before pushing run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; green Mac CI (`checks`) is the full proof. Render at most 2 pictures at a time, and only at the screen sizes your items need.

**Screen sizes (owner rule)**: tests and before/after renders for anything placed on screen cover 1920x1080, 2560x1440, 5120x1440 (ultrawide) and 3840x2160 (4K).

**One consistent style (owner rule)**: KstyleUI is "your whole interface, forged as one piece". Anything you add or change must match its siblings exactly (same frame, header, fonts, sizes, spacing, row and bar style), preferably through the same shared builder. Reviewers flag any visual inconsistency as an issue.

**Locale**: any new player-facing string may update `Core/Locales/**` and `Tools/locale/*.json` through `python Tools/locale/strings.py sync`; no need to ask.

**Docs a test checks**: docs that a test validates (such as element-keys.md) may follow your code change without asking.
