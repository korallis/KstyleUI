# Task: every action bar fully configurable in every HUD style

**Goal**: the owner wants every action bar to be fully configurable from `/kstyle` the way the player wants it, including size and buttons per row. Today `KstyleUI_ActionBars/Settings.lua:137-176` (BarRows) offers per bar:
- buttons;
- rows;
- fill order;
- growth;
- button size;
- spacing;
- show empty;
- backing;
- fade.

Find where these options do not apply. Likely places:
- the Medallions slab, where bars 1 and 2 sit in fixed sockets;
- the Frames and Orbs trays;
- the pet, stance and possess bars;
- bar 3 beside the slab.

Then make every option work for every bar in every style.

**Target**: KstyleUI on latest `origin/staging`: `KstyleUI_ActionBars/**`, `Core/Setup/Layouts.lua` (bar footprints), and the Options Action Bars page.

**Change**:
1. Build a table of bars against styles against options, showing what works today, what is ignored and what is hidden (cite file:line). Put it in the PR body.
2. Make each ignored or hidden option work:
   - **Bars 1 and 2 in Medallions:** add a "Use the Medallions slab" toggle on the Action Bars page, default ON, so today's look is kept. Off makes bars 1 and 2 free bars with every option, styled with the same KstyleUI button skin. While the slab is on, offer the options that make sense inside it: button size scales the slab; buttons per side caps at 12; keybind, count and macro text; fade. Hide options that cannot apply, with a help line saying why.
   - **Frames and Orbs trays:** the same approach. A "Use the tray" toggle, default ON, frees the bars when turned off.
   - **Pet, stance and possess bars:** buttons, buttons per row (rows), size, spacing, growth and fade, like the other bars.
   - **Buttons per row:** if players think in buttons per row, keep the existing Rows slider and add a clear label or help, for example "Rows (12 buttons in 2 rows = 6 per row)". Do not add a second control for the same thing.
3. Changing any option updates the bars at once out of combat, and in combat queues until combat ends. Layout Mode footprints follow the new sizes, so setup overlap checks stay true.
4. Add tests:
   - each option changes the live bar in each style;
   - toggles off give the same look as before (zero-pixel diff);
   - combat queues the change.

   Render before and after for a few configurations (for example 6 buttons in 2 rows at size 40, and a free bar 1 in Medallions) at 1920x1080, 2560x1440, 5120x1440 and 3840x2160.

**Options**: new toggles default ON and keep today's look. Changelog `Added: Every action bar can be sized and arranged in Options, in every HUD style, including the Medallions slab bars.`

**Constraints**: minimal code; reuse BarRows and the shared button builder; one consistent style; secure frames only change out of combat (combat lockdown); AGENTS.md rules. Other open work: the drag fix (#490) edits `KstyleUI_ActionBars/Button.lua`, and the layout overlap guard (ctx_e14b02bfdd40) and consistency batch 4 (ctx_19278c972e84) edit `Core/Setup/Layouts.lua`. Keep hunks small and rebase before the PR. Open a **draft** PR against `staging` titled `feat(actionbars): every bar sized and arranged your way`, with sections `## Summary` (the table), `## Changelog`, `## Options`, `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `KstyleUI_Options/**` (Action Bars page only), `Core/Setup/Layouts.lua` (bar footprints), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`.

**Gate**: lint, python and the ActionBars and layout tests locally. Green Mac CI is the full proof.

**Evidence of done**: the table; tests red before and green after; renders; the draft PR's green `checks` run.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.
