# Task: stubs: SetTexture after SetAtlas clears the atlas, as the client does

**Goal**: the #544 review found the reverse case open. In `Tools/regression/stubs/wow.lua`, in both the recorded stub and the quiet stub, calling `t:SetAtlas('X')` and then `t:SetTexture('a.png')` leaves `GetAtlas()=='X'`. The client clears the atlas, and `Tools/render/scene.lua:1171` would then draw the atlas sheet over the new file. Make SetTexture (and SetColorTexture, if the client does the same; prove it from the Forever source at 9dc84f0) clear the atlas in both stubs. Add a test that fails before. Keep every other test green. If the change exposes real addon bugs, list them; don't fix them here.

**Constraints**: minimal. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/fu-H/`). Open a PR (not a draft) against `staging` titled `test(stubs): SetTexture clears the atlas`, with the `no changelog` label. Renders pixel-identical at 1920x1080. Do not merge.

**Files it may edit**: `Tools/regression/stubs/**`, `Tools/regression/**` (tests), `Tools/render/scene.lua` (only if needed).

**Gate**: lint, python and the stub tests; hosted CI. Send worker_done with the run id once it's green.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`.
