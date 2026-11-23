# Task: Medallions extra-bar presets (mockups C and D), off by default

**Goal**: a player asked for extra Medallions action bars. The owner wants two layouts offered as **quick presets** in Options. Both are off by default. A preset only lays the bars out for the player: afterwards every bar stays fully editable, movable and anchorable as usual (rows, size, Layout Mode position). Think ElvUI-style freedom, plus one-click presets. The mockups are in `C:/Users/leeba/.cache/kstyleui-evidence/mockup-extra-bars/`. Read `C-two-rows.png`, `D-beside-slab.png` and `ABCD.png`; `hud.png` and `plate.png` are the base.
- **C, two rows on the slab** (the player's favourite): the slab grows one row taller and carries two rows of 12 on each side of the crest. Bars 1 and 2 stay where they are; bars 4 and 5 fill the new upper rows, in the slab's own sockets, spacing and chrome. The crest stays centred vertically across both rows. The unit frames, cast bars and XP line move only as much as needed to stay clear.
- **D, beside the slab**: bars 4 and 5 as small 2x4 bars (8 buttons each) at the outer ends of the slab, almost touching it (the slab's socket gap), level with the slab's top and just under the unit frames, in the slab's socket skin. At 1920x1080 the left bar meets the chat card: the preset must keep it clear, by the least move of the chat's default or the bar. A player's saved chat position is never moved.

**Options**:
- On the Action Bars page, shown only in Medallions, add "Extra bars layout" with three values: Off (default, today's look; bars 4 and 5 keep their current settings), Two rows on the slab (C) and Beside the slab (D).
- Choosing C or D enables bars 4 and 5 and writes their rows, buttons, size and positions; then the player can change anything.
- Choosing Off restores the bars' previous settings, which you save when a preset is applied.
- Changes apply out of combat only (bars are secure); queue through `Core/Combat.lua`.

**Target**: latest `origin/staging`.
- `KstyleUI_ActionBars/Slab.lua` (slab chrome and hub; C needs the slab to support a second row per side).
- `KstyleUI_ActionBars/Settings.lua` (BarRows, #499).
- `Core/Setup/Layouts.lua` (bar4 and bar5 entries and footprints; no new top-level local).
- `Core/Layout/**` and the layout overlap guard tests.

Reuse what exists; a preset should be a small table of settings, not new layout machinery.

**Tests**:
- each preset sets the expected bar settings and positions, and Off restores the previous ones;
- after a preset, the player's own edits stick;
- no secure changes in combat;
- the overlap guard passes for C and D in Medallions, DPS, Tank and Healer, at 1920x1080, 2560x1440, 5120x1440 (Centred and Spread) and 3840x2160, including saved positions.

Renders of Off, C and D at the four sizes (`--strict`) over real game backdrops.

**Constraints**: minimal code; AGENTS.md rules; the owner's style rule (one consistent style: the extra rows look exactly like the slab's own). Evidence is never committed (`C:/Users/leeba/.cache/kstyleui-evidence/bar-presets/`). Update `docs/statecharts/` if the arrangement or layout flow changes. Open a **draft** PR against `staging` titled `feat(actionbars): Medallions extra-bar presets` with:
- `## Changelog`: `Added: Two quick layouts for extra action bars in Medallions: two rows on the slab, or small bars beside it. Pick one under Extra bars layout in Options; everything stays movable.`
- `## Options`, `## In-game checks` and `## Before and after`.

Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `KstyleUI_UnitFrames/**` (only the C-preset offsets, if needed), `KstyleUI_Chat/**` (only the D clearance default, if needed), `KstyleUI_Options/**`, `Core/Setup/Layouts.lua`, `Core/Layout/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, `docs/statecharts/**`, the module README.

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.
