# Task: showcase renders of the crest jewels and nameplate combo points (no PR)

The owner wants to post in Discord #chat what the v0.2.9 class-resource features look like. Make clean, branded showcase pictures with the render harness from tag `v0.2.9` (check it out in your worktree), over real game backdrops (`~/.cache/kstyleui-backdrops`, never the AI mockup plate), `--strict`, at 1920x1080 `--ppu 1` (crop tightly so the feature reads on a phone):

1. Medallions crest jewels, one crop per class: rogue combo points (embers, e.g. 3 of 5 lit), paladin holy power (gold, e.g. 3 of 5), warlock soul shards (violet, 3 of 5). Show a bit of the slab around the crest for context.
2. One wider Medallions HUD shot (player, target, slab and crest) with a rogue's combo points lit, so people see where it sits.
3. Nameplates "Combo points on the target" (Options > Nameplates > Class resource): a target plate with combo points, crop around a couple of plates.

Use the scenes and `RENDER_*` variables in `docs/feature-map.md` / `Tools/render/README.md` (the class is chosen like `--class HUNTER`; the jewels need the power values supplied as the hud scene does for `GetComboPoints`/`UnitPower`). If a needed fixture switch is missing, add the smallest scene-only switch in your worktree (do not open a PR). Save PNGs (and a compressed JPG of each under 400 KB) to `C:/Users/leeba/.cache/kstyleui-evidence/showcase-jewels/` with clear names (crest-rogue, crest-paladin, crest-warlock, hud-rogue, nameplate-combo). Look at every picture before reporting: lit counts right, nothing clipped, no stray overlaps.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md` (no PR needed). Report the file list.
