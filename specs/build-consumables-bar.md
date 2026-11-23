# Task: build the automatic consumables bar

**Goal**: build the consumables bar the owner approved. It fills itself with the best item of each consumable kind the player carries. For example, with Minor and Major Healing Potions it shows only the Major, until the Minor is the best one left. It grows and shrinks with what the player carries, sits attached just above the player frame, and is fully customisable. The approved design and mockups are in `C:/Users/leeba/.cache/kstyleui-evidence/consumable-bar/` (`design.md`, `medallions.png`, `grow.png`, `frames.png`). Follow `design.md`: secure use, finding items, ranking with a curated item-ID list from `Tools/data/items.json`, the twelve kinds and their priority, the combat rules (dim an emptied slot, repack and resize only out of combat), the 12-slot footprint for Layout Mode and the overlap guard, and the risks list. The owner's changes below override it.

**Owner changes**:
1. **Attached to the player frame**, sitting just above it, so it moves with the player frame in every HUD style. In Orbs, where the player frame is replaced, attach it beside the player orb as `design.md` proposes. Add a setting "Attach to the player frame", default ON. When it is off, the bar is a free element the player moves in Layout Mode. Attaching again re-docks it.
2. **Fully customisable, like the action bars**:
   - rows (1, 2, 3 or more), which sets how many buttons go on each row;
   - fill order and growth direction;
   - button size and spacing;
   - fade, show in combat or out of combat, and hide when empty;
   - count, cooldown and keybind text;
   - each of the twelve kinds on or off;
   - other usable consumables on or off.

   Reuse the action bars' existing per-bar option builder and controls (`KstyleUI_ActionBars/Settings.lua` BarRows, from #499) and the same button skin (`Widgets.Slot`), so it looks and behaves exactly like a KstyleUI bar. One consistent style.
3. **On by default** for everyone. It hides itself when the player carries no consumables.
4. **Grow and shrink** stay as designed: anchored on one edge, filled in priority order. With several rows, it fills row by row from the anchor, and the footprint for Layout Mode and the guard is the maximum size for the chosen rows.

**Target**: latest `origin/staging`. A new small module, or a file in `KstyleUI_ActionBars` if that is fewer lines; say which and why. Read `KstyleUI_Bags/Data.lua` (secret-safe bag reads to reuse), `Core/Combat.lua` (the queue), `Core/Setup/Layouts.lua` (elements, footprints, attaching to the player frame) and the layout overlap guard tests.

**Tests**:
- ranking per kind, including Healthstone ranks and conjured food and water;
- grow and shrink out of combat;
- the mid-fight dim and the repack at combat end;
- attached versus free;
- 1, 2 and 3 rows;
- each setting off;
- the overlap guard at 1920x1080, 2560x1440, 5120x1440 and 3840x2160 in all three HUD styles;
- no arithmetic on, or comparison of, secret values.

Renders before and after at the four sizes in Medallions, Frames and Orbs, plus a 2-row and a 3-row example.

**Constraints**: minimal code (design estimate about 500 lines); AGENTS.md rules (secret values, combat lockdown, one event handler per owner, CRLF/ASCII, `K.Widgets.FontString`); the Forever API cited per file; evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/consumables-build/`). Open a **draft** PR against `staging` titled `feat(consumables): a bar that fills itself with your best consumables`. Include `## Summary`, `## Changelog` (`Added: A consumables bar above your player frame that fills itself with the best potion, Healthstone, food, drink, bandage, flask and elixir you carry, and grows or shrinks to fit. Fully customisable in Options.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: the new module or `KstyleUI_ActionBars/**`, `KstyleUI_Options/**` (its page), `Core/Setup/Layouts.lua` (one element and its footprint, no new top-level local), `Core/Layout/**` (attach only if needed), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/data/**` (the curated list), `Tools/regression/**`, `Tools/render/**`, `docs/feature-map.md`, the module README, and a new TOC if it is a new module (TOC rules: `check_toc.py`).

**Gate**: lint, python and the touched modules' tests locally; green Mac CI is the full proof.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, base SHA, PR URL, run id and render paths.
