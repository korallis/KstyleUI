# Verify: #457 render harness truth (Z1-Z3, Z4-Z6 checklist) at a5afe293

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `a5afe2939a0bafe08b041387f17436bb351a1f1b` (draft PR https://github.com/korallis/KstyleUI/pull/457). Base is `de549a2d0b27776e512222d11f245f9dbfc0e3b4`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\audit-impl-Z.md`; plan items Z1-Z6 in `C:\Users\leeba\.cache\kstyleui-audit\arena\final\plan.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_ff822373a7fa\report.json`.

**Gate**: `bash scripts/gate.sh lint`, `bash scripts/gate.sh python`, and with PUC `lua5.1` directly the render and pixel tests the PR touches plus `test-comments.lua` and `test-syntax.lua` (the machine is shared). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- Z1: the harness multiplies a region's SetAlpha by its SetVertexColor alpha exactly as the client does (Forever source or docs; name them), and nothing that was correct before changes. Which existing pictures change, and is each change the harness becoming truthful?
- Z2: RENDER_FX=cast/stopped/ready/burst draw their peak; cooldown edge and number come from the addon's own calls, not invented harness art.
- Z3: shoot.sh writes PNGs from Git Bash on Windows with Windows file URLs and accepts `/c/...` and `C:/...` backdrop paths, and still works on macOS (the Mac CI and Lee's Macs): check the code paths for both; no output left inside the repo.
- Run shoot.sh yourself on Beast for hud_reference Medallions 1920x1080 with a `C:/Users/leeba/.cache/kstyleui-backdrops/game_02.png` backdrop: it must write the PNG.
- docs/TESTING.md Z4-Z6 checklist is clear for the owner.
- CI run 44269853186 green; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified a5afe293"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
