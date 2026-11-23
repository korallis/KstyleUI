# Verify: #464 drop a held item onto the empty bag slots at 3566b325

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `3566b325edd6675cce419f9105a6b1d75442a83e` (draft PR https://github.com/korallis/KstyleUI/pull/464). Base is `de9665838ee35b384ad4730444b7dd6075eac145`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\bug-bags-drop-on-empty.md`; the owner's screenshot `C:\Users\leeba\.cache\lee-shots\bags-split-stack.png`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_7d254b129026\report.txt`.

**Gate**: `bash scripts/gate.sh lint`, and with PUC `lua5.1` directly every bag test plus `test-comments.lua` and `test-syntax.lua` (the machine is shared; `Tools/tests/test_render_size.py` timeouts on Beast are a known baseline issue). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Never stop processes you did not start.

**Checks**:
- Placement uses the right APIs (Forever UI source, `forever` branch of Gethe/wow-ui-source at `9dc84f0`; clone `C:\Users\leeba\.cache\wow-ui-source`; name the files): split stacks, items dragged from bank to bags and back, from the character pane, a full bag set (nothing placed, clear feedback), bag-type rules (profession/reagent bags, keyring), the bank window for bank items, and nothing on an empty cursor.
- No accidental item actions: a click on EMPTY or category space without a held item must not use, sell, delete or move anything; right-click unchanged; merchant and mail windows open at the same time.
- Highlights appear only while an item is held and clear afterwards; no taint or protected calls.
- Run the regression red on the base and green on the head.
- CI run 44292649262 green; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 3566b325"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
**Shared machine**: Beast's test slots are shared. If your native Lua gate run makes little progress (under 10% of files in 20 minutes), stop only your own run by PID, run `bash scripts/gate.sh lint`, `bash scripts/gate.sh python` and, with PUC `lua5.1` directly, the test files for the modules you changed plus `test-comments.lua` and `test-syntax.lua`; say so in the PR body. CI's full suite is the final proof.
**Known Beast timeouts**: `Tools/tests/test_render_size.py` PUC subprocess cases time out (60/90 s) on Beast under load, also on unchanged staging; a fix is in progress. If those are your only Python failures, note them in the PR body and let green Mac CI be the final proof; do not ask.
