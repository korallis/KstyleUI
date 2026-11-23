# Task: render the Options pictures for a player's reply (GitHub #484), fast

**Goal**: a player on a 32:9 ultrawide (5120x1440) uses the default Centred arrangement and wants the minimap and chat out at the screen edges ("like before, spaced out"). We will reply on GitHub showing exactly which setting to change. Produce the pictures; post nothing.

**Change**:
1. Render the KstyleUI Options window open on the page that holds "Ultrawide arrangement" (`Core/Layout/Layout.lua:110`, key `arrangement`; find the page via `KstyleUI_Options` and `Tools/render/scenes/gallery_options.lua`), with the dropdown set to **Spread** and its row clearly visible (a thin accent outline drawn around that row in the picture is fine, added after the render with Pillow; no text on the image). If a scene parameter is missing to open that page or set the value, add the smallest scene option in `Tools/render/scenes/` (no addon code change). Also show the "HUD width" row just above it.
2. Render the Medallions HUD at 5120x1440 (`--ppu 1.3333333333`) Centred and Spread, DPS layout, over a real game backdrop (`--backdrop /c/Users/leeba/.cache/kstyleui-backdrops/game_NN.png`, a bright outdoor one), `--strict`.
3. Save the three images as JPEGs (quality 85, under 1 MB each) to `C:/Users/leeba/.cache/gh484/` as `options-arrangement.jpg`, `centred-5120.jpg`, `spread-5120.jpg`. Open each and check it shows what it should.

**Constraints**: no addon code changes; a scene tweak only if needed, committed in a draft PR against `staging` titled `test(render): open Options on a named page` with label `no changelog`. If no scene change was needed, open no PR. At most 2 renders at a time. On Beast see `C:/Users/leeba/.claude/projects/C--Projects-KstyleUI/memory/beast-render-harness-chrome-urls.md` if a render writes no PNG.

**Evidence of done**: the three file paths and one line each on what they show; the PR URL if any.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
