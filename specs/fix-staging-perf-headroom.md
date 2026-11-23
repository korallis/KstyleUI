# Task: staging Mac CI red — test-perf per-call headroom (ActionBars)

After the recent merges (#694/#698 Spirit Poles, #689 crowns, #697 Storm Orbs, #695 Medallions only), staging's Mac run 44986221439 fails `test-perf` on shard 2/5 twice (once under load, once on an idle 18-CPU Mac):
- `ActionBars PET_BAR_UPDATE_COOLDOWN with a pet: budget 215 us is 2.0 times the 105 us Lua 5.1 CPU time; set it to at least 527 us (5 times)`
- `ActionBars key press flashes a slot: budget 20 us is 3.3 times the 6.08 us Lua 5.1 CPU time; set it to at least 30.4 us (5 times)`
- and on the loaded run `test-perf: used 43.38 CPU s, over the 39 CPU s budget`.

Find which merge raised these paths' cost (measure on the commits before/after each merge under PUC Lua 5.1). If the new work is wasteful (e.g. totem/crown/storm code walking all slots or repainting on every pet cooldown or key press), make it cheaper so the existing budgets hold, with pixel-identical results. Only if the added cost is necessary, raise the budgets to at least 5x the measured time with a one-line reason naming the feature. Also make test-perf fit its CPU allowance (split it if needed, like groupframes_r3a). Read `Tools/regression/README.md` for calibration and allowances.

PR to `staging`: `perf(actionbars): restore per-call headroom on pet cooldown and key press`, `Fixed:` line if player-visible, else label `no changelog`. Prove on Mac CI: run `gh workflow run checks.yml --ref <branch>` (includes Mac shards) and report the run id. Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `Tools/regression/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the cause in one line, PR, SHA, run ids.
