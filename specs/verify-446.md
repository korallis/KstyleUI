# Verify: #446 never give a font a zero height in the Options preview at 58a18b89

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `58a18b8907c9062bd1ac2d6c8a18bce0c2944cb2` (draft PR https://github.com/korallis/KstyleUI/pull/446). Base is `a0984bb2cb32cd317f2f4ea16a62be1cef73f31b`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\fb-fontheight.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_ddac1e5d7546\worker-report.txt`.

**Gate**: `bash scripts/gate.sh` exits 0. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.

**Checks**:
- Root cause: the claim that `GetLeft` resolves a pending `OnSizeChanged` inside `MeasureHeader`, and that the group preview's party area went negative and was forced to one unit (factor 1/143). Confirm the reported player stack (in the spec) matches the reproduced one, and that the test-first commit changes no addon source vs the base (`git diff a0984bb2 dff34da1 -- ':!Tools'`). Run it red on dff34da1 and green on the head.
- The fix: resize work coalesced onto the next timer turn. Check for a visible one-frame flash or wrong first layout when the Options window opens or is resized, re-entrancy loops, timers left running after the window closes, and secret/NaN/inf dimensions. `ApplyFont` keeps the previous font for invalid input and never sends a height below 1: check the first-call case (no previous font) and that valid sizes are unchanged bit-for-bit.
- Stub change (`Tools/regression/stubs/wow.lua` rejects invalid font heights): matches the client's real behaviour (Forever source / the reported error text); does not hide or newly break other tests (full `bash Tools/regression/run-all.sh` under lua5.1, exit code read directly).
- Look: render `gallery_options --strict` in Frames, Orbs and Medallions at 1920x1080 and 5120x1440 on the base and the head and pixel-diff; any difference must be explained by the fix (the preview no longer drawn with a broken scale), nothing else. Also `hud_reference` in the three styles at 1920x1080 must be pixel-identical.
- CI run 44158608522 green for the SHA; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 58a18b89"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
