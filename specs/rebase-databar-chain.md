# Task: rebase the data bar chain (#512, then #530 and #531) onto staging

**Goal**: three draft PRs make up the data bar. Each has passed review with its fixes applied. They must now land on the latest `origin/staging`, where #513 (consumables bar), #525, #529 and #526 have merged since.
- **#512** (top bar and zones): branch `korallis/databar-top-bar-zones`, head 9a526888, all 8 hosted shards green on its old base.
- **#530** (readouts): branch `korallis/feat-data-bar-readout`, head 9e111027, stacked on an older #512 head.
- **#531** (micro menu dock and Medallions dock): branch `korallis/feat-databar-micro-menu`, head 0bd6b236, stacked on #512 at 7dfa14eb.

**Do, in order**:
1. Rebase #512 onto the latest `origin/staging` and resolve the conflicts. Keep staging's lazy option builders (#532) and everything already merged, plus #512's fixes. Take the next free Store migration number if 41 is taken. Force-push with lease.
2. Rebase #530 onto the new #512 head and resolve the conflicts. Force-push.
3. Rebase #531 onto the new #530 head, or onto #512 if #531 doesn't depend on #530, whichever needs fewer changes. Resolve and force-push. Say which base you used.
4. Retarget nothing; I handle merges.

**Proof** for each branch under PUC Lua 5.1:
- `test-perf-path-budgets` under 15.7M (staging is at about 15.54M), and report each branch's reload;
- the DataBars tests, the whole `test-hud-reach-*` family, `test-hud-material-*`, `test-property-layout`, `test-render-scenes-focused` and `test-options-search`;
- lint and python.

Renders of the final #531 head: Frames top bar and Medallions dock at 1920x1080 and 5120x1440.

**Constraints**: minimal, conflict resolution only; CRLF/ASCII; locales synced with translations (union both sides' strings). All three stay drafts; do not merge. This is the last thing blocking the v0.2.7 release, so be fast.

**Gate**: lint, python and those tests. Send worker_done once all three are pushed with local proof; CI is hosted and fast, so include run ids if they are green by then.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report the three SHAs, the reload counts and the migration number.
