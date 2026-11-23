# Task: land PR #530 (data bar readouts): rebase onto #531 and cut its reload cost

**Goal**: #512 has merged. #531 (dock) has been replayed onto staging at 5f50527d (branch `korallis/feat-databar-micro-menu`) and is merging now. #530 (readouts; branch `korallis/feat-data-bar-readout`, head 7d4d5e65) conflicts with #531, and it adds about **110k** reload instructions. Staging plus #531 is at about 15.554M against the 15.7M budget, and the Medallions layout change still has to fit after it.

**Do**:
1. Rebase #530's own commits onto the latest `korallis/feat-databar-micro-menu` head, or onto `origin/staging` if #531 has merged by then. #512's commits are already in staging, so replay only #530's commits with `git rebase --onto`. Resolve the conflicts, keeping #531's dock behaviour.
2. **Cut #530's reload cost to 40k or less.** Profile reload per function. Build each readout only when the bar first shows it, register no events for modules that are off, and do no account-gold or roster work until the tooltip or first show. Do not raise the budget.
3. Keep the review fixes: `Strip.Update` for value-only events, the "fps · ms" unit style and the short durations.

**Proof** under PUC Lua 5.1: `test-perf-path-budgets` (report the reload count and its delta against the base); the DataBars tests; the reach and material families; `test-property-layout`; `test-options-search`; lint and python. Renders of the full top bar and the Medallions dock at 1920x1080 and 5120x1440.

**Constraints**: minimal; CRLF/ASCII; locales synced with translations. Force-push with lease, and the PR stays a draft. Do not merge. This is the last data bar piece before release, so be fast.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, reload count and delta. Hosted CI is fast, so include the run id if it's green.
