# Verify: #459 ink and text on the world (A1-A7, B1-B4, D5, D6) at d05b61e1

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `d05b61e13e7ff5c99bcdd2c84cc77409c66a1ef5` (draft PR https://github.com/korallis/KstyleUI/pull/459). Base is `de549a2d0b27776e512222d11f245f9dbfc0e3b4`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\audit-impl-A.md`; plan items in `C:\Users\leeba\.cache\kstyleui-audit\arena\final\plan.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_9a8d4f60a061\worker-report.txt` (render paths inside).

**Decisions already made by the coordinator or owner (check they are followed, do not reopen)**: the meter bars keep their full class colours (owner); InkFor decides the cast label only, the timer stays light and outlined; when the bar ends empty the label uses light ink; A7 is a harness artifact with no addon change, pinned by a test; TextScrim backings are soft backing in the clearance checks; slab tracking unchanged; now-zero pixel_allow entries removed.

**Gate**: `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the tests the PR touches plus `test-comments.lua` and `test-syntax.lua` (the machine is shared; CI ran the full suite). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- Each item matches the plan's Change text (or a recorded decision); measure the stated contrasts yourself on 3 of the author's after renders over real backdrops.
- Secret values: InkFor and the loss-band tint never read or compare a secret colour (skip when secret); nothing reads state back from engine aura buttons.
- No regression: open the author's before/after pairs and re-render 3 yourself (Medallions combat 5120x1440 over game_02, Frames 1920x1080 over game_03, raid tiles); everything outside the items is pixel-identical (the author's zero-diff table: spot-check 2).
- Tokens.lua changes are only the named tokens; Layouts.lua keeps its 7-local margin; strings synced.
- CI run 44274965270 green; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified d05b61e1"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
