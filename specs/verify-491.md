# Verify: #491 at 545901e1

Work only in your own worktree; never change `C:\Projects\KstyleUI` or another worktree. Check out `545901e18d2e5dc9e06f5d30b428bdc9f79d55e8` (draft PR https://github.com/korallis/KstyleUI/pull/491), base `8278d84744b5d0a1ee1ab0d4e3a9ec8e0b3eb5f9`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\map-icons-size.md`. Author report: `C:/Users/leeba/AppData/Local/Temp/orca-ctx_ebb001d65753/report.md`.

**Local checks**: `bash scripts/gate.sh lint`; with PUC `lua5.1` the tests the PR touches plus `test-comments.lua` and `test-syntax.lua`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start. At most 2 renders, 1920x1080 only (`--ppu 1`, `--strict`, `--backdrop /c/Users/leeba/.cache/kstyleui-backdrops/game_03.png`), only where you need to see a claim.

**Checks**: each item matches the plan's Change text (sizes, tokens, timings); every new setting defaults ON and turning it off restores the previous look and behaviour; nothing outside the items changes (the author's zero-pixel diffs hold); Forever APIs proven against the `forever` branch of Gethe/wow-ui-source at `9dc84f0` (clone `C:\Users\leeba\.cache\wow-ui-source`); secret values, combat lockdown, one event handler per owner; no perf regression on hot paths (event handlers, OnUpdate). **Minimal code**: report every behaviour-identical cut (file:line, smaller version, lines saved); over-engineering is an issue. **Consistency**: flag any element that does not match its siblings in look (frame, header, fonts, sizes, spacing, row and bar style).

**Report**: start with "verified 545901e1"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags". Be fast: one pass, no full suite.
