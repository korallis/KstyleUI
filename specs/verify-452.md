# Verify: #452 build widget art on first use at 457b68df

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `457b68df3a680f6afd1ad4272f1e794cad18c506` (draft PR https://github.com/korallis/KstyleUI/pull/452). Base is `55175d21b9f7a1ef74ef92e7cb2c7b1cef4a7da3`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\perf-2-lazy-regions.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_7bf93f8269e4\REPORT.md`. Approved scope extension: `Core/Skin.lua` StripRegions varargs change.

**Owner constraint**: performance work must not change how anything looks. Any differing pixel, a missing hover/press/proc/glow layer, wrong draw order, or a region created or shown on a protected frame in combat is blocking.

**Gate**: `bash scripts/gate.sh lint`, and with PUC `lua5.1` directly the widget, actionbars, unitframes, tooltips and skins tests plus `test-widgets-lazy.lua`, `test-comments.lua` and `test-syntax.lua` (the machine is shared; CI ran the full suite). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- Draw order: lazily created pieces keep today's layer, sublevel and creation order relative to their siblings (textures on one sublevel draw in creation order). Probe it.
- Every setter that touched an eager region (colour, alpha, size, texture, restyle, hover, press, proc, glow start/stop, style switch, scale change) reaches a lazily built one; state is recorded and applied on build, never read back from regions. Write a probe that drives random sequences through base and head and compares every region's state.
- First-use in combat on secure buttons: no protected calls, no taint, no stall (first hover, first proc in combat).
- Pixel proof: re-render 3 of the author's pairs (Medallions combat 5120x1440, Frames idle 1920x1080, a tooltip or Options scene) base vs head: 0 differing pixels; confirm the region-count drop (16,887 -> 10,188 Medallions).
- CI run 44224673202 green for the SHA; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 457b68df"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
