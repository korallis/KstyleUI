# Verify: #458 rails and windows (G1, G3, G7, G10, G11) at 6578282b

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `6578282b7db35934e577512acfe3a88daa74a377` (draft PR https://github.com/korallis/KstyleUI/pull/458). Base is `de9665838ee35b384ad4730444b7dd6075eac145`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\audit-impl-Ga.md`; plan items in `C:\Users\leeba\.cache\kstyleui-audit\arena\final\plan.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_0d1aa456e038\report.md` (render paths inside). Owner rules: every change toggleable in Options and ON by default; the meter bars keep their full class colours (only text may change); decisions recorded with the coordinator: G1 includes docking the data strip into the meter cap row; G11 implemented from native source with in-game checks; a fixture fix for the AddOns gallery search icon.

**Gate**: `bash scripts/gate.sh lint`, and with PUC `lua5.1` directly the tests the PR touches plus `test-comments.lua` and `test-syntax.lua` (the machine is shared; CI ran the full suite; `Tools/tests/test_render_size.py` timeouts on Beast are a known baseline issue). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- Each item matches the plan or a recorded decision; open the author's before/after pairs and re-render 3 yourself over real backdrops (the right rail Medallions 1920x1080, a skinned window family, bags).
- Every new setting: default on, and off restores the base look exactly (spot-check 3 of the 52 zero pairs yourself).
- Skinned windows: no taint, no protected calls in combat, native layout respected (spot-check 4 families against the Forever source: `forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone `C:\Users\leeba\.cache\wow-ui-source`).
- Quest card and meter card sizing with 1, 4 and 8 quests and 3, 5 and 20 meter rows; RestedXP guide not cropped; Centred and Spread.
- CI run 44289977058 green; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 6578282b"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
**Known Beast timeouts**: `Tools/tests/test_render_size.py` PUC subprocess cases time out (60/90 s) on Beast under load, also on unchanged staging; a fix is in progress. If those are your only Python failures, note them in the PR body and let green Mac CI be the final proof; do not ask.
