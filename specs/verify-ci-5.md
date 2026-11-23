# Verify: CI PR 5 (portable runner and gate) at d6d738fd

Work only in your own worktree (your starting directory); never cd into or change `C:\Projects\KstyleUI` or any other worktree. Fetch and check out `d6d738fd07241bcad01f5ee2f3260c15aeb1bc3c` (draft PR https://github.com/korallis/KstyleUI/pull/416). Base is `d70a3f5e76ba7f1bd57ec07a8f6be37086c7fc75`. Edit nothing, push nothing, comment nothing.

**Spec the author worked from**: `C:\Projects\KstyleUI\specs\ci-5-portable-runner.md` (plan section 3 in `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md`). Author's report: `C:\Users\leeba\.capy\work\ci-pr5-portable-runner\report.txt`. Approved exceptions: one `runner_platform.py` tuple item in `Tools/tests/test_affected.py`; assertions in `Tools/tests/test_gate.py` and one expected entry in `Tools/tests/test_pre_commit_config.py`.

**Allowed files**: `Tools/regression/run_all.py`, `Tools/regression/run-all.sh`, `Tools/regression/runner_platform.py`, `Tools/regression/README.md`, `scripts/gate.sh`, `Tools/dev/install-lua51*`, `Tools/tests/test_run_all.py`, `Tools/tests/test_affected.py`, `Tools/tests/test_gate.py`, `Tools/tests/test_pre_commit_config.py`, `.pre-commit-config.yaml`, `AGENTS.md`.

**Gate**: `bash scripts/gate.sh`. Windows bar: `gate.sh lint` exit 0; `gate.sh lua --affected origin/staging` runs every file (failures only from the Lua shell calls PR 4/#413 fixes); `python -m unittest Tools.tests.test_run_all Tools.tests.test_gate Tools.tests.test_pre_commit_config` exit 0. Toolchain: prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH; `KSTYLEUI_PYTHON=python`.

**Checks**:
- Budgets still mean something on Windows: a test file that sleeps past 20 s is killed and failed; one that allocates past 4096 MB is failed with a peak-memory figure (write throwaway test files in a temp dir, not the repo). Same on the Mac path by reading the POSIX branch (`wait4`, `killpg` unchanged).
- Slot locks: two concurrent `run-all.sh` runs share the slot pool; killing one frees its slots (Windows and POSIX code paths); no stale lease file left behind.
- Python picker rejects the Microsoft Store stub and honours `KSTYLEUI_PYTHON`; `gate.sh` no longer runs luacheck/check_toc twice and uses `env -u SKIP`; the python-language pre-commit hooks import only the stdlib.
- The Windows Lua installer checks SHA-256 and is idempotent.
- Mac CI unchanged in behaviour: same file selection and shard split as staging; run 43918891774 green for the SHA; the accepted timing (summed test time 838.5 s -> 831.6 s on the same six-slot Mac).
- How cleanly it combines with #413 (draft, f2036c10): merge both into a scratch branch, run the Windows Lua loop through `gate.sh lua --affected origin/staging`, and report the pass count and conflicts.
- `git diff --stat <base>..<sha>` against the allowed files; suppressions grep; new tests red at base and green at the SHA (apply `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\principle-test-behavior-not-implementation\SKILL.md`); comments via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` REPORT ONLY; blast radius via `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\blast-radius\SKILL.md` steps 1-5.

**Report**: start with "verified d6d738fd"; PASS / ISSUES / BLOCKED; prove every issue with a command and its output; end with an Attention list or "No flags".
