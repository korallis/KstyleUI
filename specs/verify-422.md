# Verify: #422 CI PR 7 (CPU-time and peak-memory budgets) at 898fb5dc

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `898fb5dc` (draft PR https://github.com/korallis/KstyleUI/pull/422; resolve the full SHA with `git rev-parse`). Base is `f6144445fcd16f9e922607e5ed7cc4c65e737414`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\ci-7-cpu-budgets.md`. Coordinator decisions made during the work: (a) budget 20 CPU s for every file, plus a per-file allowance list (measured worst CPU time across sampled Mac runners plus 25%, rounded up, each line naming LEE-5827) for files over 20 today; an unlisted file over 20 fails, a listed file over its allowance fails, normal runs never fail a listed file for coming in under 20, and only a dedicated serial `--margins` calibration proposes removing a line (under 20 on every sampled Mac); (b) wall-clock hang guard = max(120 s, 5 x the file's CPU budget or allowance x the platform factor); (c) a measured Windows platform factor recorded in `Tools/regression/README.md`; (d) the flaky timing tests in `Tools/tests/test_run_all.py` (margins, `test_prints_the_slowest_five_and_the_total`) made deterministic; (e) the Mac shard wall-time difference recorded as slot contention. Author evidence: `C:\Users\leeba\.cache\kstyleui-ci-pr7\evidence.json`.

**Gate**: `bash scripts/gate.sh`. Windows bar for this PR: `gate.sh lint` exit 0 and `gate.sh lua --affected origin/staging` exit 0 (author: 494/494). Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.

**Checks**:
- Budgets still bite: a throwaway file that burns 30 CPU s fails (unlisted); a listed file pushed past its allowance fails; a 5 GB allocation fails with a peak figure; a real infinite loop is killed by the hang guard; all on Windows, and by reading the POSIX path. Write throwaway files in a temp dir, not the repo.
- Load insensitivity: a CPU-bound file under heavy parallel load keeps its verdict.
- Calibration numbers: every allowance traces to recorded measurements (which runner, which run); none guessed; the Windows factor is measured.
- `test-lua-runtime.lua`: how the MSVC `rand()` difference was resolved, and that it still catches a real divergence that would change a test's result.
- Deleted `CI_SLOWDOWN`/`SLOW_FIX`/`BIG_FIX`/`TARGET_HEADROOM`/`onCI` with nothing still referring to them; "not budgeted" printed under LuaJIT.
- The timing tests are deterministic: run `Tools/tests/test_run_all.py` 20 times in a row on Windows under load.
- Run `gate.sh lua --affected origin/staging` natively yourself and report the pass count; CI 43953802560 green for the SHA; merges cleanly onto current `origin/staging`; `git diff --stat` within the allowed files; suppressions grep; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified 898fb5dc"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
