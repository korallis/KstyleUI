# Task: a mockup of extra Medallions action bars, to check a player's request

**Goal**: a player asked on Discord:

> "On my favourite layout (Medallions), could you add one or two more action bars while keeping the clean look? At least two extra bars, maybe stacked above and below Bar 1 or Bar 2, to give space for a utility bar (professions, Hearthstone, toys, poisons) and a consumables bar (pre-pots, flasks, elixirs, food, Healthstones)."

Make two mockup pictures we can post to ask whether this is what they meant. This is not a feature, so change no addon code.

**Change**:
1. Render the Medallions HUD (DPS layout) at 1920x1080 (`--ppu 1`, `--strict`) over a clean, bright, real game backdrop from `C:/Users/leeba/.cache/kstyleui-backdrops/`. Check the backdrop first: it must have no game UI baked in. Use the default scene with the slab and its 12-plus-12 sockets.
2. Using Pillow (no addon changes), build two mockups from that render by copying the slab's own socket row, so the extra bars wear exactly the same chrome and socket art:
   - **A, stacked above**: two extra 12-button rows stacked above the slab, centred on it, with the same gap as the slab's own spacing. The lower one is a "utility" row and the upper one a "consumables" row.
   - **B, above and below**: one extra row above the slab (utility) and one below it (consumables), keeping the XP line visible.

   Fill the extra sockets with icons from the render's own existing action icons, or leave them as empty sockets. Do not invent new art.
3. Add small, quiet text labels beside each new row ("Bar 4: utility", "Bar 5: consumables") in the KstyleUI caption style (Cinzel or Alegreya, muted gold), plus a corner caption "Mockup". Crop each picture to the bottom-centre HUD area, about 1100x420, so the bars read clearly. Save both as PNGs under `C:/Users/leeba/.cache/kstyleui-evidence/mockup-extra-bars/` (`A-stacked.png`, `B-above-below.png`). Open each and check it looks right and on-style.

**Constraints**: no repository changes and no PR; renders and mockups go only in the evidence folder. At most 2 renders at a time. On Beast see `C:/Users/leeba/.claude/projects/C--Projects-KstyleUI/memory/beast-render-harness-chrome-urls.md`.

**Evidence of done**: the two PNG paths, each with one line on what it shows.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
