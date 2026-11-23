# Task: CI PR 5: portable runner and gate on Windows, macOS and Linux

**Goal**: `bash scripts/gate.sh lint` and `bash scripts/gate.sh lua --affected origin/staging` run natively on Windows 11 (Git Bash + python.org Python, no WSL) with the same behaviour as on the Mac CI runners.

**Target**: KstyleUI, branch from `origin/staging`. The approved plan is `C:\Users\leeba\.capy\drive\captain-kstyle-project-lead\reports\CI-PLAN-2026-11-16.md`: read section 3 ("Test runner decision") and PR 5's row in section 4, plus R7 ("duplicate lint steps"). That is your Change, except anything about `fs.lua`/the Lua test files (PR 4, in flight on another branch) and CPU-time budgets (PR 7, later).

**Change** (plan section 3, runner rows):
- `Tools/regression/run_all.py`: replace the `fcntl` slot lock and JSON lease with N lock files (`flock(LOCK_NB)` on POSIX, `msvcrt.locking(LK_NBLCK)` on Windows; the OS frees them when a process dies); `killpg`/`wait4` unchanged on POSIX, on Windows `child.kill()` + `wait()` (no Job object, no taskkill) and peak memory plus CPU time from about 10 lines of `ctypes` (`PeakPagefileUsage`, `GetProcessTimes`) on `Popen._handle`, printing "n/a" if that fails, so the 4096 MB budget still applies on Windows; `os.getloadavg` only where it exists; `shlex.split(chosen, posix=os.name != "nt")` then `shutil.which(command[0])`, and fix the `.exe` fallback; deps-cache keys with `Path.as_posix()`; add a progress line (files done of total). Put the platform-specific parts in a small shim that `Tools/tests/test_run_all.py` covers on every OS.
- `Tools/regression/run-all.sh` and `scripts/gate.sh`: Python picker in order `$KSTYLEUI_PYTHON`, venv `bin/python` or `Scripts/python.exe`, `py -3`, `python3`, `python`, each checked with `-c 'import sys'` (rejects the Microsoft Store stub), held in an array, exported as `KSTYLEUI_PYTHON`; `run-all.sh` uses it; repo roots from `BASH_SOURCE`. R7: drop the gate's duplicate luacheck/check_toc steps and run `env -u SKIP pre-commit run --all-files`; give the `toc-files` (and `forever-api-contracts`) pre-commit hook a portable Python entry instead of `python3`.
- `Tools/dev/install-lua51*`: a Windows path that installs Lua 5.1.5 binaries (as done by hand on this machine: LuaBinaries `lua-5.1.5_Win64_bin.zip` into `~/.local/bin`, SHA-256 checked) and luacheck 1.2.0 `luacheck.exe`.
- AGENTS.md: remove the Windows `lua` group from `Known failing` once it passes; add the rule that a PR touching `run_all.py`, `gate.sh` or `run-all.sh` shows native Windows exit codes of `gate.sh lint` and `gate.sh lua --affected`.

**Playbook**: refactor -> Read and follow `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\skills\poteto-mode\playbooks\refactoring.md`, steps 1, 4, 5, 6, 8 only. Skip any delegation/subagents, model names, /loop, Bugbot, cloud agents, PR steps, and references to skills or sections not given as a path.

**Constraints**:
- Minimal code, stdlib only (no psutil). Behaviour on the Mac CI runners must not change: shard wall time within about 5%, same selection, same budgets.
- Do not edit any `Tools/regression/*.lua` file, `affected.py`, `trace.lua` or `.github/`; PR 4 (draft #413) owns the Lua side and CI PRs own the workflows. Lua test files that still fail on Windows because of shell calls are expected until #413 merges; list them.
- Windows machine (Beast): prepend `~/.local/bin`, `%LOCALAPPDATA%\Programs\LuaJIT\bin`, `%APPDATA%\Python\Python313\Scripts` to PATH.
- You may push your branch and open a **draft** PR against `staging`: title `refactor(regression): portable runner and gate on Windows, macOS and Linux`, label `no changelog`, body with `## Summary`, `## Changelog` ("No changelog: tooling only"), `## In-game checks` ("None"). Do not merge it.

**Files it may edit**: `Tools/regression/run_all.py`, `Tools/regression/run-all.sh`, a new shim module beside `run_all.py`, `Tools/regression/README.md`, `scripts/gate.sh`, `Tools/dev/install-lua51*`, `Tools/tests/test_run_all.py`, `.pre-commit-config.yaml` (hook entries only), `AGENTS.md`.

**Gate**: `bash scripts/gate.sh`. Windows bar for this PR: `gate.sh lint` exit 0 and `gate.sh lua --affected origin/staging` exit 0 except Lua files that fail only for #413's shell calls (listed); `python -m unittest Tools.tests.test_run_all` exit 0. The draft PR's Mac CI proves macOS.

**Evidence of done**: native Windows exit codes and tails of `gate.sh lint` and `gate.sh lua --affected origin/staging` before (staging) and after; a timeout-kill test and a peak-memory test passing on Windows; the draft PR's green `checks` run with Lua shard times next to staging's last push run.

**Before worker_done**: run the Gate as above; clean comments in `git diff origin/staging..HEAD` by following `C:\Users\leeba\.claude\plugins\marketplaces\cursor-plugins\harness\pstack\claude-code\agents\comment-sicko.md` in worker mode. Conventional Commits subjects. If you stop before green: commit `wip: <what>` and report BLOCKED. Report SHA, base SHA, PR URL, run id, Gate output and evidence.
