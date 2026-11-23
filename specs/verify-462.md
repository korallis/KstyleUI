# Verify: #462 performance part 2 (P3, P4, P5b/c, P7 slice tail, P12) at 3eb835d6

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `3eb835d6a1209bae9419d2efa2331d20d6dd6b35` (draft PR https://github.com/korallis/KstyleUI/pull/462). Base is `de9665838ee35b384ad4730444b7dd6075eac145`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\audit-impl-P2.md`; plan items in `C:\Users\leeba\.cache\kstyleui-audit\arena\final\plan.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_e26240e9d988\final-report.md`. Decisions already made: P5a (hidden-next-show restyle) and P6 are blocked by secret-aura constraints; P3 and P4 report their real shortfalls; P5b (trailing-edge resize delay) is a visible change and an option, default ON (owner rule).

**Owner constraint**: performance work must not change how anything looks or behaves (P5b excepted, behind its option). A stale 1 px snap after a scale change, a wrong draw order, a region missing when shown, or anything that taints or acts on protected frames in combat is blocking.

**Gate**: `bash scripts/gate.sh lint`, and with PUC `lua5.1` directly the widget, group, layout, perf and pixel tests the PR touches plus `test-comments.lua` and `test-syntax.lua` (the machine is shared; `Tools/tests/test_render_size.py` timeouts on Beast are a known baseline issue). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- P4 cached scale factor: every event that can change an effective scale invalidates the cache (UI scale, display size, root and parent SetScale, reparenting, IgnoreParentScale, Layout Mode scale, Options window scale, engine-owned frames); write a probe comparing cached and live factors after random sequences of these.
- P3 lazy slices: draw order and restyle state equal to eager build (probe), protected owners prepared out of combat.
- P5c input skip: a widget whose real inputs changed is never skipped (fonts, scale, style, accent, text floor).
- P5b: the option works both ways, and with it off the HUD resizes live as before.
- P7 slice skip: size or colour changes always repaint.
- Re-render 3 pairs yourself (Medallions combat 5120x1440, Frames 1920x1080, a raid scene): 0 differing pixels.
- CI run 44293510870 green; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 3eb835d6"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
**Known Beast timeouts**: `Tools/tests/test_render_size.py` PUC subprocess cases time out (60/90 s) on Beast under load, also on unchanged staging; a fix is in progress. If those are your only Python failures, note them in the PR body and let green Mac CI be the final proof; do not ask.
