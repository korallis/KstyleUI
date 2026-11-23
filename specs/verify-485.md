# Verify: #485 at b8dde24d

Work only in your own worktree; never change `C:\Projects\KstyleUI` or another worktree. Check out `b8dde24dc5a8c2bbbe5dd10599c3d6555b2100d6` (draft PR https://github.com/korallis/KstyleUI/pull/485), base `8a5a451a133fa4e7731b7733ccd3ecc5fd27274d`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\bug-minimap-edge.md`, source plan `C:\Users\leeba\.cache\kstyleui-audit\arena\final\plan.md` (only the items the spec names). Author report: `C:/Users/leeba/AppData/Local/Temp/orca-ctx_2a2e9dab28f5/report.md`.

**Local checks**: `bash scripts/gate.sh lint`; with PUC `lua5.1` the tests the PR touches plus `test-comments.lua` and `test-syntax.lua`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start. At most 2 renders, 1920x1080 only (`--ppu 1`, `--strict`, `--backdrop /c/Users/leeba/.cache/kstyleui-backdrops/game_03.png`), only where you need to see a claim.

**Checks**: each item matches the plan's Change text (sizes, tokens, timings); every new setting defaults ON and turning it off restores the previous look and behaviour; nothing outside the items changes (the author's zero-pixel diffs hold); Forever APIs proven against the `forever` branch of Gethe/wow-ui-source at `9dc84f0` (clone `C:\Users\leeba\.cache\wow-ui-source`); secret values, combat lockdown, one event handler per owner; no perf regression on hot paths (event handlers, OnUpdate). **Minimal code**: report every behaviour-identical cut (file:line, smaller version, lines saved); over-engineering is an issue.

**Report**: start with "verified b8dde24d"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags". Be fast: one pass, no full suite.
