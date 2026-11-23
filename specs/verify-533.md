# Verify: #533 at 52136411

Work only in your own worktree; never change `C:\Projects\KstyleUI` or another worktree. Check out `52136411b461a9be7f2af5ca232ef07dffaf3b2a` (draft PR https://github.com/korallis/KstyleUI/pull/533), base `785145f7872d361ce0815d008a2056686dc5e443`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\medallions-caith-layout.md`. Author report: `C:/Users/leeba/.cache/kstyleui-evidence/medallions-caith/verification-summary.txt`.

**Local checks**: `bash scripts/gate.sh lint`; with PUC `lua5.1` the tests the PR touches plus `test-comments.lua` and `test-syntax.lua`. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start. At most 2 renders, 1920x1080 only (`--ppu 1`, `--strict`, `--backdrop /c/Users/leeba/.cache/kstyleui-backdrops/game_03.png`), only where you need to see a claim.

**Checks**: each item matches the plan's Change text (sizes, tokens, timings); every new setting defaults ON and turning it off restores the previous look and behaviour; nothing outside the items changes (the author's zero-pixel diffs hold); Forever APIs proven against the `forever` branch of Gethe/wow-ui-source at `9dc84f0` (clone `C:\Users\leeba\.cache\wow-ui-source`); secret values, combat lockdown, one event handler per owner; no perf regression on hot paths (event handlers, OnUpdate). **Minimal code**: report every behaviour-identical cut (file:line, smaller version, lines saved); over-engineering is an issue. **Consistency**: flag any element that does not match its siblings in look (frame, header, fonts, sizes, spacing, row and bar style).

**Report**: start with "verified 52136411"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags". Be fast: one pass, no full suite.
