# Verify: #456 audit performance part 1 (P1, P2, P8, P9, P10 subset, P11) at f21c1e58

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `f21c1e58dd2f8cf89c2fbf5574025aa60875af11` (draft PR https://github.com/korallis/KstyleUI/pull/456). Base is `de549a2d0b27776e512222d11f245f9dbfc0e3b4`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\audit-impl-P1.md`; plan items in `C:\Users\leeba\.cache\kstyleui-audit\arena\final\plan.md` (batch P). Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_1163d644501e\report.txt`.

**Owner constraint**: performance work must not change how anything looks or behaves. A differing pixel, a stale value on screen, a missing string in a non-English client, or a Lua error is blocking.

**Gate**: `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the tests for the files the PR touches plus `test-comments.lua` and `test-syntax.lua` (the machine is shared; CI ran the full suite). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- P1 saved scale answer: the cache key covers everything that changes the result (addon version, preset, physical size, style, arrangement, canvas, enabled-element signature, saved layout edits, UI scale CVar); a stale key can never apply a wrong scale; SavedVariables shape is safe across versions; the warm value equals the cold one to %.17g.
- P9 locale loading: deDE, esES, frFR and zhCN clients still load their strings (Forever source for `AllowLoadTextLocale` / the TOC syntax used; name the file); enUS loads none; check_toc.py and the packager handle the syntax; the packaged zip still contains the locale files.
- P8: ranges set only on max-health/unit change without comparing secret values; animation restarts; the ToT ticker still updates on target-of-target changes.
- P2, P10, P11: the data strip, meter rows and quest log update whenever their text, width or rank changes; nothing animates while hidden, and everything that should animate when shown still does.
- Re-render 3 pairs yourself (Medallions combat 5120x1440, Frames 1920x1080, data strip/meter scene): 0 differing pixels.
- CI run 44266039655 green; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified f21c1e58"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
