# Task: consumables bar at half the action button size, with its backdrop on

**Goal**: the owner's in-game video (v0.2.7, Medallions, 5120x1440) shows two problems with the consumables bar:
- its buttons are the same size as the action buttons;
- it has no backdrop.

It should be about **half the size of the action buttons**, with the KstyleUI backdrop behind it.

The causes, in `KstyleUI_ActionBars/Settings.lua:101`:
- `defaults.consumables.size = 38`, the same as `BUTTON`;
- `backing = false`.

`Layouts.ConsumableGrid` (`Core/Setup/Layouts.lua:635`) scales `size` by the Medallions slot ratio.

**Change**:
- **Size:** the default is half the action button size, so about 19 units. Keep the Medallions ratio scaling, so it stays half the action buttons in every HUD style. Make the default spacing scale with the size, so the gaps don't stay full-size.
- **Backdrop:** `backing` defaults to true. The backdrop is the existing `Widgets.Chrome` tile, the same material as the action bar backdrops: one consistent style.
- **Readable at half size:**
  - the count, hotkey and cooldown text must stay legible; scale them with the button using the existing text-style path, and check that they are not truncated in the strict renders;
  - the icon keeps its crop and border.
- **Existing players:** defaults are stripped and refilled (see `Core/Store.lua` fill and strip), so untouched values pick up the new defaults with no migration. Keep a player's explicit size or backing choice.
- **Layout:** the consumables footprint shrinks, so check every preset that places the bar (`test-consumables-clearance*`, `test-consumables-layout`, `test-setup-layouts`, `test-hud-caith-*`, `test-layout-*`). Nothing may overlap. "Nothing moves" for the other elements stays true. Update any expected numbers the size change legitimately alters, and say which in the PR.
- **Options:** the existing Size slider and Backdrop toggle now show the new defaults.

**Tests**:
- the default size is half the action button size in Frames, Orbs and Medallions;
- the backdrop is shown by default and hidden when toggled off;
- an explicit saved size or backing is kept;
- the clearance and layout tests pass;
- `test-perf-path-budgets` passes.

**Renders**: the HUD in Frames, Orbs and Medallions at 1920x1080, 2560x1440, 5120x1440 and 3840x2160 (Medallions is the priority, at 5120x1440, which is the owner's screen). Use `--strict` and render over real game backdrops. Include before-and-after crops of the bar. Evidence never committed: `C:/Users/leeba/.cache/kstyleui-evidence/consumables-half/`.

**Constraints**: minimal code; CRLF/ASCII; locales synced if any string changes.

**PR**: open a PR (not a draft) against `staging` titled `fix(actionbars): consumables bar at half size with its backdrop`. Include:
- `## Changelog`: `Changed: The consumables bar is half the size of the action buttons and has a backdrop.`
- `## Options`, `## In-game checks` and `## Before and after`.

Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `Core/Setup/Layouts.lua` (consumable functions only, no new top-level locals), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`.

**Gate**: lint, python and the consumables, actionbars, layout and setup tests under PUC Lua 5.1, then hosted CI. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
