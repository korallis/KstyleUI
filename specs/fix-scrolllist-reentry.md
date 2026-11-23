# Task: fix the ScrollList Lua error when Options switches pages (player bug report)

**Report (Evil, Discord #bug-reports, v0.2.8)**: `4x KstyleUI/Core/Widgets/ScrollList.lua:91: attempt to compare nil with number`.

The stack goes: Options Rail click, then `Window.lua:168`, then `Window.lua:112`, then `ScrollList.lua:295 SetData`, then `:42 Measure`, then `:29 GetViewWidth`, then `[C] GetWidth`, then **`:416 OnSizeChanged`**, then `:174 Refresh`, then `:91 FirstIndex`. The locals show `items` has 117 entries while `tops` has only 7, and `mid=59`.

**Cause**:
- `SetData` assigns the new items before `Measure` has rebuilt `tops`;
- `Measure` calls `GetWidth`, which in the client can resolve pending layout and fire `OnSizeChanged` **synchronously**;
- that handler calls `Refresh`, so `FirstIndex` binary-searches 117 items over a 7-entry `tops` table.

**Fix** (minimal, at the root):
- No `OnSizeChanged` re-entry may Refresh against half-built state while `SetData` or `Measure` is running. A re-entrancy flag that makes the handler defer to the end of `SetData` is likely smallest; measuring the width before swapping the items also works. Choose the smaller correct one.
- Keep `FirstIndex` safe: bound its search by `#tops` when `tops` is shorter than items, as a guard. The root fix still comes first.
- No visual or behaviour change otherwise.

**Stubs**: make the stub raise what the client does. A frame with a pending size change must fire `OnSizeChanged` synchronously from `GetWidth` and `GetHeight`, in `Tools/regression/stubs/wow.lua`, modelled on the real behaviour, and named so it's clear.

Then add a regression that reproduces the exact crash on `origin/staging` (Options: switch pages between a short list and a 117-row list while a resize is pending) and passes after the fix. Run the other ScrollList, Options and stub tests, since changing the stub may expose other re-entrancy bugs. Fix any real ones, or list them.

**Check v0.2.8 too**: the fix must apply cleanly to staging. Note whether a v0.2.8.1 hotfix is warranted: how often players hit it, and from which pages.

**PR**: open a PR (not a draft) against `staging` titled `fix(widgets): no scroll list error when Options changes page`, with:
- `## Changelog`: `Fixed: A Lua error in the scroll list when switching Options pages.`
- `## In-game checks`.

Do not merge.

**Files it may edit**: `Core/Widgets/ScrollList.lua`, `KstyleUI_Options/Window.lua` (only if needed), `Tools/regression/stubs/wow.lua`, `Tools/regression/**`.

**Constraints**: minimal code; CRLF/ASCII. Beast speed rule: no full local Lua suite. A stub change runs every file in CI, which is the proof.

**Gate**: lint, python, the scrolllist, options and stub tests and `test-perf-path-budgets` under PUC Lua 5.1, then hosted CI.

**Before worker_done**: follow `C:/Users/leeba/orca-jev-router/WORKER.md`. Report SHA, PR URL and run id.
