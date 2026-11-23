# Task: one more mockup: the Medallions slab with two rows each side of the crest

**Goal**: we asked a player on Discord about extra Medallions action bars, and showed mockups A and B in `C:/Users/leeba/.cache/kstyleui-evidence/mockup-extra-bars/`. The owner wants a third option, **C**: the slab itself carries two rows of buttons on each side of the central crest ring instead of one. Bars 1 and 2 stay as they are, and the new rows hold bars 4 and 5, so there are 4 rows of 12 in total, 24 per side. Change no addon code.

**Change**: render the same Medallions DPS HUD at 1920x1080 (`--ppu 1`, `--strict`) over the same UI-free crop of game_03 that mockups A and B used. With Pillow, make `C-two-rows.png` in the same folder:
- The slab grows one row taller. Copy the slab's own socket row and chrome, so each side shows two stacked rows of 12 sockets with the slab's own socket gap.
- The crest ring stays centred vertically across both rows.
- The unit frames, cast bars and XP line move up or down only as much as needed to stay clear.
- Fill the new row with icons from the render's existing action icons.
- Add quiet labels in the same style as A and B ("Bar 4: utility" on the left upper row, "Bar 5: consumables" on the right upper row), plus a "Mockup" corner caption.
- Crop to the same area as A and B, about 1100x420.

Open the result and check it looks on-style and nothing overlaps.

**Constraints**: no repository changes and no PR. At most 2 renders at a time.

**Evidence of done**: the PNG path and one line on what it shows.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
