# Verify: #450 RestedXP arrow stays visible in dark zones at 05dc8844

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `05dc88447e14def92f30d81506f5707aba504ad2` (draft PR https://github.com/korallis/KstyleUI/pull/450). Base is `a0984bb2cb32cd317f2f4ea16a62be1cef73f31b`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\rxp-arrow-visible.md`. Author evidence: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_eb3fd3b668b7\` (report.json, before-/after-game-*.png). The coordinator has already looked at the before/after crops: the arrow is now ivory with a dark edge and reads clearly on both.

**Gate**: `bash scripts/gate.sh lint`, and with PUC `lua5.1` directly every `Tools/regression/test-skins-restedxp-*.lua` plus `test-comments.lua` and `test-syntax.lua` (the machine is shared; CI ran the full suite). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- RestedXP behaviour untouched: rotation, hiding, texture coords and size; the arrow keeps following RestedXP's `UpdateVisuals`/`SetupArrow` and the skin's restyle on accent or theme change; disabling the skin restores RestedXP's own look; no taint or protected calls; nothing read back from regions.
- The added contrast layer and outlined distance text: created once (no leak on repeated `SetupArrow`), sized and anchored with the arrow, correct layer order, hidden with the arrow.
- Eight existing RestedXP tests changed: confirm each change is needed and no assertion was weakened (the author says they adapt to the new layer).
- Nothing else changes: pixel-diff `hud_reference` (3 styles, 1920x1080) and the RestedXP scenes outside the arrow, 0 differing pixels.
- CI run 44208133962 (attempt 2) green for the SHA; why attempt 1 failed; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 05dc8844"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
