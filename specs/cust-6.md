# Task: customisation batch 6: Layout Mode extras

**Goal**: the owner approved the customisation-parity plan and wants it all in v0.2.7. Read `C:/Users/leeba/.cache/kstyleui-evidence/customisation-parity/report.md` ("Layout Mode, side by side" and batch 6). Batch 4 (attach and match width) is draft PR #524 on branch `korallis/feat-attach-element-match`, stacked on #521, and it touches the same Layout Mode files. **Base your branch on `korallis/feat-attach-element-match`**, open a PR stacked on it, and rebase onto staging once #521 and #524 merge.

**Scope**:
- **Axis lock:** hold Shift while dragging a plate to lock it to the axis it first moves along.
- **Overlap cycling:** scrolling with Alt over stacked plates cycles which one is on top, so a plate under another can be picked. Pick a modifier that doesn't clash with the existing scroll-to-resize on action bar plates, and say which in the PR.
- **Coordinates on every plate:** a Layout Mode toggle, "Show coordinates on every plate", off by default, so today's look is unchanged.
- Arrow nudge stays at 1 px, and Shift+arrow stays at 10 px, which is today's behaviour.

**Rules**:
- An absent setting is today's behaviour.
- Layout Mode is never open in combat, as today.
- Near-zero reload cost, and `test-perf-path-budgets` stays under 15.7M.

**Tests**: axis lock, cycling with 3 stacked plates, the coordinates toggle, and that drag, nudge and scroll-resize are unchanged. Renders of Layout Mode with coordinates on, at 1920x1080 and 5120x1440.

**Constraints**: minimal code; AGENTS.md rules. Evidence never committed (`C:/Users/leeba/.cache/kstyleui-evidence/cust-6/`). Open a **draft** PR with base `korallis/feat-attach-element-match`, titled `feat(layout): axis lock, overlap cycling and coordinates in Layout Mode`, with `## Changelog` (`Added: In Layout Mode, Shift locks a drag to one direction, you can cycle through stacked frames, and every frame can show its coordinates.`), `## Options`, `## In-game checks` and `## Before and after`. Do not merge.

**Files it may edit**: `Core/Layout/**`, `KstyleUI_Options/**`, `Core/Locales/**`, `Tools/locale/*.json`, `Tools/regression/**`, `Tools/render/**`.

**Gate**: lint, python and the touched tests plus `test-perf-path-budgets` under PUC Lua 5.1. Send worker_done once local proof is done.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL, run id and render paths.
