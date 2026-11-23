# Task: audit KstyleUI's CI/CD and test pipelines for waste and enhancements (read-only report)

**The owner's words**: "ensure we are not over testing, and everything is the most optimal it can be."

Two independent auditors on different model families each write their own report. Don't coordinate with the other auditor.

**Context: read these first**:
- `AGENTS.md`: the Gate, the budget rule, CI shards, PR markers, `--affected`, and the Mac budget of record;
- `Tools/regression/README.md`, `scripts/gate.sh`, `Tools/regression/run-all.sh` and `run_all.py`;
- `.github/workflows/*.yml`, `Tools/hooks/ci_scope.py` and `Tools/tests/`;
- `.pre-commit-config.yaml`.

**Data**: `gh run list` and `gh run view --log` for the last ~3 days on `staging` and on PRs. This is real history; use it.

**Today's known pain points**:
1. Hosted PR Lua shards (8x ubuntu) only warn on CPU, and are about 2x slower and noisy. Staging Mac runs make CPU fatal, so a test can pass PRs and then go red on staging. That happened on 2026-11-20: consumables clearance tests ran 20-21 s against a 20 s limit and were fixed by #564.
2. Workers kept starting the full local suite (about 811 files) and starved the 10 shared Lua slots on the Windows dev box ("Beast").
3. A `--affected` run expands to all files when a stub, env file or the runner changes.
4. Some tests asserted on `os.clock` wall time and flaked (#566).
5. CI time per PR is about 5 min for 8 shards plus lint, python and package, and the Macs take about 8 min per staging push.

**Audit and measure**:
- **Over-testing:**
  - tests that duplicate each other, such as many near-identical `test-hud-caith-*`, `test-consumables-clearance-*` and `test-actionbars-config-*` variants;
  - files whose assertions are a strict subset of another file's;
  - render or source guards that re-check the same thing;
  - Python tests of the CI workflows that test configuration rather than behaviour;
  - per-file CPU and instruction cost from CI logs, the top 30 most expensive files with what each uniquely covers, and which can be merged, parametrised more cheaply (one boot reused), or deleted.

  Give an estimate of CPU saved for each.
- **Pipeline efficiency:**
  - shard balance (the slowest shard against the median), caching (Lua, luacheck, pip, pre-commit), job startup overhead;
  - whether the PR markers and skip logic pay for themselves;
  - redundant runs (PR runs then staging runs of the same tree);
  - the Mac staging run against a cheaper, deterministic gate;
  - whether hosted CPU warnings should become a calibrated fatal check (Mac-equivalent ratio) so problems are caught on the PR.
- **Determinism:** find every remaining wall-clock or `os.clock` assert, random seed, timer dependence or other flaky pattern; give file:line.
- **Local dev loop:** how a worker can get the right subset quickly without starving slots, for example a guard in `run_all.py` that refuses a full or all-files run while other runs hold slots. Is `--affected`'s "expand to everything" rule too coarse, and could it map stub and env changes to the tests that use the touched functions?
- **CD:** `release.yml`, the packager, the icon pack, the Discord post and store uploads. Look for missing safety checks (for example a packaged-zip smoke test that every TOC folder is in `.pkgmeta`), and steps that can be cut.

**Output**: `C:/Users/leeba/.cache/kstyleui-evidence/ci-audit/<your-family>.md` (`claude.md` or `codex.md`). Make it short and ranked:
- a table of each recommendation with the evidence (run ids and numbers), the saving (minutes or CPU s per PR and per staging push), the risk, and the size in lines;
- **what to delete** and **what to keep**, with a reason;
- three PR-sized batches in priority order.

Respect the project rules: minimal code, prefer deleting; never weaken a real guard (functional, instruction-count, memory and hang checks stay fatal); the Mac stays the CPU budget of record unless you show a calibrated, equivalent replacement.

**Constraints**:
- Read-only: no commits, no PRs, no workflow dispatches, and no cancelling of runs.
- Don't run the full local Lua suite. Read CI logs instead, and at most run a few single test files to measure.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the report path and your top five recommendations in one line each.
