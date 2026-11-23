# Task: mockup of the minimap dressed in the Medallions crest style

**Goal**: a player suggested the minimap should have artwork consistent with the Medallions theme, most likely the central crest ring. The owner wants mockups of how that would look. Change no addon code.

**Target**: the Medallions crest hub art and its ring textures (`Media/Textures/Medallions/**`, `Ring*.png`, `RingBevel.png`, `RingLine*.png`). The Medallions hub code (`KstyleUI_ActionBars/Slab.lua`) and the unit medallion rings (`Core/Widgets/Medallion.lua`) show how they are layered. Also the minimap module (`KstyleUI_Minimap/**`) and its scenes (`Tools/render/scenes/gallery_minimap.lua`, `minimap_plaque.lua`, `minimap_ornaments.lua`).

**Change**: render the Medallions HUD at 1920x1080 (`--ppu 1`, `--strict`) over the clean, UI-free game_03 crop that earlier mockups used (see `C:/Users/leeba/.cache/kstyleui-evidence/mockup-extra-bars/`). Render the minimap scene too. Then, with Pillow and only the real repository art (no invented art), make mockups that dress the round minimap the way the crest hub is dressed: the gunmetal bevel ring, the engraved rune ring in class colour, and the same edge light.
- **A, ring only**: the minimap framed by the crest's gunmetal bevel ring and rune ring, with the zone plaque and clock bar in the same metal.
- **B, crest medallion**: A plus small medallion details from the hub. For example, the north marker as a small crest gem at the top, and the plaque seated like the level plaque under the crest.
- **Today**: the current minimap, for comparison.

Make each a close-up crop of the minimap corner at about 500x500, plus one full 1920x1080 picture of B in place, so the minimap and the central crest read as a set. Add a quiet "Mockup" caption. Save everything to `C:/Users/leeba/.cache/kstyleui-evidence/minimap-medallions/`, then open each picture and check it is on style.

**Constraints**: no repository changes and no PR. At most 2 renders at a time.

**Evidence of done**: the paths, with one line each on what they show.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
