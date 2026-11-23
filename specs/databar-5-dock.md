# Task: data bar batch 5: micro menu dock and the Medallions slab dock

**Goal**: build batch 5 of the approved data bar. The design is `C:/Users/leeba/.cache/kstyleui-evidence/xiv-databar/design.md` (section 4, Medallions dock and micro menu; PR 5 row), and the mockup is `closeup_medallions_dock_2x.png` in that folder. Batch 1 is draft #512 on branch `korallis/databar-top-bar-zones`. **Base your branch on `korallis/databar-top-bar-zones`** and open a PR stacked on it. Batches 3 and 4 (the new readouts, `KstyleUI_DataBars/Readouts.lua`) run in parallel on the same base, so keep your `Strip.lua` edits small.

**Scope**:
- **Micro menu in the bar.** In Frames and Orbs, the micro menu docks into the bar's left zone with `Menus.SetDock`. Each button stays a secure click on Blizzard's own, and docking and undocking wait for `Combat.Queue`. The bag bar keeps its own slot.
- **Medallions:** the bar becomes two quiet instrument lines along the slab's foot, in the caps face and muted ink of the XP caption.
  - The left zone starts under the left wing; the right zone ends at the XP caption's left edge. The centre zone joins the left, because the crest owns the middle.
  - The micro menu keeps its own hover-faded slot.
  - The slab's hub-ring overlap check exempts `databars.strip` when docked, the same way it exempts `databars.xp`.
- **Placement option:** add "Docked under the action bars" to the bar's Position. It's the Medallions default; Frames and Orbs default to Top.
- **Forged artwork** in Medallions uses the slab's metal.

**Rules**:
- An absent key is today's behaviour, beyond #512's own migration. If you need a migration, take the next free number at rebase time; #512 uses 41.
- Near-zero reload cost; `test-perf-path-budgets` stays under 15.7M.

**Tests**: dock and undock in and out of combat; the overlap guard in Medallions, DPS, Tank and Healer at 1920x1080, 2560x1440, 5120x1440 (Centred and Spread) and 3840x2160; the micro buttons still click Blizzard's. Renders of the Medallions dock and the Frames top bar with the menu, at all four sizes.

**Constraints**: minimal code; AGENTS.md rules. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/databar-5/`). Open a **draft** PR with base `korallis/databar-top-bar-zones`, titled `feat(databars): micro menu in the bar and the Medallions slab dock`, with `## Changelog` (`Added: The micro menu sits in the data bar, and in Medallions the data bar docks along the foot of the action bar slab.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `KstyleUI_DataBars/**`, `KstyleUI_ActionBars/Slab.lua` (the dock anchor only), `Core/Setup/Layouts.lua` (the dock footprint and the hub exemption; no new top-level local), `Core/Layout/**` (only if the dock needs it), `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/statecharts/**` (if the setup flow changes), `docs/feature-map.md`, the module README.

**Gate**: lint, python and the DataBars and layout tests plus `test-perf-path-budgets` under PUC Lua 5.1. Send worker_done once local proof is done.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
