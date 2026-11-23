# Verify: #425 CI PR 6 (Python suite on Windows, LF check, CI follow-ups) at 6df7bf68

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `6df7bf689d95d41eee8338c58c24d6f2feca8778` (draft PR https://github.com/korallis/KstyleUI/pull/425). Base is `f6144445fcd16f9e922607e5ed7cc4c65e737414`. Edit nothing, push nothing, comment nothing.

**Spec**: `C:\Projects\KstyleUI\specs\ci-6-python-windows.md`. Approved changes: the timing-margin flakes in `Tools/tests/test_run_all.py` moved to PR 7 (untouched here); the two write calls in `Tools/medallions/medallions.py`; a RAQM feature-detection skip for `test_render_standins.GlyphsTest.test_glyph_table_is_current` when `PIL.features.check('raqm')` is False. Author report: `C:/Users/leeba/.cache/kstyleui-verify/pr6/report.txt`.

**Gate**: `bash scripts/gate.sh`. Windows bar for this PR: `gate.sh lint` and `gate.sh python` exit 0. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH.

**Checks**:
- No weakened assertion: for every changed test, say whether it still checks the same behaviour on the Mac; every skip names a missing platform feature, is conditional on that feature, and does not fire on the Mac runners (confirm from the Mac job log of run 43945803775: 861 tests, list the skips there versus base).
- The interrupt test no longer kills the interpreter on Windows and still proves the Ctrl-C behaviour on POSIX.
- `crlf.py --check` fails on a planted CRLF file in `Tools/` and `docs/` and names `newline="\n"`; the Python writers now write LF on Windows (run one and inspect bytes).
- `gate.sh` runs `check-suppressions.sh` with `SUPPRESSION_BASELINES=Tools/regression/pixel_allow.tsv`: prove a pixel_allow.tsv growth without a `Baseline-Growth:` trailer fails, and with it passes.
- The #419 tag-cleanup assertion in `test_workflows.py` is now an exact match (an appended command fails it).
- Merges cleanly onto current `origin/staging` (it has #424, which also edits `Tools/media/medallions_kit.py`); run the media tests on the merged tree.
- `git diff --stat <base>..<sha>`; suppressions grep; comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified 6df7bf68"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".

**Do not end your turn while your own work is still running** (CI runs, background test loops, subagents, mutants): block on it in this turn (`gh run watch <id> --exit-status`, `wait <pid>`), then send worker_done. Ending a turn without worker_done makes Orca report you as stopped.
**Poll CI slowly**: the GitHub account is shared by many agents. Poll at most once every 2 minutes (`gh run watch <id> --exit-status --interval 120`), avoid `gh api` loops, and treat an HTTP 403 rate-limit error as unknown (wait for the reset), never as a CI failure.
