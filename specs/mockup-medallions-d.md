# Task: mockup D: small Medallions bars beside the slab, as the player described

**Goal**: we showed a player mockups A, B and C of extra Medallions action bars (`C:/Users/leeba/.cache/kstyleui-evidence/mockup-extra-bars/`). They replied that they want small extra bars almost touching the slab, as a double row (like 6+6 or 4+4), with 8 to 10 buttons each, or small bars under each unit frame. Make mockup **D** that shows this. Change no addon code.

**Change**: reuse `plate.png` and `hud.png` in that folder (the Medallions DPS HUD at 1920x1080 over the clean game_03 crop), or re-render the same way (`--ppu 1`, `--strict`) if you need a clean layer. With Pillow, copying only the slab's own socket art and chrome:
- **D**: two small bars of 8 buttons each, laid out 2 rows x 4, one on each side of the slab. Each sits just under its unit frame (player on the left, target on the right) and almost touches the slab's outer end, with the slab's own socket gap. Nothing overlaps the unit frames, cast bars, slab or XP line.
- Fill the sockets with icons from the render's existing action icons.
- Add quiet labels in the same style as A, B and C ("Bar 4" left, "Bar 5" right) and a "Mockup" corner caption.
- Crop to the same area as A, B and C (about 1100x420), saved as `D-beside-slab.png`. Also make `ABCD.png`, the four crops stacked 2x2 with their letters, so the player can compare.

Open both pictures and check they look on-style and nothing overlaps.

**Constraints**: no repository changes and no PR. At most 2 renders at a time.

**Evidence of done**: the PNG paths, with one line each.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
