# Verify: #448 HUD scale search cheap and bit-identical at 9a668788

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `9a6687880bf1b3b397e345c924c49c1b39af5c32` (draft PR https://github.com/korallis/KstyleUI/pull/448). Base is `a0984bb2cb32cd317f2f4ea16a62be1cef73f31b`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\perf-1-scalelimit.md`. Author report: `C:\Users\leeba\AppData\Local\Temp\orca-ctx_8e7ea0cd75d4\REPORT.txt`.

**Owner constraint**: performance work must not change how anything looks, ever. Any scale or layout result that differs from the base, for any input, is a blocking issue.

**Gate**: `bash scripts/gate.sh lua --affected origin/staging` and `bash scripts/gate.sh lint` exit 0 (CI ran the full suite). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`. Test slots are shared and busy: be patient, never stop other processes.

**Checks**:
- Identity beyond the author's 63 cases: write your own probe (outside the repo) comparing base `Layouts.ScaleLimit` and every other public `Layouts` function the PR touches (`Story`, `Fits`, `Get`) against the head for all presets x 3 styles x many screen sizes (include odd sizes such as 1366x768, 2560x1080, 3840x2160, 1280x1024, 7680x2160), arrangements, module on/off sets and custom element positions or scales from `/kstyle layout`; assert `%.17g` equality and deep-equal layouts.
- Shared-state traps: memo or scratch tables leaking between calls or styles, a caller mutating a table that is now shared (the report warns `Get`'s copy must stay), re-entrancy (ScaleLimit called during a layout), stale memo after a layout edit, SavedVariables changes.
- `test-layouts-locals.lua` margin; `Tools/regression/fixtures/scalelimit-before.lua` is a faithful copy of the base implementation (diff it against the base).
- Pixel proof: re-render 3 of the author's pairs yourself (Medallions 5120x1440 Spread, Orbs 3456x2234, Frames 1920x1080) base vs head: 0 differing pixels.
- Measurement: re-run the cold-call benchmark under PUC lua5.1, base vs head interleaved, and confirm the time and garbage drop (author: Medallions 5120x1440 69 -> 19 ms, 41 MB -> 61 KB).
- CI run 44175360819 green for the SHA; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY.

**Report**: start with "verified 9a668788"; PASS / ISSUES / BLOCKED; prove every issue with file:line and a command; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
