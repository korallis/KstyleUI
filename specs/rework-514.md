# Task: rework draft PR #514: skins DO restyle other addons, safely

**Goal**: #514 (branch `korallis/fix-skin-text-pass`, head c19f827a) makes the skin text pass skip other addons' frames inside skinned windows. **The owner has decided the opposite: skins should restyle other addons too**, so the whole UI looks like one piece. The real problem the audit found (`C:/Users/leeba/.cache/kstyleui-evidence/compat-audit/report.md`, finding 4) is that the pass breaks other addons' layouts: it raises every font string to at least body size, so their text grows past their own frames, and it keeps permanent `SetFontObject` and `SetTextColor` hooks that fight their code. Rework #514 on its branch so KstyleUI restyles other addons' frames **without breaking them**.

**Change**:
- **Keep restyling** other addons' text inside skinned windows: KstyleUI's font face and colours.
- For a frame whose `GetSourceLocation()` is not a `Blizzard_` path (keep the IsSecret check and the proof you already have), **keep that font string's own size**. Change the face and colour only, never the size, so its layout still fits.
- Do not add the permanent `SetFontObject` and `SetTextColor` hooks to other addons' strings. Restyle them on the existing skin and `OnShow` passes only, so their own later changes win.
- Add an Options setting on the Skins page, "Restyle other addons' text", ON by default. Off leaves other addons' text exactly as they draw it.
- Blizzard windows stay pixel-identical, exactly as your current renders prove.

**Tests**: replace G3 with: an addon-made string under a skinned window gets KstyleUI's font face and colour but keeps its original size and gets no permanent hooks. With the setting off, it is unchanged. Blizzard strings are unchanged from base. Optional cut from review: drop the four-screen loop at `test-skins-registry.lua:132`.

**Constraints**: minimal code. Retitle the PR `fix(skins): other addons' text matches without breaking their layout` and update the Changelog line (`Fixed: KstyleUI restyles other addons' text inside skinned windows without making it overflow their frames.`). It stays a draft; do not merge. The staging reload budget is being fixed separately, so if Lua shard 1 fails only on `test-perf-path-budgets`, say so.

**Files it may edit**: `KstyleUI_Skins/**`, `KstyleUI_Options/**` (the setting), `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`.

**Gate**: lint, python and the Skins tests locally; CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA and run id.
