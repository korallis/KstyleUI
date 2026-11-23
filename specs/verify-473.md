# Verify: #473 at b264bf70

Work only in your own worktree; never change `C:\Projects\KstyleUI` or another worktree. Check out `b264bf70a500855f0aff35224e5b8b48dc9e09c4` (draft PR https://github.com/korallis/KstyleUI/pull/473), base `92135ee2369fa44474f2d8cf739b8c601d4da5fc`; staging is now `1d7b6359` (check the PR merged onto it too). Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\fix-harness-texture-alpha.md`, plus the coordinator's ruling: the one-value model applies to Textures only (proven in game by the v0.2.2 hub fix); FontStrings keep the previous model; Skins callers may change only where a texture's later SetVertexColor/SetColorTexture revived something hidden with SetAlpha. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_569230a00b2c\report.txt`.

**Local checks**: `bash scripts/gate.sh lint`; with PUC `lua5.1` the tests the PR touches plus `test-skins-*.lua`, `test-comments.lua`, `test-syntax.lua`, on the head and on the head merged onto `origin/staging`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start. At most 2 renders at a time.

**Checks**: the stub and `Tools/render/scene.lua` follow last-write-wins for Textures only, with the Forever evidence cited (`forever` branch of Gethe/wow-ui-source at `9dc84f0`, clone `C:\Users\leeba\.cache\wow-ui-source`); FontString behaviour unchanged from base; the Skins changes are each a real client bug of that kind (prove with the client rule, not the stub); `KstyleUI_GroupFrames/Auras.lua` passes `WASH_ALPHA`; no allowance lists were loosened; the medallions hub at rest shows no shock ring or flash (render `hud_reference` Medallions idle at 1080p over `C:/Users/leeba/.cache/kstyleui-backdrops/game_01.png`, `--strict`). Over-engineering is an issue (minimal-code rule): name any cut and its smaller version. CI run 44339459733 green.

**Report**: start with "verified b264bf70"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".
