# Task: action bar options that are easy to find, with every setting for every bar (EllesmereUI parity)

**The owner's words** (in-game, v0.2.7): "the action bars are hard to adjust, i.e. finding the settings for action bar 2 etc. They should all be easy to access in the menu. Furthermore I couldn't find a single setting for setting the number of buttons on any action bar other than bar 1. The point of the customisation options was to rival the same level of customisation as EllesmereUI."

**Today's state**:
- `KstyleUI_ActionBars/Settings.lua:225-300` builds one section per bar, shown only when the "edit bar" dropdown (`EditOptions`, `settings.editBar`) selects it.
- A Buttons slider exists for every bar except consumables (`:245`), but the owner never found it. Either the dropdown is not discoverable, or switching it doesn't refresh the page. **Check that first in the render harness and the regression stubs**: select bar 2, 3, 4 and so on, and confirm their sliders appear and write their own settings. If it's a bug, fix it and add a regression.

**Change**:
1. **Navigation:**
   - replace the hidden dropdown with an always-visible bar picker at the top of the Action Bars page: a row of tabs or chips for Bar 1 to Bar N, Pet, Stance, Consumables and any other bar `ns.BARS` defines;
   - the selected bar's full settings show below it, and the picker stays visible while scrolling if the Options kit already supports that cheaply;
   - clicking a bar in Layout Mode (the existing mover) can open the Options page on that bar, if that is a few lines;
   - one consistent style: use the Options kit's existing tab or segmented control. If there is none, build it from the existing button widget, not a new framework.
2. **Every setting for every bar:**
   - the same full set on every action bar: buttons, rows, orientation, growth, size, spacing, split, show empty, backing, fade, hotkey, count, macro, cooldown and paging;
   - every slider and toggle writes to that bar only;
   - the Medallions slab note stays, but its explanation must be clear about why rows and spacing are hidden for bars 1 and 2 while the slab is on, with a one-click "Turn off the slab" link if that is a few lines.
3. **EllesmereUI parity audit:**
   - list EllesmereUI's action bar options from public sources only (CurseForge or Wago pages, its public docs or screenshots; copy no code), and mark each as present, missing or not possible on Forever;
   - implement the missing ones that are a few lines each and fit the existing schema. Likely candidates are per-bar visibility (combat, target, mouseover, macro conditions), per-bar opacity, per-bar scale and an out-of-range colour;
   - list larger ones in the report as follow-ups;
   - everything is toggleable and ON by default only where that doesn't change what players see today; a new behaviour defaults to today's look.

**Tests**:
- the picker selects each bar and shows that bar's settings;
- each bar's Buttons slider changes only that bar's button count;
- the new options write and apply;
- a hidden bar's rows don't show;
- `test-perf-path-budgets` passes, because the Options page is lazy-built, so keep the reload cost flat.

**Renders**: the Action Bars Options page at 1920x1080 and 5120x1440 with Bar 2 selected, plus the HUD with Bar 2 at 6 buttons. Render over real game backdrops with `--strict`. Evidence never committed: `C:/Users/leeba/.cache/kstyleui-evidence/actionbars-options/`.

**PR**: open a PR (not a draft) against `staging` titled `feat(options): every action bar's settings one click away`. Include:
- `## Changelog`: `Changed: The Action Bars options have a bar picker, so every bar's settings, including its number of buttons, are one click away.` Add an `Added:` line for any new options;
- `## Options`, `## In-game checks`, `## Before and after`;
- the parity table, or a link to it.

Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `KstyleUI_Options/**`, `Core/Widgets/**` (only if the Options kit needs a tab control), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, the ActionBars README.

**Constraints**: minimal code; CRLF/ASCII; locales synced with translations.

**Gate**: lint, python, the actionbars and options tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI. Send worker_done once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id, render paths and the parity table path.
