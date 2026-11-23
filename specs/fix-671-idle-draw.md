# Task: PR #671 (crest jewel polish) passes the idle draw guard

PR #671 (branch `korallis/polish-medallions-crest-jewels`, head `377dd56e0`, just rebased onto staging) is approved by the owner. After the rebase, `test-perf-idle-draw` (from #673) fails: `medallions: 1764 shown regions at idle, ceiling 1715`. The jewel polish adds 49 shown regions at idle.

Fix it the right way: anything that draws nothing at idle (ring glow and halo below max, flare/drain layers that are not animating, gem layers of empty jewels if their texels are transparent) must be **hidden** (`Hide`), not shown at alpha 0, and shown only when it draws. Keep the look and every animation exactly as approved: the owner signed off on the GIFs in `C:/Users/leeba/.cache/kstyleui-evidence/task_d868cb696347/`; re-render them after the fix and show 0 changed pixels in every frame. Only if some new regions genuinely draw at idle (e.g. the faceted empty sockets), raise the Medallions ceiling in `test-perf-idle-draw.lua` to the measured count with a comment line naming them. Also keep `test-perf-medallions-switches` and the jewel tests green.

Lint, python, ActionBars tests, `test-perf*`, `test-taint-scan`, `test-perf-path-budgets` under PUC Lua 5.1; push to the same branch; hosted CI green. Do not merge.

**Files it may edit**: `KstyleUI_ActionBars/**`, `Tools/regression/**`, `Tools/render/**`.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, run id and the idle region count.
