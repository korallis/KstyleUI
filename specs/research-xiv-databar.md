# Task: research and design an XIV-style data bar in the KstyleUI style (read-only, with mockups)

**Goal**: the owner wants a data bar like the XIV_Databar addon, but in KstyleUI's own style and cleverly integrated, with full control from the Options window to add and remove items. XIV_Databar is a slim bar along the top or bottom of the screen. It shows a micro menu, clock, gold, durability, bag space, spec and talents, hearthstone and travel, FPS and latency, experience and reputation, guild and friends counts, and currencies, each clickable. Find what KstyleUI already has, then propose the design. Do not build it yet.

**Target**: latest `origin/staging`, read-only:
- `KstyleUI_DataBars/**`. `Strip.lua` is the existing data strip, `Sources.lua` the data sources, `Menus.lua` the micro menu, and `Bars.lua` the XP and reputation strip. Its README and `docs/feature-map.md` describe them.
- The Options pages (`KstyleUI_Options/**`, `Core/Options.lua`) and Layout Mode (`Core/Layout/Layout.lua`, `Core/Setup/Layouts.lua`).
- The consistency audit at `C:/Users/leeba/.cache/kstyleui-consistency-audit.md` (one card, one bar, one font set).
- The Forever UI source (`C:/Users/leeba/.cache/wow-ui-source`, `forever` branch at `9dc84f0`). Cite file:line for every API.

**Research**:
1. **What exists today.** List what the current strip and data sources already show, how they are placed and styled, and how they are configured. Cite file:line.
2. **XIV_Databar's public behaviour.** Its modules and what each click and tooltip does, from its public documentation and listing. Cite the source; copy no code.
3. **Modules for Forever.** Which modules make sense on Forever, and the API for each: clock and calendar, gold with a session change and a tooltip of characters, durability, bag space, spec and talents, hearthstone and travel cooldowns, FPS and latency, XP and reputation, guild and friends online, currencies, micro menu. Note any secret values and any combat restrictions.
4. **Clever integration.** How this unifies with the existing strip and micro menu rather than duplicating them. For example, the current strip grows into the data bar, so there is one source system and one look. Cover placement per HUD style:
   - a full-width top bar in Frames and Orbs;
   - a docked strip in Medallions;
   - Centred and Spread on ultrawide.

   The layout overlap guard must still pass at 1920x1080, 2560x1440, 5120x1440 and 3840x2160.
5. **Options design.** An Options page where the player can:
   - add and remove modules with toggles;
   - reorder them by drag or up/down buttons;
   - choose left, centre or right zones;
   - set each module's own options (clock format, gold display and so on);
   - choose position (top, bottom or docked), height, and background opacity.

   Every module defaults to a sensible on or off state. Follow the owner rule that new things are toggleable and default on, and say which modules start on.

**Mockups**: render the Frames and Medallions HUDs at 1920x1080 over the clean game_03 crop used before. With Pillow, add the proposed data bar using the real KstyleUI card chrome, fonts and icon art from the repository; do not invent art. Make full-screen pictures plus a close-up crop of the bar. Also make one mockup of the Options page, built from a render of the existing DataBars Options page, showing the add, remove and reorder list. Save everything to `C:/Users/leeba/.cache/kstyleui-evidence/xiv-databar/`.

**Report**: write `C:/Users/leeba/.cache/kstyleui-evidence/xiv-databar/design.md`. Keep it short: what exists, the proposed modules and their defaults, how integration and placement work, the Options design, risks, and a lines estimate split into PR-sized batches. Change no code.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
