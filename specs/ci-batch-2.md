# Task: CI batch 2, no flakes and no slot starvation (local admission, precise `--affected`, clock asserts, hosted warn factor)

The owner approved this from the two CI audits. Read `C:/Users/leeba/.cache/kstyleui-evidence/ci-audit/claude.md` and `codex.md`.

**Change**:
1. **Local admission:**
   - after `run_all.py` selects files, if the selection is more than about 150 files (or "all") **and** other runs hold shared slots, refuse with a message naming the Beast speed rule and the fix (`KSTYLEUI_FULL=1` to force, or pass explicit files);
   - add a `--list` (dry-run) mode and an explicit-files mode that still takes shared slots;
   - CI is unaffected.
2. **Precise `--affected`:**
   - replace the blanket "a `*_env.lua`, stub or runner change runs everything" rule with the existing per-file read records (the codex audit showed the roads env selecting 17 of 834 tests), plus the mandatory guards;
   - fall back to everything when the records are stale or missing, or when the runner itself changes;
   - keep a stub change running everything if the records can't attribute stub functions. Say which you chose, with the numbers.
3. **No clock asserts:**
   - replace the remaining `os.clock` asserts with instruction or operation budgets using the existing instruction-budget helper: `test-layout-tag-budget.lua:13-21` and `test-nameplates-build-cost.lua:47`;
   - make the per-call time budgets in `measure.lua` / `perf_runner.lua` fatal **on Mac CI only**, informational elsewhere, as the Claude audit recommends. Allocation and instruction checks stay fatal everywhere.
4. **Hosted warn factor:** use 2.5 for hosted Linux CPU warnings, so a warning means something (149 noise warnings per green run today, and none at 2.5), and skip the headroom check there as Windows already does. Hosted CPU stays non-fatal. (Batch 1 may move PR Lua to the AMD runner. If so, this factor applies only to the hosted fallback; coordinate by rebasing.)

**Constraints**:
- Never weaken a real guard.
- Minimal code.
- Python tests for `run_all.py` behaviour, not YAML snapshots.

**PR**: open a PR (not a draft) against `staging` titled `build(tests): no accidental full runs, precise --affected, no clock asserts`, with the `no changelog` label. Do not merge.

**Files it may edit**: `Tools/regression/run_all.py`, `run-all.sh`, `measure.lua`, `perf_runner.lua`, `instruction_budget.lua`, `test-layout-tag-budget.lua`, `test-nameplates-build-cost.lua`, `Tools/regression/README.md`, `Tools/tests/test_run_all.py` and related tests, `.github/workflows/checks.yml` (only the warn factor env, if that's where it lives), `AGENTS.md` (only the lines describing these rules).

**Gate**: lint, python and the touched Lua tests under PUC Lua 5.1, then hosted CI. Prove the admission refusal with a real run while another run holds slots.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and the `--affected` before/after numbers.
