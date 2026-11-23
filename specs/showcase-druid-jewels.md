# Task: render the cat-form druid crest jewels GIF (no PR)

The owner wants Discord showcase GIFs of the polished crest jewels (merged #671) for every class that has them. Rogue, paladin and warlock exist in `C:/Users/leeba/.cache/kstyleui-evidence/task_d868cb696347/` (crest-<class>-1080.gif and -5120.gif); the cat-form druid is missing. Make `crest-druid-1080.gif` and `crest-druid-5120.gif` from current `origin/staging` the same way and matching those GIFs exactly in crop, length, frame rate, backdrop and story (0 -> max one point at a time, the full-ring glow at max, then a spend), with the druid in cat form (Medallions, `RENDER_FX=jewels`, see `Tools/render/README.md` and the jewels row of `docs/feature-map.md`). If the harness lacks a cat-form switch, add the smallest scene-only switch in your worktree (no PR). `--strict`; under 8 MB each. Look at every frame before reporting: amber druid colour, counts right, nothing clipped.

Save into the same folder. Max 2 renders at a time (Beast speed rule).

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md` (no PR). Report the file paths.
